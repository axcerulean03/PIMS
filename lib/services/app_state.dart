import 'package:flutter/foundation.dart';
import '../models/wfp_entry.dart';
import '../models/budget_activity.dart';
import '../database/database_helper.dart';
import '../utils/id_generator.dart';

/// Central shared state for the PIMS DepED app.
///
/// Pages listen to this via [ListenableBuilder] and call its
/// async methods to read/write data. All DB interactions are
/// routed through here so pages never touch [DatabaseHelper] directly.
class AppState extends ChangeNotifier {
  // ─── Internal state ──────────────────────────────────────────────────────

  List<WFPEntry> _wfpEntries = [];
  List<BudgetActivity> _activities = [];
  WFPEntry? _selectedWFP;
  bool _isLoading = false;
  String? _error;

  // ─── Public getters ──────────────────────────────────────────────────────

  /// All WFP entries loaded from the database.
  List<WFPEntry> get wfpEntries => List.unmodifiable(_wfpEntries);

  /// Activities for the currently selected WFP entry.
  List<BudgetActivity> get activities => List.unmodifiable(_activities);

  /// The WFP entry currently selected in the Budget Overview page.
  WFPEntry? get selectedWFP => _selectedWFP;

  /// True while any async DB operation is in progress.
  bool get isLoading => _isLoading;

  /// Last error message, or null if no error.
  String? get error => _error;

  // ─── Init ────────────────────────────────────────────────────────────────

  /// Call once at startup (in main.dart) to pre-load WFP entries.
  Future<void> init() async {
    _setLoading(true);
    try {
      _wfpEntries = await DatabaseHelper.getAllWFPs();
      _error = null;
    } catch (e) {
      _error = 'Failed to load WFP entries: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ─── WFP Operations ──────────────────────────────────────────────────────

  /// Generates the next available WFP ID for a given year.
  /// Retries automatically if a conflict is detected.
  Future<String> generateWFPId(int year) async {
    int count = await DatabaseHelper.countWFPsByYear(year);
    String id;
    do {
      count++;
      id = IDGenerator.generateWFP(year, count);
    } while (await DatabaseHelper.wfpIdExists(id));
    return id;
  }

  /// Adds a new WFP entry to the database and refreshes the list.
  Future<void> addWFP(WFPEntry entry) async {
    _setLoading(true);
    try {
      await DatabaseHelper.insertWFP(entry);
      _wfpEntries = await DatabaseHelper.getAllWFPs();
      _error = null;
    } catch (e) {
      _error = 'Failed to add WFP entry: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Updates an existing WFP entry and refreshes the list.
  Future<void> updateWFP(WFPEntry entry) async {
    _setLoading(true);
    try {
      await DatabaseHelper.updateWFP(entry);
      _wfpEntries = await DatabaseHelper.getAllWFPs();
      // Keep selectedWFP in sync if the updated entry is the selected one.
      if (_selectedWFP?.id == entry.id) {
        _selectedWFP = entry;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to update WFP entry: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Deletes a WFP entry (and its activities) and refreshes the list.
  Future<void> deleteWFP(String id) async {
    _setLoading(true);
    try {
      await DatabaseHelper.deleteWFP(id);
      _wfpEntries = await DatabaseHelper.getAllWFPs();
      // Clear budget overview state if the deleted entry was selected.
      if (_selectedWFP?.id == id) {
        _selectedWFP = null;
        _activities = [];
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to delete WFP entry: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ─── Budget Activity Operations ──────────────────────────────────────────

  /// Selects a WFP entry as the active context for Budget Overview,
  /// and loads its activities from the database.
  Future<void> selectWFP(WFPEntry entry) async {
    _selectedWFP = entry;
    _setLoading(true);
    try {
      _activities = await DatabaseHelper.getActivitiesForWFP(entry.id);
      _error = null;
    } catch (e) {
      _error = 'Failed to load activities: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Clears the currently selected WFP entry and its loaded activities.
  void clearSelectedWFP() {
    _selectedWFP = null;
    _activities = [];
    notifyListeners();
  }

  /// Generates the next available Activity ID for a given WFP entry.
  /// Retries automatically if a conflict is detected.
  Future<String> generateActivityId(String wfpId) async {
    int count = await DatabaseHelper.countActivitiesForWFP(wfpId);
    String id;
    do {
      count++;
      id = IDGenerator.generateActivity(wfpId, count);
    } while (await DatabaseHelper.activityIdExists(id));
    return id;
  }

  /// Adds a new budget activity and refreshes the activity list.
  Future<void> addActivity(BudgetActivity activity) async {
    _setLoading(true);
    try {
      await DatabaseHelper.insertActivity(activity);
      if (_selectedWFP != null) {
        _activities = await DatabaseHelper.getActivitiesForWFP(
          _selectedWFP!.id,
        );
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to add activity: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Updates an existing activity and refreshes the activity list.
  Future<void> updateActivity(BudgetActivity activity) async {
    _setLoading(true);
    try {
      await DatabaseHelper.updateActivity(activity);
      if (_selectedWFP != null) {
        _activities = await DatabaseHelper.getActivitiesForWFP(
          _selectedWFP!.id,
        );
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to update activity: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Deletes an activity by ID and refreshes the activity list.
  Future<void> deleteActivity(String id) async {
    _setLoading(true);
    try {
      await DatabaseHelper.deleteActivity(id);
      if (_selectedWFP != null) {
        _activities = await DatabaseHelper.getActivitiesForWFP(
          _selectedWFP!.id,
        );
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to delete activity: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ─── Computed Budget Totals ───────────────────────────────────────────────

  double get totalAR => _activities.fold(0, (s, a) => s + a.total);
  double get totalObligated => _activities.fold(0, (s, a) => s + a.projected);
  double get totalDisbursed => _activities.fold(0, (s, a) => s + a.disbursed);
  double get totalBalance => _activities.fold(0, (s, a) => s + a.balance);

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Clears any stored error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
