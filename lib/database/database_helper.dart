import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/wfp_entry.dart';
import '../models/budget_activity.dart';

class DatabaseHelper {
  static Database? _db;

  // ─── Connection ────────────────────────────────────────────────────────────

  static Future<Database> get db async {
    if (_db != null) return _db!;

    sqfliteFfiInit();
    final factory = databaseFactoryFfi;

    // path_provider gives a stable, persistent folder on Windows:
    // C:\Users\<user>\Documents\pims_deped.db
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'pims_deped.db');

    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
      ),
    );

    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wfp (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        targetSize TEXT NOT NULL,
        indicator  TEXT NOT NULL,
        year       INTEGER NOT NULL,
        fundType   TEXT NOT NULL,
        amount     REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id        TEXT PRIMARY KEY,
        wfpId     TEXT NOT NULL,
        name      TEXT NOT NULL,
        total     REAL NOT NULL,
        projected REAL NOT NULL,
        disbursed REAL NOT NULL,
        status    TEXT NOT NULL,
        FOREIGN KEY (wfpId) REFERENCES wfp(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── WFP CRUD ──────────────────────────────────────────────────────────────

  static Future<void> insertWFP(WFPEntry entry) async {
    final d = await db;
    await d.insert('wfp', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail);
  }

  static Future<List<WFPEntry>> getAllWFPs() async {
    final d = await db;
    final rows = await d.query('wfp', orderBy: 'year DESC, id ASC');
    return rows.map(WFPEntry.fromMap).toList();
  }

  static Future<WFPEntry?> getWFPById(String id) async {
    final d = await db;
    final rows = await d.query('wfp', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return WFPEntry.fromMap(rows.first);
  }

  static Future<void> updateWFP(WFPEntry entry) async {
    final d = await db;
    await d.update('wfp', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  /// Deletes a WFP entry AND all its associated activities.
  static Future<void> deleteWFP(String id) async {
    final d = await db;
    await d.delete('activities', where: 'wfpId = ?', whereArgs: [id]);
    await d.delete('wfp', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> countWFPsByYear(int year) async {
    final d = await db;
    final result = await d.rawQuery(
        'SELECT COUNT(*) AS cnt FROM wfp WHERE year = ?', [year]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<bool> wfpIdExists(String id) async {
    final d = await db;
    final rows = await d.query('wfp',
        columns: ['id'], where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  // ─── Activity CRUD ─────────────────────────────────────────────────────────

  static Future<void> insertActivity(BudgetActivity activity) async {
    final d = await db;
    await d.insert('activities', activity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail);
  }

  static Future<List<BudgetActivity>> getActivitiesForWFP(
      String wfpId) async {
    final d = await db;
    final rows = await d.query('activities',
        where: 'wfpId = ?', whereArgs: [wfpId], orderBy: 'id ASC');
    return rows.map(BudgetActivity.fromMap).toList();
  }

  static Future<void> updateActivity(BudgetActivity activity) async {
    final d = await db;
    await d.update('activities', activity.toMap(),
        where: 'id = ?', whereArgs: [activity.id]);
  }

  static Future<void> deleteActivity(String id) async {
    final d = await db;
    await d.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> countActivitiesForWFP(String wfpId) async {
    final d = await db;
    final result = await d.rawQuery(
        'SELECT COUNT(*) AS cnt FROM activities WHERE wfpId = ?', [wfpId]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<bool> activityIdExists(String id) async {
    final d = await db;
    final rows = await d.query('activities',
        columns: ['id'], where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }
}
