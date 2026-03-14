import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/budget_activity.dart';
import '../models/wfp_entry.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';

class BudgetOverviewPage extends StatefulWidget {
  final AppState appState;
  const BudgetOverviewPage({super.key, required this.appState});
  @override
  State<BudgetOverviewPage> createState() => BudgetOverviewPageState();
}

class BudgetOverviewPageState extends State<BudgetOverviewPage> {
  final _activityName   = TextEditingController();
  final _total          = TextEditingController();
  final _projected      = TextEditingController();
  final _disbursed      = TextEditingController();
  final _activitySearch = TextEditingController();
  final _wfpSearch      = TextEditingController();

  String _status = 'Not Started';
  String? _suggestedStatus; // auto-derived suggestion, null when no suggestion differs from _status
  String? _targetDate;
  BudgetActivity? _editingActivity;

  int  _sortColumnIndex = 0;
  bool _sortAscending   = true;
  int  _currentPage     = 0;
  int  _rowsPerPage     = 10;
  static const _rowsPerPageOptions = [10, 25, 50, 100];

  int  _wfpSortCol = 0;
  bool _wfpSortAsc = true;

  final _scrollController   = ScrollController();
  final _activitySectionKey = GlobalKey();

  static const _statusOptions = ['Not Started', 'Ongoing', 'Completed', 'At Risk'];
  static const double _activityTableHeight = 420.0;

