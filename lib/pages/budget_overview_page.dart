import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/wfp_entry.dart';
import '../models/budget_activity.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';

class BudgetOverviewPage extends StatefulWidget {
  final AppState appState;

  const BudgetOverviewPage({super.key, required this.appState});

  @override
  State<BudgetOverviewPage> createState() => _BudgetOverviewPageState();
}

class _BudgetOverviewPageState extends State<BudgetOverviewPage> {
  // Form controllers
  final _activityName = TextEditingController();
  final _total = TextEditingController();
  final _projected = TextEditingController();
  final _disbursed = TextEditingController();
  final _search = TextEditingController();

  String _status = 'Not Started';
  BudgetActivity? _editingActivity;

  // Sort state
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  static const _statusOptions = [
    'Not Started',
    'Ongoing',
    'Completed',
    'At Risk',
  ];

  // ─── Filtering & Sorting ──────────────────────────────────────────────────

  List<BudgetActivity> get _filtered {
    final q = _search.text.toLowerCase();
    final all = widget.appState.activities;

    final filtered = q.isEmpty
        ? all.toList()
        : all.where((a) {
            return a.id.toLowerCase().contains(q) ||
                a.name.toLowerCase().contains(q) ||
                a.status.toLowerCase().contains(q);
          }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.id.compareTo(b.id);
          break;
        case 1:
          cmp = a.name.compareTo(b.name);
          break;
        case 2:
          cmp = a.total.compareTo(b.total);
          break;
        case 3:
          cmp = a.projected.compareTo(b.projected);
          break;
        case 4:
          cmp = a.disbursed.compareTo(b.disbursed);
          break;
        case 5:
          cmp = a.balance.compareTo(b.balance);
          break;
        case 6:
          cmp = a.status.compareTo(b.status);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  void _onSort(int col, bool asc) => setState(() {
    _sortColumnIndex = col;
    _sortAscending = asc;
  });

  // ─── WFP Selection ────────────────────────────────────────────────────────

  Future<void> _showWFPSelector() async {
    final entries = widget.appState.wfpEntries;

    if (entries.isEmpty) {
      _showSnack(
        'No WFP entries found. Add entries in WFP Management first.',
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select WFP Entry'),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = entries[i];
              return ListTile(
                title: Text(
                  e.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${e.id}  •  ${e.fundType}  •  ${e.year}'),
                trailing: Text(
                  CurrencyFormatter.format(e.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await widget.appState.selectWFP(e);
                  _clearForm();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ─── Form Helpers ─────────────────────────────────────────────────────────

  void _loadActivityIntoForm(BudgetActivity a) {
    _activityName.text = a.name;
    _total.text = a.total.toString();
    _projected.text = a.projected.toString();
    _disbursed.text = a.disbursed.toString();
    setState(() {
      _status = a.status;
      _editingActivity = a;
    });
  }

  void _clearForm() {
    _activityName.clear();
    _total.clear();
    _projected.clear();
    _disbursed.clear();
    setState(() {
      _status = 'Not Started';
      _editingActivity = null;
    });
  }

  // ─── Add / Update Activity ────────────────────────────────────────────────

  Future<void> _submitActivity() async {
    final selectedWFP = widget.appState.selectedWFP;
    if (selectedWFP == null) return;

    if (_activityName.text.trim().isEmpty) {
      _showSnack('Activity name cannot be empty.', isError: true);
      return;
    }

    final totalVal = double.tryParse(_total.text);
    final projectedVal = double.tryParse(_projected.text);
    final disbursedVal = double.tryParse(_disbursed.text);

    if (totalVal == null || projectedVal == null || disbursedVal == null) {
      _showSnack('Please enter valid numeric values.', isError: true);
      return;
    }

    if (_editingActivity != null) {
      final updated = _editingActivity!.copyWith(
        name: _activityName.text.trim(),
        total: totalVal,
        projected: projectedVal,
        disbursed: disbursedVal,
        status: _status,
      );
      await widget.appState.updateActivity(updated);
      _showSnack('Activity updated.');
    } else {
      final id = await widget.appState.generateActivityId(selectedWFP.id);
      final activity = BudgetActivity(
        id: id,
        wfpId: selectedWFP.id,
        name: _activityName.text.trim(),
        total: totalVal,
        projected: projectedVal,
        disbursed: disbursedVal,
        status: _status,
      );
      await widget.appState.addActivity(activity);
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
        content: Text('Delete activity "${a.name}" (${a.id})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green.shade600;
      case 'Ongoing':
        return Colors.blue.shade600;
      case 'At Risk':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _activityName.dispose();
    _total.dispose();
    _projected.dispose();
    _disbursed.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final selectedWFP = widget.appState.selectedWFP;
        final isLoading = widget.appState.isLoading;
        final rows = _filtered;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'Budget Overview',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2F3E46),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      selectedWFP == null
                          ? 'Select WFP Entry'
                          : 'Change WFP Entry',
                    ),
                    onPressed: _showWFPSelector,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── WFP Context Banner ─────────────────────────────────────
              if (selectedWFP == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 12),
                      Text(
                        'Select a WFP Entry to view and manage budget activities.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                )
              else ...[
                // WFP Context Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff2F3E46).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xff2F3E46).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _contextChip('ID', selectedWFP.id),
                      const SizedBox(width: 16),
                      _contextChip('Title', selectedWFP.title),
                      const SizedBox(width: 16),
                      _contextChip('Fund Type', selectedWFP.fundType),
                      const SizedBox(width: 16),
                      _contextChip(
                        'WFP Amount',
                        CurrencyFormatter.format(selectedWFP.amount),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 5-Column Summary Header ─────────────────────────────
                _buildSummaryHeader(),

                const SizedBox(height: 20),

                // ── Activity Form ───────────────────────────────────────
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _activityName,
                              decoration: const InputDecoration(
                                labelText: 'Activity Name *',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _total,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Total Amount (₱)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _projected,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Projected / Obligated (₱)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _disbursed,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Disbursed (₱)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            value: _status,
                            items: _statusOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                          const SizedBox(width: 10),
                          if (_editingActivity != null) ...[
                            OutlinedButton(
                              onPressed: _clearForm,
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff2F3E46),
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(
                              _editingActivity != null ? Icons.save : Icons.add,
                            ),
                            label: Text(
                              _editingActivity != null
                                  ? 'Save'
                                  : 'Add Activity',
                            ),
                            onPressed: isLoading ? null : _submitActivity,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Search ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search activities…',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${rows.length} activit${rows.length == 1 ? 'y' : 'ies'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Data Table ─────────────────────────────────────────
                Expanded(
                  child: DataTable2(
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xff2F3E46),
                    ),
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    columns: [
                      DataColumn2(
                        label: const Text('Activity ID'),
                        size: ColumnSize.M,
                        onSort: _onSort,
                      ),
                      DataColumn2(
                        label: const Text('Activity Name'),
                        size: ColumnSize.L,
                        onSort: _onSort,
                      ),
                      DataColumn2(
                        label: const Text('Total AR (₱)'),
                        size: ColumnSize.M,
                        numeric: true,
                        onSort: _onSort,
                      ),
                      DataColumn2(
                        label: const Text('Projected (₱)'),
                        size: ColumnSize.M,
                        numeric: true,
                        onSort: _onSort,
                      ),
                      DataColumn2(
                        label: const Text('Disbursed (₱)'),
                        size: ColumnSize.M,
                        numeric: true,
                        onSort: _onSort,
                      ),
                      DataColumn2(
                        label: const Text('Balance (₱)'),
                        size: ColumnSize.M,
                        numeric: true,
                        onSort: _onSort,
                      ),
                      DataColumn2(
                        label: const Text('Status'),
                        size: ColumnSize.S,
                        onSort: _onSort,
                      ),
                      const DataColumn2(
                        label: Text('Actions'),
                        size: ColumnSize.S,
                      ),
                    ],
                    rows: rows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final a = entry.value;
                      final isEditing = _editingActivity?.id == a.id;

                      return DataRow2(
                        color: WidgetStateProperty.resolveWith((_) {
                          if (isEditing) return Colors.blue.shade50;
                          return i.isEven ? Colors.white : Colors.grey.shade50;
                        }),
                        cells: [
                          DataCell(
                            Text(
                              a.id,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataCell(Text(a.name)),
                          DataCell(Text(CurrencyFormatter.format(a.total))),
                          DataCell(Text(CurrencyFormatter.format(a.projected))),
                          DataCell(Text(CurrencyFormatter.format(a.disbursed))),
                          DataCell(
                            Text(
                              CurrencyFormatter.format(a.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: a.balance >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(a.status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a.status,
                                style: TextStyle(
                                  color: _statusColor(a.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blueGrey,
                                  ),
                                  tooltip: 'Edit',
                                  onPressed: () => _loadActivityIntoForm(a),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red.shade400,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDeleteActivity(a),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Sub-Widgets ──────────────────────────────────────────────────────────

  Widget _buildSummaryHeader() {
    final s = widget.appState;
    return Row(
      children: [
        _summaryTile(
          'Current Status',
          s.totalBalance >= 0 ? 'On Track' : 'At Risk',
          color: s.totalBalance >= 0
              ? Colors.green.shade700
              : Colors.red.shade700,
        ),
        const SizedBox(width: 12),
        _summaryTile('Total AR Amount', CurrencyFormatter.format(s.totalAR)),
        const SizedBox(width: 12),
        _summaryTile(
          'Total Obligated AR',
          CurrencyFormatter.format(s.totalObligated),
        ),
        const SizedBox(width: 12),
        _summaryTile(
          'Disbursement Amount',
          CurrencyFormatter.format(s.totalDisbursed),
        ),
        const SizedBox(width: 12),
        _summaryTile(
          'Total AR Balance',
          CurrencyFormatter.format(s.totalBalance),
          color: s.totalBalance >= 0
              ? Colors.green.shade700
              : Colors.red.shade700,
          bold: true,
        ),
      ],
    );
  }

  Widget _summaryTile(
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color ?? const Color(0xff2F3E46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
