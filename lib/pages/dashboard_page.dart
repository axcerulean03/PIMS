import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../models/wfp_entry.dart';
import '../models/budget_activity.dart';
import '../widgets/sidebar.dart';
import '../widgets/summary_card.dart';
import 'wfp_management_page.dart';
import 'budget_overview_page.dart';
import 'reports_page.dart';
import 'deadlines_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'audit_log_page.dart';
import 'login_page.dart';
import '../utils/currency_formatter.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _ink      = Color(0xFF1C2B33);   // deep text
const _primary  = Color(0xFF2F3E46);   // brand dark
const _accent   = Color(0xFF3A7CA5);   // blue accent
const _emerald  = Color(0xFF52B788);   // green
const _surface  = Color(0xFFF8F9FA);   // page bg hint
const _card     = Colors.white;
const _border   = Color(0xFFE8ECEF);
const _muted    = Color(0xFF8A9BA8);
const _mutedBg  = Color(0xFFF0F4F7);

// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  final AppState appState;

  const DashboardPage({super.key, required this.appState});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _pageIndex = 0;

  late final List<Widget> _pages;

  final _wfpKey    = GlobalKey<WFPManagementPageState>();
  final _budgetKey = GlobalKey<BudgetOverviewPageState>();

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardHome(
        appState: widget.appState,
        onNavigate: (i) => _onSidebarSelect(i),
      ),
      WFPManagementPage(key: _wfpKey, appState: widget.appState),
      BudgetOverviewPage(key: _budgetKey, appState: widget.appState),
      ReportsPage(appState: widget.appState),
      DeadlinesPage(appState: widget.appState),
      SettingsPage(appState: widget.appState),
      const ProfilePage(),
      AuditLogPage(appState: widget.appState),
    ];
  }

  String _pageName(int index) {
    const names = ['Dashboard', 'WFP Management', 'Budget Overview',
        'Reports', 'Deadlines', 'Settings', 'Profile', 'Audit Log'];
    return index < names.length ? names[index] : 'this page';
  }

  bool get _currentPageDirty {
    if (_pageIndex == 1) return _wfpKey.currentState?.hasUnsavedChanges ?? false;
    if (_pageIndex == 2) return _budgetKey.currentState?.hasUnsavedChanges ?? false;
    return false;
  }

  void _onSidebarSelect(int index) {
    if (index == 8) { _confirmLogout(); return; }
    if (index == _pageIndex) return;
    if (_currentPageDirty) { _confirmDiscard(index); return; }
    setState(() => _pageIndex = index);
  }

  Future<void> _confirmDiscard(int targetIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Text('Unsaved Changes', style: TextStyle(fontSize: 17)),
        ]),
        content: Text('You have unsaved changes in ${_pageName(_pageIndex)}.\n'
            'Discard them and continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard & Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (_pageIndex == 1) _wfpKey.currentState?.clearForm();
      if (_pageIndex == 2) _budgetKey.currentState?.clearForm();
      setState(() => _pageIndex = targetIndex);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(fontSize: 17)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.appState.clearSelectedWFP();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(appState: widget.appState)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Row(
        children: [
          Sidebar(currentIndex: _pageIndex, onSelect: _onSidebarSelect, appState: widget.appState),
          Expanded(
            child: IndexedStack(index: _pageIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Home ───────────────────────────────────────────────────────────

class _DashboardHome extends StatefulWidget {
  final AppState appState;
  final void Function(int) onNavigate;

  const _DashboardHome({required this.appState, required this.onNavigate});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  int? _selectedFiscalYearStart;

  bool _inFiscalYear(WFPEntry e, int startYear) =>
      e.year == startYear || e.year == startYear + 1;

  List<int> _distinctFYStarts(List<WFPEntry> entries) {
    final years = entries.map((e) => e.year).toSet();
    final fyStarts = <int>{};
    for (final y in years) {
      fyStarts.add(y - 1);
      fyStarts.add(y);
    }
    return fyStarts.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final appState      = widget.appState;
        final onNavigate    = widget.onNavigate;
        final allEntries    = appState.wfpEntries;
        final allActivities = appState.allActivities;
        final fyStarts      = _distinctFYStarts(allEntries);

        final entries = _selectedFiscalYearStart == null
            ? allEntries
            : allEntries.where((e) => _inFiscalYear(e, _selectedFiscalYearStart!)).toList();
        final filteredActivities = _selectedFiscalYearStart == null
            ? allActivities
            : allActivities.where((a) {
                final wfp = allEntries.where((e) => e.id == a.wfpId).firstOrNull;
                return wfp != null && _inFiscalYear(wfp, _selectedFiscalYearStart!);
              }).toList();

        final totalBudget    = entries.fold<double>(0, (s, e) => s + e.amount);
        final totalDisbursed = filteredActivities.fold<double>(0, (s, a) => s + a.disbursed);
        final totalBalance   = filteredActivities.fold<double>(0, (s, a) => s + a.balance);

        return LayoutBuilder(builder: (context, constraints) {
          final wide    = constraints.maxWidth > 700;
          final cardGap = wide ? 16.0 : 8.0;

          Widget statCards = wide
              ? Column(children: [
                  Row(children: [
                    Expanded(child: SummaryCard(title: 'Total WFP Entries', value: entries.length.toString())),
                    SizedBox(width: cardGap),
                    Expanded(child: SummaryCard(title: 'Total WFP Budget', value: CurrencyFormatter.format(totalBudget))),
                    SizedBox(width: cardGap),
                    Expanded(child: SummaryCard(title: 'Fund Types Used', value: entries.map((e) => e.fundType).toSet().length.toString())),
                    SizedBox(width: cardGap),
                    Expanded(child: SummaryCard(title: 'Total Activities', value: appState.totalActivityCount.toString())),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: SummaryCard(title: 'Total Disbursed', value: CurrencyFormatter.format(totalDisbursed))),
                    SizedBox(width: cardGap),
                    Expanded(child: SummaryCard(title: 'Total Balance', value: CurrencyFormatter.format(totalBalance))),
                    SizedBox(width: cardGap),
                    const Expanded(child: SizedBox()),
                    SizedBox(width: cardGap),
                    const Expanded(child: SizedBox()),
                  ]),
                ])
              : Wrap(
                  spacing: cardGap, runSpacing: cardGap,
                  children: [
                    SizedBox(width: (constraints.maxWidth - cardGap) / 2 - 1,
                      child: SummaryCard(title: 'Total WFP Entries', value: entries.length.toString())),
                    SizedBox(width: (constraints.maxWidth - cardGap) / 2 - 1,
                      child: SummaryCard(title: 'Total WFP Budget', value: CurrencyFormatter.format(totalBudget))),
                    SizedBox(width: (constraints.maxWidth - cardGap) / 2 - 1,
                      child: SummaryCard(title: 'Fund Types Used', value: entries.map((e) => e.fundType).toSet().length.toString())),
                    SizedBox(width: (constraints.maxWidth - cardGap) / 2 - 1,
                      child: SummaryCard(title: 'Total Activities', value: appState.totalActivityCount.toString())),
                    SizedBox(width: (constraints.maxWidth - cardGap) / 2 - 1,
                      child: SummaryCard(title: 'Total Disbursed', value: CurrencyFormatter.format(totalDisbursed))),
                    SizedBox(width: (constraints.maxWidth - cardGap) / 2 - 1,
                      child: SummaryCard(title: 'Total Balance', value: CurrencyFormatter.format(totalBalance))),
                  ],
                );

          Widget chartsRow = entries.isEmpty
              ? const SizedBox()
              : Column(children: [
                  _BudgetVsDisbursedChart(entries: entries, allActivities: filteredActivities),
                  const SizedBox(height: 16),
                  _FundTypeDistributionChart(entries: entries),
                ]);

          Widget panelsRow = wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(children: [
                    _PanelCard(icon: Icons.list_alt_rounded, title: 'WFP Management',
                      subtitle: '${entries.length} WFP entries recorded',
                      color: _primary, onTap: () => onNavigate(1)),
                    const SizedBox(height: 10),
                    _WFPMiniList(entries: entries, onNavigate: onNavigate),
                  ])),
                  const SizedBox(width: 20),
                  Expanded(child: Column(children: [
                    _PanelCard(icon: Icons.account_balance_wallet_rounded, title: 'Budget Overview',
                      subtitle: 'Total: ${CurrencyFormatter.format(totalBudget)}',
                      color: _accent, onTap: () => onNavigate(2)),
                    const SizedBox(height: 10),
                    _ActivityMiniList(activities: filteredActivities),
                  ])),
                ])
              : Column(children: [
                  _PanelCard(icon: Icons.list_alt_rounded, title: 'WFP Management',
                    subtitle: '${entries.length} WFP entries recorded',
                    color: _primary, onTap: () => onNavigate(1)),
                  const SizedBox(height: 10),
                  _WFPMiniList(entries: entries, onNavigate: onNavigate),
                  const SizedBox(height: 16),
                  _PanelCard(icon: Icons.account_balance_wallet_rounded, title: 'Budget Overview',
                    subtitle: 'Total: ${CurrencyFormatter.format(totalBudget)}',
                    color: _accent, onTap: () => onNavigate(2)),
                  const SizedBox(height: 10),
                  _ActivityMiniList(activities: filteredActivities),
                ]);

          // Fiscal year selector
          final fySelector = fyStarts.isEmpty ? const SizedBox() : _FYSelector(
            fyStarts: fyStarts,
            selected: _selectedFiscalYearStart,
            onChanged: (v) => setState(() => _selectedFiscalYearStart = v),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Dashboard',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                          color: _ink, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('Welcome to PIMS DepED',
                      style: TextStyle(color: _muted, fontSize: 13)),
                  ]),
                  const Spacer(),
                  fySelector,
                ]),
                const SizedBox(height: 28),
                statCards,
                const SizedBox(height: 28),
                chartsRow,
                if (entries.isNotEmpty) const SizedBox(height: 28),
                panelsRow,
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }
}