  @override
  void dispose() {
    _activityName.dispose(); _total.dispose();
    _projected.dispose(); _disbursed.dispose();
    _activitySearch.dispose(); _wfpSearch.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── WFP filtering + sort ─────────────────────────────────────────────────

  List<WFPEntry> get _filteredWFP {
    final q   = _wfpSearch.text.toLowerCase();
    final all = widget.appState.wfpEntries;
    final filtered = q.isEmpty
        ? all.toList()
        : all.where((e) =>
            e.id.toLowerCase().contains(q) ||
            e.title.toLowerCase().contains(q) ||
            e.fundType.toLowerCase().contains(q) ||
            e.year.toString().contains(q) ||
            e.approvalStatus.toLowerCase().contains(q),
          ).toList();
    filtered.sort((a, b) {
      int cmp;
      switch (_wfpSortCol) {
        case 0: cmp = a.id.compareTo(b.id); break;
        case 1: cmp = a.title.compareTo(b.title); break;
        case 2: cmp = a.fundType.compareTo(b.fundType); break;
        case 3: cmp = a.year.compareTo(b.year); break;
        case 4: cmp = a.amount.compareTo(b.amount); break;
        case 5: cmp = a.approvalStatus.compareTo(b.approvalStatus); break;
        case 6: cmp = (a.dueDate ?? '').compareTo(b.dueDate ?? ''); break;
        default: cmp = 0;
      }
      return _wfpSortAsc ? cmp : -cmp;
    });
    return filtered;
  }

  void _onWFPSort(int col, bool asc) =>
      setState(() { _wfpSortCol = col; _wfpSortAsc = asc; });

  // ─── Select WFP + scroll ──────────────────────────────────────────────────

  Future<void> _selectWFP(WFPEntry e) async {
    await widget.appState.selectWFP(e);
    _clearForm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activitySectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ─── Activity filtering & sort ────────────────────────────────────────────

  List<BudgetActivity> get _filteredActivities {
    final q   = _activitySearch.text.toLowerCase();
    final all = widget.appState.activities;
    final filtered = q.isEmpty
        ? all.toList()
        : all.where((a) =>
            a.id.toLowerCase().contains(q) ||
            a.name.toLowerCase().contains(q) ||
            a.status.toLowerCase().contains(q),
          ).toList();
    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = a.id.compareTo(b.id); break;
        case 1: cmp = a.name.compareTo(b.name); break;
        case 2: cmp = a.total.compareTo(b.total); break;
        case 3: cmp = a.projected.compareTo(b.projected); break;
        case 4: cmp = a.disbursed.compareTo(b.disbursed); break;
        case 5: cmp = a.balance.compareTo(b.balance); break;
        case 6: cmp = a.status.compareTo(b.status); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  void _onActivitySort(int col, bool asc) => setState(() {
    _sortColumnIndex = col; _sortAscending = asc; _currentPage = 0;
  });

  List<BudgetActivity> get _pagedRows {
    final all   = _filteredActivities;
    final start = _currentPage * _rowsPerPage;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _rowsPerPage).clamp(0, all.length));
  }

  int get _totalPages {
    final total = _filteredActivities.length;
    return total == 0 ? 1 : (total / _rowsPerPage).ceil();
  }

  /// True when the activity form has unsaved data.
  /// Public — called by DashboardPage when discarding unsaved changes.
  void clearForm() => _clearForm();

  bool get hasUnsavedChanges =>
      _activityName.text.isNotEmpty ||
      _total.text.isNotEmpty ||
      _projected.text.isNotEmpty ||
      _disbursed.text.isNotEmpty ||
      _editingActivity != null;

  // ─── Form helpers ─────────────────────────────────────────────────────────

  void _loadActivityIntoForm(BudgetActivity a) {
    _activityName.text = a.name;
    _total.text        = a.total.toString();
    _projected.text    = a.projected.toString();
    _disbursed.text    = a.disbursed.toString();
    setState(() { _status = a.status; _suggestedStatus = null; _targetDate = a.targetDate; _editingActivity = a; });
  }

  void _clearForm() {
    _activityName.clear(); _total.clear(); _projected.clear(); _disbursed.clear();
    setState(() { _status = 'Not Started'; _suggestedStatus = null; _targetDate = null; _editingActivity = null; });
  }

  /// Derives a suggested status from the current numeric field values.
  /// Returns null if the suggestion matches the current status (no chip needed).
  String? _computeSuggestedStatus() {
    final total     = double.tryParse(_total.text)     ?? 0;
    final projected = double.tryParse(_projected.text) ?? 0;
    final disbursed = double.tryParse(_disbursed.text) ?? 0;

    String suggested;
    if (total <= 0 && disbursed <= 0) {
      suggested = 'Not Started';
    } else if (projected > total && total > 0) {
      suggested = 'At Risk'; // over-committed
    } else if (disbursed >= total && total > 0) {
      suggested = 'Completed';
    } else if (disbursed > 0) {
      suggested = 'Ongoing';
    } else {
      suggested = 'Not Started';
    }

    return suggested == _status ? null : suggested;
  }

  void _onAmountChanged() {
    final suggestion = _computeSuggestedStatus();
    if (suggestion != _suggestedStatus) {
      setState(() => _suggestedStatus = suggestion);
    }
  }

  Future<void> _pickTargetDate() async {
    final initial = _targetDate != null
        ? DateTime.tryParse(_targetDate!) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(2020), lastDate: DateTime(2040),
      helpText: 'Select Target Date',
    );
    if (picked != null) setState(() => _targetDate = picked.toIso8601String().substring(0, 10));
  }

  // ─── Submit Activity ──────────────────────────────────────────────────────

