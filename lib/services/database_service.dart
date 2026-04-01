import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chatbot.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        role      TEXT    NOT NULL,
        content   TEXT    NOT NULL,
        timestamp TEXT    NOT NULL,
        is_audio  INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ─── Settings ────────────────────────────────────────────────────────────────

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  // ─── Messages ─────────────────────────────────────────────────────────────────

  Future<int> insertMessage(MessageModel message) async {
    final db = await database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<MessageModel>> loadMessages() async {
    final db = await database;
    final rows = await db.query('messages', orderBy: 'timestamp ASC');
    return rows.map(MessageModel.fromMap).toList();
  }

  Future<void> clearMessages() async {
    final db = await database;
    await db.delete('messages');
  }
}
