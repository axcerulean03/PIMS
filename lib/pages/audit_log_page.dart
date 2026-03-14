import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/app_state.dart';

class AuditLogPage extends StatefulWidget {
  final AppState appState;
  const AuditLogPage({super.key, required this.appState});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String _search       = '';
  String? _filterType;   // 'WFP' | 'Activity' | null
  String? _filterAction; // 'CREATE' | 'UPDATE' | 'DELETE' | null
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await widget.appState.getAuditLog(limit: 500);
    if (mounted) setState(() { _entries = all; _loading = false; });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Audit Log'),
        content: const Text(
          'This will permanently delete all audit log entries. '
          'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.appState.clearAuditLog();
      _load();
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _entries.where((e) {
      final matchSearch = q.isEmpty ||
          (e['entityId']   as String).toLowerCase().contains(q) ||
          (e['entityType'] as String).toLowerCase().contains(q) ||
          (e['action']     as String).toLowerCase().contains(q) ||
          (e['diffJson']   as String).toLowerCase().contains(q);
      final matchType   = _filterType   == null || e['entityType'] == _filterType;
      final matchAction = _filterAction == null || e['action']     == _filterAction;
      return matchSearch && matchType && matchAction;
    }).toList();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('Audit Log',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                  color: Color(0xff2F3E46))),
            const Spacer(),
            if (!_loading) ...[
              Text('${filtered.length} of ${_entries.length} entries',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300)),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear Log'),
                onPressed: _confirmClear,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text('Full field-level change history for all WFP entries and activities.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),

          const SizedBox(height: 20),

          // Filters
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Search by ID, entity type, action, or changed fields…',
                  isDense: true,
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          })
                      : null,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _filterType,
              hint: const Text('Entity'),
              items: const [
                DropdownMenuItem(value: null,       child: Text('All types')),
                DropdownMenuItem(value: 'WFP',      child: Text('WFP')),
                DropdownMenuItem(value: 'Activity', child: Text('Activity')),
              ],
              onChanged: (v) => setState(() => _filterType = v),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _filterAction,
              hint: const Text('Action'),
              items: const [
                DropdownMenuItem(value: null,     child: Text('All actions')),
                DropdownMenuItem(value: 'CREATE', child: Text('Created')),
                DropdownMenuItem(value: 'UPDATE', child: Text('Updated')),
                DropdownMenuItem(value: 'DELETE', child: Text('Deleted')),
              ],
              onChanged: (v) => setState(() => _filterAction = v),
            ),
          ]),

          const SizedBox(height: 16),

          // Log list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) => _logTile(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(_entries.isEmpty ? 'No audit log entries yet.' : 'No entries match your filters.',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
    ]));
  }

  Widget _logTile(Map<String, dynamic> entry) {
    final entityType = entry['entityType'] as String;
    final entityId   = entry['entityId']   as String;
    final action     = entry['action']     as String;
    final timestamp  = entry['timestamp']  as String;
    final diffJson   = entry['diffJson']   as String;

    final ts = DateTime.tryParse(timestamp);
    final timeLabel = ts != null
        ? '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')}  '
          '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}'
        : timestamp;

    final actionColor = action == 'CREATE'
        ? Colors.green.shade600
        : action == 'DELETE'
            ? Colors.red.shade600
            : Colors.blue.shade600;

    final typeColor = entityType == 'WFP'
        ? const Color(0xff2F3E46)
        : const Color(0xff3A7CA5);

    // Parse diff
    Map<String, dynamic> diff = {};
    try { diff = jsonDecode(diffJson) as Map<String, dynamic>; } catch (_) {}

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: actionColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(_actionIcon(action), size: 18, color: actionColor),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(entityType,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: actionColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(action,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: actionColor)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(entityId,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            overflow: TextOverflow.ellipsis),
        ),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(timeLabel,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: action == 'UPDATE'
              ? _renderDiff(diff)
              : _renderSnapshot(diff, action),
        ),
      ],
    );
  }

  Widget _renderDiff(Map<String, dynamic> diff) {
    if (diff.isEmpty) {
      return Text('No field changes recorded.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Changed fields:',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
              fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...diff.entries.map((e) {
          final from = e.value is Map ? (e.value as Map)['from']?.toString() ?? '—' : '—';
          final to   = e.value is Map ? (e.value as Map)['to']?.toString()   ?? '—' : '—';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 130,
                child: Text(e.key,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Expanded(child: Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(from,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700,
                        decoration: TextDecoration.lineThrough)),
                )),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                ),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(to,
                    style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                )),
              ])),
            ]),
          );
        }),
      ],
    );
  }

  Widget _renderSnapshot(Map<String, dynamic> snapshot, String action) {
    final label = action == 'CREATE' ? 'Created with:' : 'Deleted snapshot:';
    if (snapshot.isEmpty) {
      return Text('No data recorded.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...snapshot.entries.where((e) => e.value != null).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130,
              child: Text(e.key,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Expanded(child: Text(e.value.toString(),
              style: const TextStyle(fontSize: 12))),
          ]),
        )),
      ],
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'CREATE': return Icons.add_circle_outline;
      case 'DELETE': return Icons.delete_outline;
      default:       return Icons.edit_outlined;
    }
  }
}