// ─── Fiscal Year Selector ─────────────────────────────────────────────────────

class _FYSelector extends StatelessWidget {
  final List<int> fyStarts;
  final int? selected;
  final ValueChanged<int?> onChanged;

  const _FYSelector({required this.fyStarts, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.date_range_outlined, size: 15, color: _muted),
        const SizedBox(width: 6),
        Text('Fiscal Year', style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(width: 8),
        DropdownButton<int?>(
          value: selected,
          isDense: true,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w600),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _muted),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
            ...fyStarts.map((y) => DropdownMenuItem<int?>(
              value: y, child: Text('FY $y–${y + 1}'))),
          ],
          onChanged: onChanged,
        ),
        if (selected != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(null),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _mutedBg, borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.close_rounded, size: 13, color: _muted),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── WFP Mini List ────────────────────────────────────────────────────────────

class _WFPMiniList extends StatelessWidget {
  final List<WFPEntry> entries;
  final void Function(int) onNavigate;

  const _WFPMiniList({required this.entries, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return _emptyMiniList('No WFP entries yet.');
    return _MiniListCard(
      children: entries.map((e) => InkWell(
        onTap: () => onNavigate(1),
        hoverColor: _mutedBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(width: 108, child: Text(e.id,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10,
                  color: _accent, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
            Expanded(child: Text(e.title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _ink),
              overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            _Tag(e.fundType, bg: _mutedBg, fg: _primary),
            const SizedBox(width: 8),
            SizedBox(width: 100, child: Text(CurrencyFormatter.format(e.amount),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
              textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            SizedBox(width: 36, child: Text(e.year.toString(),
              style: const TextStyle(fontSize: 11, color: _muted),
              textAlign: TextAlign.right)),
          ]),
        ),
      )).toList(),
    );
  }
}

// ─── Activity Mini List ───────────────────────────────────────────────────────

class _ActivityMiniList extends StatelessWidget {
  final List<BudgetActivity> activities;

  const _ActivityMiniList({required this.activities});

  static Color _statusColor(String s) {
    switch (s) {
      case 'Completed': return const Color(0xFF2D6A4F);
      case 'Ongoing':   return _accent;
      case 'At Risk':   return const Color(0xFFB00020);
      default:          return _muted;
    }
  }

  static Color _statusBg(String s) {
    switch (s) {
      case 'Completed': return const Color(0xFFE8F5EE);
      case 'Ongoing':   return const Color(0xFFE3F0F8);
      case 'At Risk':   return const Color(0xFFFCE8EB);
      default:          return _mutedBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return _emptyMiniList('No budget activities yet.');
    return _MiniListCard(
      children: activities.map((a) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(width: 108, child: Text(a.id,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10,
                color: _accent, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
          Expanded(child: Text(a.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _ink),
            overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _Tag(a.status, bg: _statusBg(a.status), fg: _statusColor(a.status)),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(CurrencyFormatter.format(a.total),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
            textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
        ]),
      )).toList(),
    );
  }
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color bg, fg;

  const _Tag(this.label, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Mini-list card ───────────────────────────────────────────────────────────

class _MiniListCard extends StatelessWidget {
  final List<Widget> children;
  const _MiniListCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: children.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: _border),
          itemBuilder: (_, i) => children[i],
        ),
      ),
    );
  }
}

Widget _emptyMiniList(String message) {
  return Container(
    height: 220,
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 32, color: _border),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: _muted, fontSize: 13)),
      ]),
    ),
  );
}

