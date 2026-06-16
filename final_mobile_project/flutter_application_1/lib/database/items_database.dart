import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/item.dart';

/// Handles all SQLite database operations for Items/Tasks.
class ItemsDatabase {
  static final ItemsDatabase instance = ItemsDatabase._internal();
  ItemsDatabase._internal();

  static Database? _database;

  static const String _tableName = 'items';
  static const String _colId = 'id';
  static const String _colItemId = 'item_id';
  static const String _colUserId = 'user_id';
  static const String _colTitle = 'title';
  static const String _colBody = 'body';
  static const String _colImagePaths = 'image_paths';
  static const String _colCreatedAt = 'created_at';
  static const String _colFavorite = 'favorite';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'items_database.db');

    return await openDatabase(dbPath, version: 1, onCreate: _createTable);
  }

  Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        $_colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $_colItemId TEXT NOT NULL UNIQUE,
        $_colUserId TEXT NOT NULL,
        $_colTitle TEXT NOT NULL,
        $_colBody TEXT NOT NULL,
        $_colImagePaths TEXT NOT NULL,
        $_colCreatedAt TEXT NOT NULL,
        $_colFavorite INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_user_id ON $_tableName($_colUserId)
    ''');
  }

  Future<void> insertItem(Item item) async {
    final db = await database;
    await db.insert(
      _tableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Item>> getItemsByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: '$_colUserId = ?',
      whereArgs: [userId],
      orderBy: '$_colCreatedAt DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<Item?> getItemById(String itemId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: '$_colItemId = ?',
      whereArgs: [itemId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<List<Item>> getFavoriteItems(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: '$_colUserId = ? AND $_colFavorite = ?',
      whereArgs: [userId, 1],
      orderBy: '$_colCreatedAt DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update(
      _tableName,
      item.toMap(),
      where: '$_colItemId = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> toggleFavorite(String itemId, bool isFavorite) async {
    final db = await database;
    await db.update(
      _tableName,
      {_colFavorite: isFavorite ? 1 : 0},
      where: '$_colItemId = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteItem(String itemId) async {
    final db = await database;
    await db.delete(_tableName, where: '$_colItemId = ?', whereArgs: [itemId]);
  }

  Future<void> deleteAllUserItems(String userId) async {
    final db = await database;
    await db.delete(_tableName, where: '$_colUserId = ?', whereArgs: [userId]);
  }

  Future<List<Item>> searchItems(String userId, String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: '$_colUserId = ? AND ($_colTitle LIKE ? OR $_colBody LIKE ?)',
      whereArgs: [userId, '%$query%', '%$query%'],
      orderBy: '$_colCreatedAt DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<int> getItemCount(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE $_colUserId = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
