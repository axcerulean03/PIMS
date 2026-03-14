import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/wfp_entry.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';

class WFPManagementPage extends StatefulWidget {
  final AppState appState;
  const WFPManagementPage({super.key, required this.appState});

  @override
  State<WFPManagementPage> createState() => WFPManagementPageState();
}

class WFPManagementPageState extends State<WFPManagementPage> {
  final _title       = TextEditingController();
  final _targetSize  = TextEditingController();
  final _indicator   = TextEditingController();
  final _amount      = TextEditingController();
  final _search      = TextEditingController();

  int    _selectedYear   = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;
  String _fundType       = 'MODE';
  String _viewSection    = 'Section A';
  String _approvalStatus = 'Pending';
  String? _approvedDate;
  String? _dueDate;

  WFPEntry? _editingEntry;

  int  _sortColumnIndex = 0;
  bool _sortAscending   = true;
  int  _currentPage     = 0;
  int  _rowsPerPage     = 10;
  static const _rowsPerPageOptions = [10, 25, 50, 100];

  // Increased from 900 → 1100 so all 9 columns have enough room
  // without clipping. Horizontal scroll kicks in below this width.
  static const double _tableMinWidth = 1280.0;
  static const double _tableHeight   = 420.0;

  static const _fundTypes = [
    'MODE','GASS','HRTD','LSP','SBFP','PESS','Palaro',
    'BEFF-EAO','BFLP','DPRP','OPDNTP','BEFF-Repair','BEFF-Electric',
  ];
  static const _sections        = ['Section A', 'Section B', 'Section C'];
  static const _approvalOptions = ['Pending', 'Approved', 'Rejected'];

  // ─── Filtering & Sorting ──────────────────────────────────────────────────

  List<WFPEntry> get _filtered {
    final q   = _search.text.toLowerCase();
    final all = widget.appState.wfpEntries;
    final filtered = q.isEmpty
        ? all.toList()
        : all.where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.id.toLowerCase().contains(q) ||
            e.fundType.toLowerCase().contains(q) ||
            e.year.toString().contains(q) ||
            e.targetSize.toLowerCase().contains(q) ||
            e.indicator.toLowerCase().contains(q) ||
            e.approvalStatus.toLowerCase().contains(q),
          ).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = a.id.compareTo(b.id); break;
        case 1: cmp = a.title.compareTo(b.title); break;
        case 2: cmp = a.targetSize.compareTo(b.targetSize); break;
        case 3: cmp = a.fundType.compareTo(b.fundType); break;
        case 4: cmp = a.year.compareTo(b.year); break;
        case 5: cmp = a.amount.compareTo(b.amount); break;
        case 6: cmp = a.approvalStatus.compareTo(b.approvalStatus); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  void _onSort(int col, bool asc) => setState(() {
    _sortColumnIndex = col; _sortAscending = asc; _currentPage = 0;
  });