  Future<void> _submitActivity() async {
    final selectedWFP = widget.appState.selectedWFP;
    if (selectedWFP == null) return;
    if (!selectedWFP.isApproved) {
      _showSnack(
        'Cannot add activities — this WFP is "${selectedWFP.approvalStatus}". Approve it first.',
        isError: true);
      return;
    }
    if (_activityName.text.trim().isEmpty) {
      _showSnack('Activity name cannot be empty.', isError: true); return;
    }
    final totalVal     = double.tryParse(_total.text);
    final projectedVal = double.tryParse(_projected.text);
    final disbursedVal = double.tryParse(_disbursed.text);
    if (totalVal == null || projectedVal == null || disbursedVal == null) {
      _showSnack('Please enter valid numeric values.', isError: true); return;
    }
    final otherTotal = widget.appState.activities
        .where((a) => a.id != _editingActivity?.id)
        .fold<double>(0, (s, a) => s + a.total);
    if (otherTotal + totalVal > selectedWFP.amount) {
      final remaining = selectedWFP.amount - otherTotal;
      _showSnack(
        'Exceeds WFP ceiling. Remaining: ${CurrencyFormatter.format(remaining < 0 ? 0 : remaining)}',
        isError: true);
      return;
    }
    if (_editingActivity != null) {
      await widget.appState.updateActivity(_editingActivity!.copyWith(
        name: _activityName.text.trim(), total: totalVal,
        projected: projectedVal, disbursed: disbursedVal,
        status: _status, targetDate: _targetDate,
        clearTargetDate: _targetDate == null,
      ));
      _showSnack('Activity updated.');
    } else {
      final id = await widget.appState.generateActivityId(selectedWFP.id);
      await widget.appState.addActivity(BudgetActivity(
        id: id, wfpId: selectedWFP.id, name: _activityName.text.trim(),
        total: totalVal, projected: projectedVal, disbursed: disbursedVal,
        status: _status, targetDate: _targetDate,
      ));
      _showSnack('Activity added: $id');
    }
    _clearForm();
  }

  // ─── Delete Activity ──────────────────────────────────────────────────────

