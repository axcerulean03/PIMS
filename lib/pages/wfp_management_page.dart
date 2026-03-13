import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/wfp_entry.dart';
import '../services/app_state.dart';
import '../utils/currency_formatter.dart';

class WFPManagementPage extends StatefulWidget {
  final AppState appState;

  const WFPManagementPage({super.key, required this.appState});

  @override
  State<WFPManagementPage> createState() => _WFPManagementPageState();
}

class _WFPManagementPageState extends State<WFPManagementPage> {
  // Form controllers
  final _title = TextEditingController();
  final _targetSize = TextEditingController();
  final _indicator = TextEditingController();
  final _amount = TextEditingController();
  final _search = TextEditingController();

  int _selectedYear = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;
  String _fundType = 'MODE';
  String _viewSection = 'Section A';

  // Edit mode
  WFPEntry? _editingEntry;

  // Sort state
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final _fundTypes = const [
    'MODE',
    'GASS',
    'HRTD',
    'LSP',
    'SBFP',
    'PESS',
    'Palaro',
    'BEFF-EAO',
    'BFLP',
    'DPRP',
    'OPDNTP',
    'BEFF-Repair',
    'BEFF-Electric',
  ];

  final _sections = const ['Section A', 'Section B', 'Section C'];

  // ─── Filtering & Sorting ───────────────────────────────────────────────────

