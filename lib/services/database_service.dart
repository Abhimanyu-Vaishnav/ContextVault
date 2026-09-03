import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/snippet.dart';

class DatabaseService {
  static late Database _db;
  static final _streamController = StreamController<List<Snippet>>.broadcast();

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'context_vault.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE snippets (
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE snippets ADD COLUMN category TEXT DEFAULT 'All'");
        }
      },
    );
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

  static void _notify() {
    _streamController.add([]);
  }
}
