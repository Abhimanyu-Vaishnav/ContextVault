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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE snippets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            useCount INTEGER DEFAULT 0,
            isPinned INTEGER DEFAULT 0,
            createdAt TEXT,
            lastUsedAt TEXT
          )
        ''');
      },
    );
  }

  static Stream<List<Snippet>> watchSnippets({String query = ''}) async* {
    yield await getSnippets(query: query);
    yield* _streamController.stream.asyncMap((_) => getSnippets(query: query));
  }

  static Future<List<Snippet>> getSnippets({String query = ''}) async {
    List<Map<String, dynamic>> maps;
    if (query.trim().isEmpty) {
      maps = await _db.query(
        'snippets',
        orderBy: 'isPinned DESC, lastUsedAt DESC',
      );
    } else {
      maps = await _db.query(
        'snippets',
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'isPinned DESC, lastUsedAt DESC',
      );
    }
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