  List<WFPEntry> get _pagedRows {
    final all   = _filtered;
    final start = _currentPage * _rowsPerPage;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _rowsPerPage).clamp(0, all.length));
  }

  int get _totalPages {
    final total = _filtered.length;
    return total == 0 ? 1 : (total / _rowsPerPage).ceil();
  }

  void clearForm() => _clearForm();

  bool get hasUnsavedChanges =>
      _title.text.isNotEmpty ||
      _targetSize.text.isNotEmpty ||
      _indicator.text.isNotEmpty ||
      _amount.text.isNotEmpty ||
      _editingEntry != null;

  // ─── Form Helpers ─────────────────────────────────────────────────────────

  void _loadEntryIntoForm(WFPEntry entry) {
    _title.text      = entry.title;
    _targetSize.text = entry.targetSize;
    _indicator.text  = entry.indicator;
    _amount.text     = entry.amount.toString();
    setState(() {
      _selectedYear   = entry.year;
      _fundType       = entry.fundType;
      _approvalStatus = entry.approvalStatus;
      _approvedDate   = entry.approvedDate;
      _dueDate        = entry.dueDate;
      _editingEntry   = entry;
    });
  }

  void _clearForm() {
    _title.clear(); _targetSize.clear(); _indicator.clear(); _amount.clear();
    setState(() {
      _approvalStatus = 'Pending';
      _approvedDate   = null;
      _dueDate        = null;
      _editingEntry   = null;
    });
  }

  // ─── Date Pickers ─────────────────────────────────────────────────────────

  Future<void> _pickDueDate() async {
    final initial = _dueDate != null
        ? DateTime.tryParse(_dueDate!) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(2020), lastDate: DateTime(2040),
      helpText: 'Select Due Date',
    );
    if (picked != null) setState(() => _dueDate = picked.toIso8601String().substring(0, 10));
  }

  Future<void> _pickApprovedDate() async {
    final initial = _approvedDate != null
        ? DateTime.tryParse(_approvedDate!) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(2020), lastDate: DateTime(2040),
      helpText: 'Select Approval Date',
    );
    if (picked != null) setState(() => _approvedDate = picked.toIso8601String().substring(0, 10));
  }

  // ─── Add / Update ─────────────────────────────────────────────────────────

  Future<void> _submitEntry() async {
    if (_title.text.trim().isEmpty) {
      _showSnack('Title cannot be empty.', isError: true); return;
    }
    final parsedAmount = double.tryParse(_amount.text);
    if (parsedAmount == null || parsedAmount < 0) {
      _showSnack('Please enter a valid amount.', isError: true); return;
    }

    String? resolvedApprovedDate = _approvedDate;
    if (_approvalStatus == 'Approved' && resolvedApprovedDate == null) {
      resolvedApprovedDate = DateTime.now().toIso8601String().substring(0, 10);
    }
    if (_approvalStatus != 'Approved') resolvedApprovedDate = null;

    if (_editingEntry != null) {
      final updated = _editingEntry!.copyWith(
        title: _title.text.trim(), targetSize: _targetSize.text.trim(),
        indicator: _indicator.text.trim(), year: _selectedYear,
        fundType: _fundType, amount: parsedAmount,
        approvalStatus: _approvalStatus, approvedDate: resolvedApprovedDate,
        clearApprovedDate: resolvedApprovedDate == null,
        dueDate: _dueDate, clearDueDate: _dueDate == null,
      );
      await widget.appState.updateWFP(updated);
      _showSnack('WFP entry updated successfully.');
    } else {
      final duplicate = widget.appState.wfpEntries.any(
        (e) => e.title.toLowerCase() == _title.text.trim().toLowerCase());
      if (duplicate) {
        _showSnack('A WFP entry with this title already exists.', isError: true);
        return;
      }
      final id = await widget.appState.generateWFPId(_selectedYear);
      final entry = WFPEntry(
        id: id, title: _title.text.trim(), targetSize: _targetSize.text.trim(),
        indicator: _indicator.text.trim(), year: _selectedYear,
        fundType: _fundType, amount: parsedAmount,
        approvalStatus: _approvalStatus, approvedDate: resolvedApprovedDate,
        dueDate: _dueDate,
      );
      await widget.appState.addWFP(entry);
      _showSnack('WFP entry added: $id');
    }
    _clearForm();
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(WFPEntry entry) async {
    final activityCount = await widget.appState.getActivityCountForWFP(entry.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete WFP Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "${entry.title}" (${entry.id})?'),
            const SizedBox(height: 12),
            if (activityCount > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'This will also delete $activityCount linked budget '
                    '${activityCount == 1 ? 'activity' : 'activities'}. '
                    'This cannot be undone.',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  )),
                ]),
              )
            else
              Text('This entry has no linked activities.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
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
      await widget.appState.deleteWFP(entry.id);
      if (mounted) _showSnack('Deleted: ${entry.id}');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
    ));
  }

  Color _approvalColor(String status) {
    switch (status) {
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
        final isLoading = widget.appState.isLoading;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Page header ────────────────────────────────────────
                const Text('WFP Management',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: Color(0xff2F3E46))),
                const SizedBox(height: 4),
                Text('Create, manage, and track Work and Financial Plan entries.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),

                const SizedBox(height: 20),

                // ── Form card ──────────────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingEntry != null ? 'Edit WFP Entry' : 'Add WFP Entry',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),

                        LayoutBuilder(builder: (context, c) {
                          final narrow = c.maxWidth < 600;
                          if (narrow) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              TextField(controller: _title,
                                decoration: const InputDecoration(labelText: 'Program Title *')),
                              const SizedBox(height: 10),
                              TextField(controller: _targetSize,
                                decoration: const InputDecoration(labelText: 'Target Size')),
                              const SizedBox(height: 10),
                              TextField(controller: _indicator,
                                decoration: const InputDecoration(labelText: 'Indicator / Details')),
                            ]);
                          }
                          return Row(children: [
                            Expanded(flex: 3, child: TextField(controller: _title,
                              decoration: const InputDecoration(labelText: 'Program Title *'))),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: TextField(controller: _targetSize,
                              decoration: const InputDecoration(labelText: 'Target Size'))),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: TextField(controller: _indicator,
                              decoration: const InputDecoration(labelText: 'Indicator / Details'))),
                          ]);
                        }),

                        const SizedBox(height: 14),

                        LayoutBuilder(builder: (context, c) {
                          final narrow = c.maxWidth < 600;
                          final yearDd = DropdownButtonFormField<int>(
                            // ignore: deprecated_member_use
                            value: _selectedYear,
                            decoration: const InputDecoration(labelText: 'Year'),
                            items: List.generate(10, (i) {
                              final y = 2026 + i;
                              return DropdownMenuItem(value: y, child: Text(y.toString()));
                            }),
                            onChanged: (v) => setState(() => _selectedYear = v!),
                          );
                          final fundDd = DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _fundType,
                            decoration: const InputDecoration(labelText: 'Fund Type'),
                            items: _fundTypes.map((f) =>
                              DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (v) => setState(() => _fundType = v!),
                          );
                          final sectionDd = DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _viewSection,
                            decoration: const InputDecoration(labelText: 'View Section'),
                            items: _sections.map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _viewSection = v!),
                          );
                          final amountField = TextField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Amount (₱) *', prefixText: '₱ '),
                          );
                          if (narrow) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [Expanded(child: yearDd), const SizedBox(width: 12), Expanded(child: fundDd)]),
                              const SizedBox(height: 10),
                              Row(children: [Expanded(child: sectionDd), const SizedBox(width: 12), Expanded(child: amountField)]),
                            ]);
                          }
                          return Row(children: [
                            Expanded(child: yearDd), const SizedBox(width: 12),
                            Expanded(child: fundDd), const SizedBox(width: 12),
                            Expanded(child: sectionDd), const SizedBox(width: 12),
                            Expanded(child: amountField),
                          ]);
                        }),

                        const SizedBox(height: 14),

                        LayoutBuilder(builder: (context, c) {
                          final approvalDd = DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _approvalStatus,
                            decoration: InputDecoration(
                              labelText: 'Approval Status',
                              labelStyle: TextStyle(color: _approvalColor(_approvalStatus)),
                            ),
                            items: _approvalOptions.map((s) {
                              final color = _approvalColor(s);
                              return DropdownMenuItem(
                                value: s,
                                child: Row(children: [
                                  Container(width: 10, height: 10,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(s, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                                ]),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() {
                              _approvalStatus = v!;
                              if (v == 'Approved' && _approvedDate == null) {
                                _approvedDate = DateTime.now().toIso8601String().substring(0, 10);
                              }
                              if (v != 'Approved') _approvedDate = null;
                            }),
                          );
                          final approvedDateField = InkWell(
                            onTap: _approvalStatus == 'Approved' ? _pickApprovedDate : null,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Approved Date',
                                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                enabled: _approvalStatus == 'Approved',
                              ),
                              child: Text(
                                _approvedDate ?? (_approvalStatus == 'Approved' ? 'Tap to set' : '—'),
                                style: TextStyle(
                                  color: _approvalStatus == 'Approved'
                                      ? Colors.black87 : Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                          final dueDateField = InkWell(
                            onTap: _pickDueDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Due Date',
                                suffixIcon: Icon(Icons.calendar_today, size: 16),
                              ),
                              child: Row(children: [
                                Expanded(child: Text(
                                  _dueDate ?? 'Tap to set',
                                  style: TextStyle(
                                    color: _dueDate != null ? Colors.black87 : Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                )),
                                if (_dueDate != null)
                                  GestureDetector(
                                    onTap: () => setState(() => _dueDate = null),
                                    child: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
                                  ),
                              ]),
                            ),
                          );
                          if (c.maxWidth < 600) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              approvalDd, const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: approvedDateField), const SizedBox(width: 12),
                                Expanded(child: dueDateField),
                              ]),
                            ]);
                          }
                          return Row(children: [
                            Expanded(child: approvalDd), const SizedBox(width: 12),
                            Expanded(child: approvedDateField), const SizedBox(width: 12),
                            Expanded(child: dueDateField),
                          ]);
                        }),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_editingEntry != null) ...[
                              OutlinedButton(onPressed: _clearForm, child: const Text('Cancel')),
                              const SizedBox(width: 10),
                            ],
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff2F3E46),
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(_editingEntry != null ? Icons.save : Icons.add),
                              label: Text(_editingEntry != null ? 'Save Changes' : 'Add WFP Entry'),
                              onPressed: isLoading ? null : _submitEntry,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Search + Entries Per Page ──────────────────────────
                LayoutBuilder(builder: (context, c) {
                  final searchField = TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search by title, ID, fund type, year, target size, indicator, or approval status…',
                    ),
                    onChanged: (_) => setState(() => _currentPage = 0),
                  );
                  final paginationControls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      Text('${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  );
                  if (c.maxWidth < 600) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      searchField, const SizedBox(height: 8), paginationControls,
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 16),
                    paginationControls,
                  ]);
                }),

                const SizedBox(height: 16),

                // ── Data Table ─────────────────────────────────────────
                // LayoutBuilder measures available width. If narrower than
                // _tableMinWidth the horizontal ScrollView enables drag.
                // The SizedBox locks to exactly _tableMinWidth so DataTable2
                // always has enough room for all 9 columns.
                LayoutBuilder(builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth < _tableMinWidth
                      ? _tableMinWidth
                      : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: _tableHeight,
                      child: DataTable2(
                        minWidth: _tableMinWidth,
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        headingRowColor: WidgetStateProperty.all(const Color(0xff2F3E46)),
                        headingTextStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        columns: [
                          DataColumn2(label: const Text('WFP ID'),
                              size: ColumnSize.M, onSort: _onSort),
                          DataColumn2(label: const Text('Title'),
                              size: ColumnSize.L, onSort: _onSort),
                          DataColumn2(label: const Text('Target Size'),
                              size: ColumnSize.M, onSort: _onSort),
                          DataColumn2(label: const Text('Fund Type'),
                              size: ColumnSize.S, onSort: _onSort),
                          DataColumn2(label: const Text('Year'),
                              size: ColumnSize.S, numeric: true, onSort: _onSort),
                          DataColumn2(label: const Text('Amount'),
                              size: ColumnSize.M, numeric: true, onSort: _onSort),
                          DataColumn2(label: const Text('Approval'),
                              size: ColumnSize.S, onSort: _onSort),
                          DataColumn2(label: const Text('Due Date'),
                              size: ColumnSize.S, onSort: _onSort),
                          const DataColumn2(label: Text('Actions'),
                              size: ColumnSize.S),
                        ],
                        rows: _pagedRows.asMap().entries.map((entry) {
                          final i           = entry.key;
                          final e           = entry.value;
                          final isEditing   = _editingEntry?.id == e.id;
                          final isPending   = e.approvalStatus == 'Pending';
                          final approvalClr = _approvalColor(e.approvalStatus);
                          final daysUntil   = e.daysUntilDue;

                          return DataRow2(
                            color: WidgetStateProperty.resolveWith((_) {
                              if (isEditing) return Colors.blue.shade50;
                              if (isPending) return Colors.orange.shade50;
                              return i.isEven ? Colors.white : Colors.grey.shade50;
                            }),
                            cells: [
                              DataCell(Row(children: [
                                if (isPending)
                                  Container(
                                    width: 3, height: 28,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade400,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                Text(e.id, style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12)),
                              ])),
                              DataCell(Text(e.title)),
                              DataCell(Text(e.targetSize)),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xff2F3E46).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(e.fundType, style: const TextStyle(fontSize: 12)),
                              )),
                              DataCell(Text(e.year.toString())),
                              DataCell(Text(CurrencyFormatter.format(e.amount))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: approvalClr.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(e.approvalStatus, style: TextStyle(
                                    fontSize: 11, color: approvalClr,
                                    fontWeight: FontWeight.w600)),
                              )),
                              DataCell(e.dueDate == null
                                  ? Text('—', style: TextStyle(color: Colors.grey.shade400))
                                  : Row(children: [
                                      if (daysUntil != null && daysUntil <= 7)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Icon(Icons.warning_amber_rounded, size: 14,
                                            color: daysUntil < 0 ? Colors.red : Colors.orange),
                                        ),
                                      Text(e.dueDate!, style: TextStyle(
                                        fontSize: 12,
                                        color: daysUntil != null && daysUntil < 0
                                            ? Colors.red.shade600 : Colors.black87,
                                      )),
                                    ])),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                                    tooltip: 'Edit',
                                    onPressed: () => _loadEntryIntoForm(e),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(e),
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),

                // ── Pagination ─────────────────────────────────────────
                _PaginationBar(
                  currentPage:   _currentPage,
                  totalPages:    _totalPages,
                  totalItems:    _filtered.length,
                  rowsPerPage:   _rowsPerPage,
                  onPageChanged: (p) => setState(() => _currentPage = p),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Pagination Bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int rowsPerPage;
  final void Function(int) onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.rowsPerPage,
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
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text('Showing $start–$end of $totalItems entries',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.first_page), tooltip: 'First page', iconSize: 20,
            onPressed: currentPage > 0 ? () => onPageChanged(0) : null),
          IconButton(
            icon: const Icon(Icons.chevron_left), tooltip: 'Previous page', iconSize: 20,
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null),
          ...List.generate(totalPages, (i) => i)
              .where((i) => i == 0 || i == totalPages - 1 || (i - currentPage).abs() <= 1)
              .fold<List<Widget>>([], (acc, i) {
                if (acc.isNotEmpty) {
                  final prev = int.tryParse(
                      (acc.last as dynamic)?.key?.toString() ?? '') ?? -999;
                  if (i - prev > 1) {
                    acc.add(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('…', style: TextStyle(color: Colors.grey.shade500))));
                  }
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
                          color: isActive ? const Color(0xff2F3E46) : Colors.grey.shade300),
                      ),
                      child: Text('${i + 1}', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : Colors.grey.shade700)),
                    ),
                  ),
                ));
                return acc;
              }),
          IconButton(
            icon: const Icon(Icons.chevron_right), tooltip: 'Next page', iconSize: 20,
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null),
          IconButton(
            icon: const Icon(Icons.last_page), tooltip: 'Last page', iconSize: 20,
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(totalPages - 1) : null),
        ],
      ),
    );
  }
}