  List<WFPEntry> get _filtered {
    final q = _search.text.toLowerCase();
    final all = widget.appState.wfpEntries;

    final filtered = q.isEmpty
        ? all.toList()
        : all.where((e) {
            return e.title.toLowerCase().contains(q) ||
                e.id.toLowerCase().contains(q) ||
                e.fundType.toLowerCase().contains(q) ||
                e.year.toString().contains(q);
          }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.id.compareTo(b.id);
          break;
        case 1:
          cmp = a.title.compareTo(b.title);
          break;
        case 2:
          cmp = a.targetSize.compareTo(b.targetSize);
          break;
        case 3:
          cmp = a.fundType.compareTo(b.fundType);
          break;
        case 4:
          cmp = a.year.compareTo(b.year);
          break;
        case 5:
          cmp = a.amount.compareTo(b.amount);
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

  // ─── Form Helpers ─────────────────────────────────────────────────────────

  void _loadEntryIntoForm(WFPEntry entry) {
    _title.text = entry.title;
    _targetSize.text = entry.targetSize;
    _indicator.text = entry.indicator;
    _amount.text = entry.amount.toString();
    setState(() {
      _selectedYear = entry.year;
      _fundType = entry.fundType;
      _editingEntry = entry;
    });
  }

  void _clearForm() {
    _title.clear();
    _targetSize.clear();
    _indicator.clear();
    _amount.clear();
    setState(() => _editingEntry = null);
  }

  // ─── Add / Update ─────────────────────────────────────────────────────────

  Future<void> _submitEntry() async {
    if (_title.text.trim().isEmpty) {
      _showSnack('Title cannot be empty.', isError: true);
      return;
    }

    final parsedAmount = double.tryParse(_amount.text);
    if (parsedAmount == null || parsedAmount < 0) {
      _showSnack('Please enter a valid amount.', isError: true);
      return;
    }

    if (_editingEntry != null) {
      // Update existing
      final updated = _editingEntry!.copyWith(
        title: _title.text.trim(),
        targetSize: _targetSize.text.trim(),
        indicator: _indicator.text.trim(),
        year: _selectedYear,
        fundType: _fundType,
        amount: parsedAmount,
      );
      await widget.appState.updateWFP(updated);
      _showSnack('WFP entry updated successfully.');
    } else {
      // Check for duplicate title
      final duplicate = widget.appState.wfpEntries.any(
        (e) => e.title.toLowerCase() == _title.text.trim().toLowerCase(),
      );
      if (duplicate) {
        _showSnack(
          'A WFP entry with this title already exists.',
          isError: true,
        );
        return;
      }

      final id = await widget.appState.generateWFPId(_selectedYear);
      final entry = WFPEntry(
        id: id,
        title: _title.text.trim(),
        targetSize: _targetSize.text.trim(),
        indicator: _indicator.text.trim(),
        year: _selectedYear,
        fundType: _fundType,
        amount: parsedAmount,
      );
      await widget.appState.addWFP(entry);
      _showSnack('WFP entry added: $id');
    }

    _clearForm();
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(WFPEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete WFP Entry'),
        content: Text(
          'Delete "${entry.title}" (${entry.id})?\n\n'
          'This will also remove all associated budget activities.',
        ),
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
      await widget.appState.deleteWFP(entry.id);
      _showSnack('WFP entry deleted.');
      if (_editingEntry?.id == entry.id) _clearForm();
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _title.dispose();
    _targetSize.dispose();
    _indicator.dispose();
    _amount.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
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
                    'WFP Management',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Entry Form ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingEntry != null
                          ? 'Edit Entry: ${_editingEntry!.id}'
                          : 'Add New WFP Entry',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Row 1: Title, Target Size, Indicator
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _title,
                            decoration: const InputDecoration(
                              labelText: 'Title *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _targetSize,
                            decoration: const InputDecoration(
                              labelText: 'Target Size',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _indicator,
                            decoration: const InputDecoration(
                              labelText: 'Indicator / Details',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Row 2: Year, Fund Type, View Section, Amount
                    Row(
                      children: [
                        // Year dropdown
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                            ),
                            items: List.generate(10, (i) {
                              final y = 2026 + i;
                              return DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              );
                            }),
                            onChanged: (v) =>
                                setState(() => _selectedYear = v!),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Fund Type dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _fundType,
                            decoration: const InputDecoration(
                              labelText: 'Fund Type',
                            ),
                            items: _fundTypes
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _fundType = v!),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // View Section (UI-only, no logic)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _viewSection,
                            decoration: const InputDecoration(
                              labelText: 'View Section',
                            ),
                            items: _sections
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _viewSection = v!),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Amount
                        Expanded(
                          child: TextField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount (₱) *',
                              prefixText: '₱ ',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_editingEntry != null) ...[
                          OutlinedButton(
                            onPressed: _clearForm,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2F3E46),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            _editingEntry != null ? Icons.save : Icons.add,
                          ),
                          label: Text(
                            _editingEntry != null
                                ? 'Save Changes'
                                : 'Add WFP Entry',
                          ),
                          onPressed: isLoading ? null : _submitEntry,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Search ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search by title, ID, fund type, or year…',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${rows.length} result${rows.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Data Table ─────────────────────────────────────────────
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
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  columns: [
                    DataColumn2(
                      label: const Text('WFP ID'),
                      size: ColumnSize.M,
                      onSort: _onSort,
                    ),
                    DataColumn2(
                      label: const Text('Title'),
                      size: ColumnSize.L,
                      onSort: _onSort,
                    ),
                    DataColumn2(
                      label: const Text('Target Size'),
                      size: ColumnSize.M,
                      onSort: _onSort,
                    ),
                    DataColumn2(
                      label: const Text('Fund Type'),
                      size: ColumnSize.S,
                      onSort: _onSort,
                    ),
                    DataColumn2(
                      label: const Text('Year'),
                      size: ColumnSize.S,
                      numeric: true,
                      onSort: _onSort,
                    ),
                    DataColumn2(
                      label: const Text('Amount'),
                      size: ColumnSize.M,
                      numeric: true,
                      onSort: _onSort,
                    ),
                    const DataColumn2(
                      label: Text('Actions'),
                      size: ColumnSize.S,
                    ),
                  ],
                  rows: rows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final isEditing = _editingEntry?.id == e.id;

                    return DataRow2(
                      color: WidgetStateProperty.resolveWith((states) {
                        if (isEditing) return Colors.blue.shade50;
                        return i.isEven ? Colors.white : Colors.grey.shade50;
                      }),
                      cells: [
                        DataCell(
                          Text(
                            e.id,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(Text(e.title)),
                        DataCell(Text(e.targetSize)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff2F3E46).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e.fundType,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(Text(e.year.toString())),
                        DataCell(Text(CurrencyFormatter.format(e.amount))),
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
                                onPressed: () => _loadEntryIntoForm(e),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red.shade400,
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(e),
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
          ),
        );
      },
    );
  }
}
