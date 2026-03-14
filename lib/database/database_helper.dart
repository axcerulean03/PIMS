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

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'pims_deped.db');

    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    return _db!;
  }

  // ─── Schema ────────────────────────────────────────────────────────────────

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wfp (
        id             TEXT PRIMARY KEY,
        title          TEXT NOT NULL,
        targetSize     TEXT NOT NULL,
        indicator      TEXT NOT NULL,
        year           INTEGER NOT NULL,
        fundType       TEXT NOT NULL,
        amount         REAL NOT NULL,
        approvalStatus TEXT NOT NULL DEFAULT 'Pending',
        approvedDate   TEXT,
        dueDate        TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id          TEXT PRIMARY KEY,
        wfpId       TEXT NOT NULL,
        name        TEXT NOT NULL,
        total       REAL NOT NULL,
        projected   REAL NOT NULL,
        disbursed   REAL NOT NULL,
        status      TEXT NOT NULL,
        targetDate  TEXT,
        FOREIGN KEY (wfpId) REFERENCES wfp(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        entityType  TEXT NOT NULL,
        entityId    TEXT NOT NULL,
        action      TEXT NOT NULL,
        timestamp   TEXT NOT NULL,
        diffJson    TEXT NOT NULL
      )
    ''');
  }

  /// Incremental migrations — safe to run on existing databases.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: approval fields on wfp, targetDate on activities
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'wfp', 'approvalStatus', "TEXT NOT NULL DEFAULT 'Pending'");
      await _addColumnIfMissing(db, 'wfp', 'approvedDate', 'TEXT');
      await _addColumnIfMissing(db, 'activities', 'targetDate', 'TEXT');
    }
    // v2 → v3: dueDate on wfp
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'wfp', 'dueDate', 'TEXT');
    }
    // v3 → v4: audit_log table
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          entityType  TEXT NOT NULL,
          entityId    TEXT NOT NULL,
          action      TEXT NOT NULL,
          timestamp   TEXT NOT NULL,
          diffJson    TEXT NOT NULL
        )
      ''');
    }
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    } catch (_) {
      // Column already exists — safe to ignore
    }
  }

  // ─── WFP CRUD ──────────────────────────────────────────────────────────────

  static Future<void> insertWFP(WFPEntry entry) async {
    final d = await db;
    await d.insert('wfp', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
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
    await d.update('wfp', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  static Future<void> deleteWFP(String id) async {
    final d = await db;
    await d.delete('activities', where: 'wfpId = ?', whereArgs: [id]);
    await d.delete('wfp', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> countWFPsByYear(int year) async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT COUNT(*) AS cnt FROM wfp WHERE year = ?', [year],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<bool> wfpIdExists(String id) async {
    final d = await db;
    final rows = await d.query('wfp', columns: ['id'], where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  /// Returns WFP entries filtered by year and/or approvalStatus.
  static Future<List<WFPEntry>> getWFPsFiltered({
    int? year,
    String? approvalStatus,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <dynamic>[];
    if (year != null) { where.add('year = ?'); args.add(year); }
    if (approvalStatus != null) { where.add('approvalStatus = ?'); args.add(approvalStatus); }
    final rows = await d.query(
      'wfp',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'year DESC, id ASC',
    );
    return rows.map(WFPEntry.fromMap).toList();
  }

  /// All distinct years in the wfp table, descending.
  static Future<List<int>> getDistinctYears() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT DISTINCT year FROM wfp ORDER BY year DESC');
    return rows.map((r) => r['year'] as int).toList();
  }

  // ─── Activity CRUD ─────────────────────────────────────────────────────────

  static Future<void> insertActivity(BudgetActivity activity) async {
    final d = await db;
    await d.insert('activities', activity.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
  }

  static Future<List<BudgetActivity>> getActivitiesForWFP(String wfpId) async {
    final d = await db;
    final rows = await d.query(
      'activities',
      where: 'wfpId = ?',
      whereArgs: [wfpId],
      orderBy: 'id ASC',
    );
    return rows.map(BudgetActivity.fromMap).toList();
  }

  static Future<void> updateActivity(BudgetActivity activity) async {
    final d = await db;
    await d.update('activities', activity.toMap(), where: 'id = ?', whereArgs: [activity.id]);
  }

  static Future<void> deleteActivity(String id) async {
    final d = await db;
    await d.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> countActivitiesForWFP(String wfpId) async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT COUNT(*) AS cnt FROM activities WHERE wfpId = ?', [wfpId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<bool> activityIdExists(String id) async {
    final d = await db;
    final rows = await d.query('activities', columns: ['id'], where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  static Future<int> countAllActivities() async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) AS cnt FROM activities');
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<List<BudgetActivity>> getAllActivities() async {
    final d = await db;
    final rows = await d.query('activities', orderBy: 'id ASC');
    return rows.map(BudgetActivity.fromMap).toList();
  }

  /// Returns activities for a list of WFP IDs, keyed by wfpId (for grouped export).
  static Future<Map<String, List<BudgetActivity>>> getActivitiesForWFPs(
    List<String> wfpIds,
  ) async {
    if (wfpIds.isEmpty) return {};
    final d = await db;
    final placeholders = wfpIds.map((_) => '?').join(', ');
    final rows = await d.rawQuery(
      'SELECT * FROM activities WHERE wfpId IN ($placeholders) ORDER BY wfpId, id ASC',
      wfpIds,
    );
    final result = <String, List<BudgetActivity>>{};
    for (final row in rows) {
      final act = BudgetActivity.fromMap(row);
      result.putIfAbsent(act.wfpId, () => []).add(act);
    }
    return result;
  }

  // ─── Deadline queries ──────────────────────────────────────────────────────

  /// WFP entries whose dueDate falls within [withinDays] days from today.
  static Future<List<WFPEntry>> getWFPsDueSoon(int withinDays) async {
    final d = await db;
    final today = DateTime.now();
    final limit = today.add(Duration(days: withinDays));
    final todayStr = today.toIso8601String().substring(0, 10);
    final limitStr = limit.toIso8601String().substring(0, 10);
    final rows = await d.rawQuery(
      'SELECT * FROM wfp WHERE dueDate IS NOT NULL AND dueDate >= ? AND dueDate <= ?',
      [todayStr, limitStr],
    );
    return rows.map(WFPEntry.fromMap).toList();
  }

  /// Activities whose targetDate falls within [withinDays] days from today.
  static Future<List<BudgetActivity>> getActivitiesDueSoon(int withinDays) async {
    final d = await db;
    final today = DateTime.now();
    final limit = today.add(Duration(days: withinDays));
    final todayStr = today.toIso8601String().substring(0, 10);
    final limitStr = limit.toIso8601String().substring(0, 10);
    final rows = await d.rawQuery(
      'SELECT * FROM activities WHERE targetDate IS NOT NULL AND targetDate >= ? AND targetDate <= ?',
      [todayStr, limitStr],
    );
    return rows.map(BudgetActivity.fromMap).toList();
  }
  // ─── Audit Log ─────────────────────────────────────────────────────────────

  static Future<void> insertAuditLog({
    required String entityType,
    required String entityId,
    required String action,
    required String diffJson,
  }) async {
    final d = await db;
    await d.insert('audit_log', {
      'entityType': entityType,
      'entityId':   entityId,
      'action':     action,
      'timestamp':  DateTime.now().toIso8601String(),
      'diffJson':   diffJson,
    });
  }

  static Future<List<Map<String, dynamic>>> getAuditLog({
    int limit = 200,
    String? entityType,
    String? entityId,
  }) async {
    final d      = await db;
    final where  = <String>[];
    final args   = <dynamic>[];
    if (entityType != null) { where.add('entityType = ?'); args.add(entityType); }
    if (entityId   != null) { where.add('entityId = ?');   args.add(entityId); }
    return d.query(
      'audit_log',
      where:    where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy:  'id DESC',
      limit:    limit,
    );
  }

  static Future<void> clearAuditLog() async {
    final d = await db;
    await d.delete('audit_log');
  }

}