  Future<void> _confirmDeleteActivity(BudgetActivity a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Delete "${a.name}" (${a.id})?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.appState.deleteActivity(a.id);
      _showSnack('Activity deleted.');
      if (_editingActivity?.id == a.id) _clearForm();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      duration: const Duration(seconds: 3),
    ));
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Completed': return Colors.green.shade600;
      case 'Ongoing':   return Colors.blue.shade600;
      case 'At Risk':   return Colors.red.shade600;
      default:          return Colors.grey.shade600;
    }
  }

  Color _approvalColor(String s) {
    switch (s) {
      case 'Approved': return Colors.green.shade600;
      case 'Rejected': return Colors.red.shade600;
      default:         return Colors.orange.shade600;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final selectedWFP = widget.appState.selectedWFP;
        final isLoading   = widget.appState.isLoading;
        final wfpEntries  = _filteredWFP;
        final allWFP      = widget.appState.wfpEntries;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ─────────────────────────────────────────────
                Row(children: [
                  const Text('Budget Overview',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 4),
                Text('Select a WFP entry below to manage its budget activities.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),

                const SizedBox(height: 20),

                // ── WFP Table ──────────────────────────────────────────
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: LayoutBuilder(builder: (context, c) {
                          final titleRow = Row(children: [
                            const Text('WFP Entries',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xff2F3E46).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${allWFP.length}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ]);
                          final searchField = SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _wfpSearch,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 18),
                                hintText: 'Search ID, title, fund type, year, approval…',
                                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          );
                          if (c.maxWidth < 600) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              titleRow, const SizedBox(height: 8), searchField,
                            ]);
                          }
                          return Row(children: [
                            titleRow, const SizedBox(width: 16), Expanded(child: searchField),
                          ]);
                        }),
                      ),
                      SizedBox(
                        height: allWFP.isEmpty ? 100 : 320,
                        child: allWFP.isEmpty
                            ? Center(child: Text(
                                'No WFP entries yet. Add entries in WFP Management.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
                            : wfpEntries.isEmpty
                                ? Center(child: Text(
                                    'No results for "${_wfpSearch.text}"',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
                                : DataTable2(
                                    minWidth: 900,
                                    sortColumnIndex: _wfpSortCol,
                                    sortAscending: _wfpSortAsc,
                                    headingRowColor: WidgetStateProperty.all(const Color(0xff2F3E46)),
                                    headingTextStyle: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold),
                                    columnSpacing: 14,
                                    horizontalMargin: 12,
                                    columns: [
                                      DataColumn2(label: const Text('WFP ID'),    size: ColumnSize.M, onSort: _onWFPSort),
                                      DataColumn2(label: const Text('Title'),     size: ColumnSize.L, onSort: _onWFPSort),
                                      DataColumn2(label: const Text('Fund Type'), size: ColumnSize.S, onSort: _onWFPSort),
                                      DataColumn2(label: const Text('Year'),      size: ColumnSize.S, numeric: true, onSort: _onWFPSort),
                                      DataColumn2(label: const Text('Amount'),    size: ColumnSize.M, numeric: true, onSort: _onWFPSort),
                                      DataColumn2(label: const Text('Approval'),  size: ColumnSize.S, onSort: _onWFPSort),
                                      DataColumn2(label: const Text('Due Date'),  size: ColumnSize.S, onSort: _onWFPSort),
                                      const DataColumn2(label: Text('Actions'),   size: ColumnSize.S),
                                    ],
                                    rows: wfpEntries.asMap().entries.map((entry) {
                                      final i           = entry.key;
                                      final e           = entry.value;
                                      final isSelected  = selectedWFP?.id == e.id;
                                      final approvalClr = _approvalColor(e.approvalStatus);
                                      final daysUntil   = e.daysUntilDue;
                                      return DataRow2(
                                        color: WidgetStateProperty.resolveWith((_) {
                                          if (isSelected) return const Color(0xff2F3E46).withValues(alpha: 0.08);
                                          return i.isEven ? Colors.white : Colors.grey.shade50;
                                        }),
                                        cells: [
                                          DataCell(Text(e.id, style: TextStyle(
                                            fontFamily: 'monospace', fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? const Color(0xff2F3E46) : null))),
                                          DataCell(Row(children: [
                                            if (isSelected)
                                              Container(
                                                width: 3, height: 20,
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xff2F3E46),
                                                  borderRadius: BorderRadius.circular(2)),
                                              ),
                                            Expanded(child: Text(e.title,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontWeight: isSelected
                                                  ? FontWeight.w600 : FontWeight.normal))),
                                          ])),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xff2F3E46).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(5)),
                                            child: Text(e.fundType, style: const TextStyle(fontSize: 11)))),
                                          DataCell(Text(e.year.toString())),
                                          DataCell(Text(CurrencyFormatter.format(e.amount),
                                            style: const TextStyle(fontWeight: FontWeight.w500))),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: approvalClr.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(5)),
                                            child: Text(e.approvalStatus, style: TextStyle(
                                              fontSize: 11, color: approvalClr, fontWeight: FontWeight.w600)))),
                                          DataCell(e.dueDate == null
                                              ? Text('—', style: TextStyle(color: Colors.grey.shade400))
                                              : Row(children: [
                                                  if (daysUntil != null && daysUntil <= 7)
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 4),
                                                      child: Icon(Icons.warning_amber_rounded, size: 13,
                                                        color: daysUntil < 0 ? Colors.red : Colors.orange)),
                                                  Text(e.dueDate!, style: TextStyle(fontSize: 12,
                                                    color: daysUntil != null && daysUntil < 0
                                                        ? Colors.red.shade600 : Colors.black87)),
                                                ])),
                                          DataCell(isSelected
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xff2F3E46).withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(6)),
                                                  child: const Text('Selected', style: TextStyle(
                                                    fontSize: 11, color: Color(0xff2F3E46),
                                                    fontWeight: FontWeight.w600)))
                                              : TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    backgroundColor: const Color(0xff2F3E46),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    textStyle: const TextStyle(fontSize: 11),
                                                  ),
                                                  icon: const Icon(Icons.add, size: 13),
                                                  label: const Text('Add Activity'),
                                                  onPressed: () => _selectWFP(e),
                                                )),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Activity Section ───────────────────────────────────
                if (selectedWFP != null) ...[
                  SizedBox(key: _activitySectionKey, height: 0),

                  // Context banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff2F3E46).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xff2F3E46).withValues(alpha: 0.2)),
                    ),
                    child: Wrap(spacing: 12, runSpacing: 8, children: [
                      _contextChip('ID', selectedWFP.id),
                      _contextChip('Title', selectedWFP.title),
                      _contextChip('Fund Type', selectedWFP.fundType),
                      _contextChip('WFP Amount', CurrencyFormatter.format(selectedWFP.amount)),
                    ]),
                  ),

                  const SizedBox(height: 16),
                  _buildSummaryHeader(),
                  const SizedBox(height: 20),

                  // Activity form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingActivity != null
                              ? 'Edit Activity: ${_editingActivity!.id}'
                              : 'Add New Activity',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        if (!selectedWFP.isApproved)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200)),
                            child: Row(children: [
                              Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                'This WFP is "${selectedWFP.approvalStatus}" — '
                                'activities cannot be added until it is Approved.',
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
                            ]),
                          ),
                        LayoutBuilder(builder: (context, c) {
                          final nameField = TextField(controller: _activityName,
                            decoration: const InputDecoration(labelText: 'Activity Name *'));
                          final totalField = TextField(controller: _total,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Total Amount (₱)'),
                            onChanged: (_) => _onAmountChanged());
                          final projField = TextField(controller: _projected,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Projected / Obligated (₱)'),
                            onChanged: (_) => _onAmountChanged());
                          final disbField = TextField(controller: _disbursed,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Disbursed (₱)'),
                            onChanged: (_) => _onAmountChanged());
                          final statusDd = DropdownButton<String>(
                            value: _status,
                            items: _statusOptions.map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() {
                              _status = v!;
                              _suggestedStatus = _computeSuggestedStatus();
                            }),
                          );
                          // Suggestion chip — shown when auto-derived status differs from current
                          final suggestionChip = _suggestedStatus != null
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _status = _suggestedStatus!;
                                      _suggestedStatus = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.auto_fix_high, size: 13, color: Colors.blue.shade700),
                                        const SizedBox(width: 5),
                                        Text('Suggest: $_suggestedStatus',
                                          style: TextStyle(fontSize: 11,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 4),
                                        Icon(Icons.check, size: 12, color: Colors.blue.shade700),
                                      ]),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                          final targetDateField = InkWell(
                            onTap: _pickTargetDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Target Date',
                                suffixIcon: Icon(Icons.calendar_today, size: 14),
                                isDense: true),
                              child: Row(children: [
                                Expanded(child: Text(_targetDate ?? 'Set date',
                                  style: TextStyle(fontSize: 13,
                                    color: _targetDate != null ? Colors.black87 : Colors.grey.shade400))),
                                if (_targetDate != null)
                                  GestureDetector(
                                    onTap: () => setState(() => _targetDate = null),
                                    child: Icon(Icons.clear, size: 14, color: Colors.grey.shade500)),
                              ]),
                            ),
                          );
                          final actionBtns = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_editingActivity != null) ...[
                                OutlinedButton(onPressed: _clearForm, child: const Text('Cancel')),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff2F3E46),
                                  foregroundColor: Colors.white),
                                icon: Icon(_editingActivity != null ? Icons.save : Icons.add),
                                label: Text(_editingActivity != null ? 'Save' : 'Add Activity'),
                                onPressed: isLoading ? null : _submitActivity,
                              ),
                            ],
                          );
                          if (c.maxWidth < 700) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              nameField, const SizedBox(height: 8),
                              Row(children: [Expanded(child: totalField), const SizedBox(width: 8), Expanded(child: projField)]),
                              const SizedBox(height: 8),
                              Row(children: [Expanded(child: disbField), const SizedBox(width: 8), statusDd, suggestionChip]),
                              const SizedBox(height: 8),
                              Row(children: [Expanded(child: targetDateField), const SizedBox(width: 8), actionBtns]),
                            ]);
                          }
                          return Row(children: [
                            Expanded(flex: 2, child: nameField), const SizedBox(width: 10),
                            Expanded(child: totalField), const SizedBox(width: 10),
                            Expanded(child: projField), const SizedBox(width: 10),
                            Expanded(child: disbField), const SizedBox(width: 10),
                            statusDd, suggestionChip, const SizedBox(width: 10),
                            SizedBox(width: 150, child: targetDateField), const SizedBox(width: 10),
                            actionBtns,
                          ]);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search + pagination controls
                  LayoutBuilder(builder: (context, c) {
                    final searchField = TextField(
                      controller: _activitySearch,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search activities…'),
                      onChanged: (_) => setState(() => _currentPage = 0),
                    );
                    final controls = Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Show:', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 6),
                      DropdownButton<int>(
                        value: _rowsPerPage,
                        items: _rowsPerPageOptions
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n entries')))
                            .toList(),
                        onChanged: (v) => setState(() { _rowsPerPage = v!; _currentPage = 0; }),
                      ),
                      const SizedBox(width: 12),
                      Text('${_filteredActivities.length} activit${_filteredActivities.length == 1 ? 'y' : 'ies'}',
                        style: TextStyle(color: Colors.grey.shade600)),
                    ]);
                    if (c.maxWidth < 600) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        searchField, const SizedBox(height: 8), controls]);
                    }
                    return Row(children: [
                      Expanded(child: searchField), const SizedBox(width: 16), controls]);
                  }),

                  const SizedBox(height: 12),

                  // Activities table
                  SizedBox(
                    height: _activityTableHeight,
                    child: DataTable2(
                      minWidth: 900,
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      headingRowColor: WidgetStateProperty.all(const Color(0xff2F3E46)),
                      headingTextStyle: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      columns: [
                        DataColumn2(label: const Text('Activity ID'),   size: ColumnSize.M, onSort: _onActivitySort),
                        DataColumn2(label: const Text('Activity Name'), size: ColumnSize.L, onSort: _onActivitySort),
                        DataColumn2(label: const Text('Total AR (₱)'),  size: ColumnSize.M, numeric: true, onSort: _onActivitySort),
                        DataColumn2(label: const Text('Projected (₱)'), size: ColumnSize.M, numeric: true, onSort: _onActivitySort),
                        DataColumn2(label: const Text('Disbursed (₱)'), size: ColumnSize.M, numeric: true, onSort: _onActivitySort),
                        DataColumn2(label: const Text('Balance (₱)'),   size: ColumnSize.M, numeric: true, onSort: _onActivitySort),
                        DataColumn2(label: const Text('Status'),        size: ColumnSize.S, onSort: _onActivitySort),
                        const DataColumn2(label: Text('Actions'),       size: ColumnSize.S),
                      ],
                      rows: _pagedRows.asMap().entries.map((entry) {
                        final i = entry.key;
                        final a = entry.value;
                        final isEditing = _editingActivity?.id == a.id;
                        return DataRow2(
                          color: WidgetStateProperty.resolveWith((_) {
                            if (isEditing) return Colors.blue.shade50;
                            return i.isEven ? Colors.white : Colors.grey.shade50;
                          }),
                          cells: [
                            DataCell(Text(a.id,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                            DataCell(Text(a.name)),
                            DataCell(Text(CurrencyFormatter.format(a.total))),
                            DataCell(Text(CurrencyFormatter.format(a.projected))),
                            DataCell(Text(CurrencyFormatter.format(a.disbursed))),
                            DataCell(Text(CurrencyFormatter.format(a.balance),
                              style: TextStyle(fontWeight: FontWeight.bold,
                                color: a.balance >= 0 ? Colors.green.shade700 : Colors.red.shade700))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(a.status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6)),
                              child: Text(a.status, style: TextStyle(
                                color: _statusColor(a.status),
                                fontSize: 12, fontWeight: FontWeight.w600)))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                                tooltip: 'Edit',
                                onPressed: () => _loadActivityIntoForm(a)),
                              IconButton(
                                icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDeleteActivity(a)),
                            ])),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  _PaginationBar(
                    currentPage: _currentPage, totalPages: _totalPages,
                    totalItems: _filteredActivities.length, rowsPerPage: _rowsPerPage,
                    onPageChanged: (p) => setState(() => _currentPage = p),
                  ),

                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Summary widgets ──────────────────────────────────────────────────────

  String _aggregateStatus(List<BudgetActivity> activities) {
    if (activities.isEmpty) return 'Not Started';
    const severity = {'At Risk': 3, 'Ongoing': 2, 'Not Started': 1, 'Completed': 0};
    return activities.map((a) => a.status).reduce(
      (a, b) => (severity[a] ?? 0) >= (severity[b] ?? 0) ? a : b);
  }

  Color _aggregateStatusColor(String status) {
    switch (status) {
      case 'At Risk':   return Colors.red.shade700;
      case 'Ongoing':   return Colors.blue.shade700;
      case 'Completed': return Colors.green.shade700;
      default:          return Colors.grey.shade600;
    }
  }

  Widget _buildSummaryHeader() {
    final s = widget.appState;
    final overallStatus = _aggregateStatus(s.activities);
    return Row(children: [
      _summaryTile('Current Status', overallStatus, color: _aggregateStatusColor(overallStatus)),
      const SizedBox(width: 12),
      _summaryTile('Total AR Amount', CurrencyFormatter.format(s.totalAR)),
      const SizedBox(width: 12),
      _summaryTile('Total Obligated AR', CurrencyFormatter.format(s.totalObligated)),
      const SizedBox(width: 12),
      _summaryTile('Disbursement Amount', CurrencyFormatter.format(s.totalDisbursed)),
      const SizedBox(width: 12),
      _summaryTile('Total AR Balance', CurrencyFormatter.format(s.totalBalance),
        color: s.totalBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700, bold: true),
    ]);
  }

  Widget _summaryTile(String label, String value, {Color? color, bool bold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xff2F3E46))),
        ]),
      ),
    );
  }

  Widget _contextChip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }
}