// ─── Budget vs Disbursed Bar Chart ────────────────────────────────────────────

class _BudgetVsDisbursedChart extends StatefulWidget {
  final List<WFPEntry> entries;
  final List<BudgetActivity> allActivities;

  const _BudgetVsDisbursedChart({required this.entries, required this.allActivities});

  @override
  State<_BudgetVsDisbursedChart> createState() => _BudgetVsDisbursedChartState();
}

class _BudgetVsDisbursedChartState extends State<_BudgetVsDisbursedChart> {
  int? _hoveredIndex;

  String _compact(double v) {
    if (v >= 1000000) return '${CurrencyFormatter.symbol}${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${CurrencyFormatter.symbol}${(v / 1000).toStringAsFixed(0)}K';
    return '${CurrencyFormatter.symbol}${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final disbursedByWfp = <String, double>{};
    for (final a in widget.allActivities) {
      disbursedByWfp[a.wfpId] = (disbursedByWfp[a.wfpId] ?? 0) + a.disbursed;
    }
    final chartEntries = widget.entries.take(6).toList();
    final maxVal = chartEntries.fold<double>(1, (m, e) {
      final d = disbursedByWfp[e.id] ?? 0;
      return [m, e.amount, d].reduce((a, b) => a > b ? a : b);
    });

    const gridLines    = 4;
    final yStep        = maxVal / gridLines;
    const maxBarHeight = 120.0;
    const yAxisWidth   = 52.0;
    const xLabelHeight = 32.0;
    const tooltipH     = 100.0;
    const kChartBuffer = 10.0;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AR vs Disbursed',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                      color: _ink, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                const Text('Per WFP entry — most recent 6',
                  style: TextStyle(fontSize: 11, color: _muted)),
              ])),
              // Legend
              Row(mainAxisSize: MainAxisSize.min, children: [
                _LegendDot(color: _primary, label: 'Total AR'),
                const SizedBox(width: 14),
                _LegendDot(color: _accent, label: 'Disbursed'),
                const SizedBox(width: 14),
                _LegendDot(color: _emerald, label: 'Balance'),
              ]),
            ]),
            const SizedBox(height: 16),

            SizedBox(
              height: tooltipH + maxBarHeight + xLabelHeight + kChartBuffer,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: yAxisWidth,
                    height: tooltipH + maxBarHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(gridLines + 1, (i) {
                        final val   = yStep * (gridLines - i);
                        final topPx = tooltipH + (i / gridLines) * maxBarHeight;
                        return Positioned(
                          top: topPx - 6, right: 6,
                          child: Text(_compact(val),
                            style: const TextStyle(fontSize: 9, color: _muted),
                            textAlign: TextAlign.right),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: tooltipH + maxBarHeight + xLabelHeight + kChartBuffer,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Gridlines — very subtle
                          ...List.generate(gridLines + 1, (i) {
                            final topPx = tooltipH + (i / gridLines) * maxBarHeight;
                            return Positioned(
                              top: topPx, left: 0, right: 0,
                              child: Container(height: 1, color: _border),
                            );
                          }),
                          Positioned(
                            top: 0, left: 0, right: 0,
                            height: tooltipH + maxBarHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: chartEntries.asMap().entries.map((mapEntry) {
                                final idx       = mapEntry.key;
                                final e         = mapEntry.value;
                                final budget    = e.amount;
                                final disbursed = disbursedByWfp[e.id] ?? 0;
                                final balance   = (budget - disbursed).clamp(0.0, double.infinity);
                                final isHovered = _hoveredIndex == idx;

                                final budgetH    = maxVal > 0 ? (budget    / maxVal * maxBarHeight).clamp(2.0, maxBarHeight) : 2.0;
                                final disbursedH = maxVal > 0 ? (disbursed / maxVal * maxBarHeight).clamp(0.0, maxBarHeight) : 0.0;
                                final balanceH   = maxVal > 0 ? (balance   / maxVal * maxBarHeight).clamp(0.0, maxBarHeight) : 0.0;

                                return Expanded(
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() => _hoveredIndex = idx),
                                    onExit:  (_) => setState(() => _hoveredIndex = null),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                          height: tooltipH,
                                          child: isHovered ? Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 8),
                                              constraints: const BoxConstraints(maxWidth: 160),
                                              decoration: BoxDecoration(
                                                color: _ink,
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.2),
                                                  blurRadius: 12, offset: const Offset(0, 4))],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(e.id, style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.5),
                                                    fontSize: 8, fontFamily: 'monospace')),
                                                  Text(e.title, style: const TextStyle(
                                                    color: Colors.white, fontWeight: FontWeight.w600,
                                                    fontSize: 10),
                                                    overflow: TextOverflow.ellipsis, maxLines: 1),
                                                  const SizedBox(height: 5),
                                                  _tooltipRow('Total AR',  budget,    _primary),
                                                  _tooltipRow('Disbursed', disbursed, _accent),
                                                  _tooltipRow('Balance',   balance,   _emerald),
                                                ],
                                              ),
                                            ),
                                          ) : null,
                                        ),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _Bar(height: budgetH,    color: _primary,  hovered: isHovered),
                                            const SizedBox(width: 3),
                                            _Bar(height: disbursedH, color: _accent,   hovered: isHovered),
                                            const SizedBox(width: 3),
                                            _Bar(height: balanceH,   color: _emerald,  hovered: isHovered),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Positioned(
                            top: tooltipH + maxBarHeight, left: 0, right: 0,
                            height: xLabelHeight,
                            child: Row(
                              children: chartEntries.asMap().entries.map((mapEntry) {
                                final idx       = mapEntry.key;
                                final e         = mapEntry.value;
                                final isHovered = _hoveredIndex == idx;
                                return Expanded(child: Center(child: Text(
                                  "${e.fundType}\n'${e.year.toString().substring(2)}",
                                  style: TextStyle(fontSize: 9,
                                    color: isHovered ? _ink : _muted,
                                    fontWeight: isHovered ? FontWeight.w700 : FontWeight.normal),
                                  textAlign: TextAlign.center)));
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tooltipRow(String label, double value, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label: ${_compact(value)}',
          style: const TextStyle(color: Colors.white, fontSize: 9)),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color  color;
  final bool   hovered;

  const _Bar({required this.height, required this.color, required this.hovered});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: hovered ? 14 : 11,
      height: height.clamp(2.0, double.infinity),
      decoration: BoxDecoration(
        color: hovered ? color : color.withValues(alpha: 0.78),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}

// ─── Fund Type Distribution Chart ────────────────────────────────────────────

class _FundTypeDistributionChart extends StatelessWidget {
  final List<WFPEntry> entries;

  const _FundTypeDistributionChart({required this.entries});

  static const _palette = [
    Color(0xFF2F3E46), Color(0xFF3A7CA5), Color(0xFF52B788),
    Color(0xFFE76F51), Color(0xFF9B5DE5), Color(0xFFF4A261),
    Color(0xFF2EC4B6), Color(0xFFE63946), Color(0xFF457B9D),
    Color(0xFF6A994E), Color(0xFFF77F00), Color(0xFF8338EC),
    Color(0xFF06D6A0),
  ];

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final e in entries) {
      totals[e.fundType] = (totals[e.fundType] ?? 0) + e.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final grandTotal = sorted.fold<double>(0, (s, e) => s + e.value);
    final maxVal     = sorted.isEmpty ? 1.0 : sorted.first.value;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fund Type Distribution',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                  color: _ink, letterSpacing: -0.2)),
            const SizedBox(height: 2),
            const Text('Total budget by fund type',
              style: TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(height: 20),
            if (sorted.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart_outlined, size: 36, color: _border),
                  const SizedBox(height: 8),
                  const Text('No entries yet.', style: TextStyle(color: _muted, fontSize: 13)),
                ]),
              ))
            else
              ...sorted.asMap().entries.map((mapEntry) {
                final idx       = mapEntry.key;
                final fundEntry = mapEntry.value;
                final color     = _palette[idx % _palette.length];
                final barRatio  = maxVal > 0 ? fundEntry.value / maxVal : 0.0;
                final pct       = grandTotal > 0
                    ? (fundEntry.value / grandTotal * 100).toStringAsFixed(1)
                    : '0.0';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Expanded(child: Text(fundEntry.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                            color: _ink),
                        overflow: TextOverflow.ellipsis)),
                      Text('$pct%',
                        style: const TextStyle(fontSize: 11, color: _muted,
                            fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      SizedBox(width: 82, child: Text(
                        CurrencyFormatter.format(fundEntry.value),
                        style: const TextStyle(fontSize: 10, color: _ink,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barRatio,
                          minHeight: 5,
                          backgroundColor: _mutedBg,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─── Panel Card ───────────────────────────────────────────────────────────────

class _PanelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PanelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: _mutedBg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(
                  color: _muted, fontSize: 12)),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _muted.withValues(alpha: 0.7)),
          ]),
        ),
      ),
    );
  }
}