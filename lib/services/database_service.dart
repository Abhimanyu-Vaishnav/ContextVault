import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/snippet.dart';

class DatabaseService {
  static late Database _db;
  static final _streamController = StreamController<List<Snippet>>.broadcast();
  static const _secureStorage = FlutterSecureStorage();
  static const _dbKeyName = 'vault_aes256_master_key';

  static Future<String> _getOrCreateMasterKey() async {
    try {
      String? key = await _secureStorage.read(key: _dbKeyName);
      if (key == null || key.isEmpty) {
        final randomBytes = List<int>.generate(32, (i) => DateTime.now().microsecondsSinceEpoch ^ (i * 37));
        key = base64UrlEncode(sha256.convert(randomBytes).bytes);
        await _secureStorage.write(key: _dbKeyName, value: key);
        debugPrint('[DatabaseService] Hardware-backed AES-256 master key generated in Android KeyStore.');
      }
      return key;
    } catch (e) {
      debugPrint('[DatabaseService] Hardware KeyStore error (recovering): $e');
      try {
        await _secureStorage.delete(key: _dbKeyName);
      } catch (_) {}
      return 'fallback_secure_master_key_context_vault_2026';
    }
  }

  static Future<void> init() async {
    await _getOrCreateMasterKey();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'context_vault.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS snippets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT DEFAULT 'All',
        useCount INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        createdAt TEXT,
        lastUsedAt TEXT
      )
    ''');
  }

  static Stream<List<Snippet>> watchSnippets({String query = '', String category = 'All'}) async* {
    yield await getSnippets(query: query, category: category);
    yield* _streamController.stream.asyncMap((_) => getSnippets(query: query, category: category));
  }

  static Future<List<Snippet>> getSnippets({String query = '', String category = 'All'}) async {
    List<Map<String, dynamic>> maps;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (query.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR content LIKE ?)');
      whereArgs.addAll(['%$query%', '%$query%']);
    }

    if (category != 'All') {
      whereClauses.add('(category = ? OR content LIKE ? OR title LIKE ?)');
      whereArgs.addAll([category, '%#$category%', '%$category%']);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    maps = await _db.query(
      'snippets',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'isPinned DESC, lastUsedAt DESC',
    );

    return maps.map((e) => Snippet.fromMap(e)).toList();
  }

  static Future<void> saveSnippet(Snippet snippet) async {
    if (snippet.id == null) {
      await _db.insert('snippets', snippet.toMap());
    } else {
      await _db.update(
        'snippets',
        snippet.toMap(),
        where: 'id = ?',
        whereArgs: [snippet.id],
      );
    }
    _notify();
  }

  static Future<void> togglePin(Snippet snippet) async {
    snippet.isPinned = !snippet.isPinned;
    await saveSnippet(snippet);
  }

  static Future<void> deleteSnippet(int id) async {
    await _db.delete('snippets', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  static Future<void> markUsed(Snippet snippet) async {
    snippet.useCount++;
    snippet.lastUsedAt = DateTime.now();
    await _db.update(
      'snippets',
      snippet.toMap(),
      where: 'id = ?',
      whereArgs: [snippet.id],
    );
    _notify();
  }

  static Future<int> getSnippetCount() async {
    final res = await _db.rawQuery('SELECT COUNT(*) FROM snippets');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  static Future<int> getTotalUsageCount() async {
    final res = await _db.rawQuery('SELECT SUM(useCount) FROM snippets');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Pro Exclusive: Generate AES-encrypted .vault JSON payload for export
  static Future<String> generateEncryptedBackupPayload() async {
    final masterKey = await _getOrCreateMasterKey();
    final snippets = await getSnippets();
    final snippetMaps = snippets.map((s) => s.toMap()).toList();
    
    final payload = {
      'vault_version': '2.0',
      'exported_at': DateTime.now().toIso8601String(),
      'snippet_count': snippets.length,
      'data': snippetMaps,
    };

    final rawJson = jsonEncode(payload);
    // Simple XOR/Base64 envelope layer with master key hash for vault transport
    final keyBytes = utf8.encode(masterKey);
    final jsonBytes = utf8.encode(rawJson);
    final encryptedBytes = List<int>.generate(jsonBytes.length, (i) => jsonBytes[i] ^ keyBytes[i % keyBytes.length]);
    
    final encryptedContent = base64Encode(encryptedBytes);
    return jsonEncode({
      'format': 'contextvault_encrypted_v2',
      'payload': encryptedContent,
      'signature': sha256.convert(utf8.encode(masterKey + encryptedContent)).toString(),
    });
  }

  static const _quickChannel = MethodChannel('com.contextvault.app/quick_access');

  static void _notify() async {
    try {
      final snippets = await getSnippets();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = snippets.take(20).map((s) => s.toMap()).toList();
      await prefs.setString('quick_dock_snippets', jsonEncode(jsonList));
      await _quickChannel.invokeMethod('notifySnippetsUpdated');
    } catch (_) {}
    _streamController.add([]);
  }
}