// ─── Pagination Bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int currentPage, totalPages, totalItems, rowsPerPage;
  final void Function(int) onPageChanged;

  const _PaginationBar({
    required this.currentPage, required this.totalPages,
    required this.totalItems, required this.rowsPerPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : currentPage * rowsPerPage + 1;
    final end   = ((currentPage + 1) * rowsPerPage).clamp(0, totalItems);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Text('Showing $start–$end of $totalItems entries',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.first_page), iconSize: 20,
          onPressed: currentPage > 0 ? () => onPageChanged(0) : null),
        IconButton(icon: const Icon(Icons.chevron_left), iconSize: 20,
          onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null),
        ...List.generate(totalPages, (i) => i)
            .where((i) => i == 0 || i == totalPages - 1 || (i - currentPage).abs() <= 1)
            .fold<List<Widget>>([], (acc, i) {
              if (acc.isNotEmpty) {
                final prev = int.tryParse((acc.last as dynamic)?.key?.toString() ?? '') ?? -999;
                if (i - prev > 1) acc.add(Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('…', style: TextStyle(color: Colors.grey.shade500))));
              }
              final isActive = i == currentPage;
              acc.add(Padding(
                key: ValueKey(i),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onPageChanged(i),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32, height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xff2F3E46) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive ? const Color(0xff2F3E46) : Colors.grey.shade300)),
                    child: Text('${i + 1}', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey.shade700)),
                  ),
                ),
              ));
              return acc;
            }),
        IconButton(icon: const Icon(Icons.chevron_right), iconSize: 20,
          onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null),
        IconButton(icon: const Icon(Icons.last_page), iconSize: 20,
          onPressed: currentPage < totalPages - 1 ? () => onPageChanged(totalPages - 1) : null),
      ]),
    );
  }
}
