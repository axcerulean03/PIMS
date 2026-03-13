import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../widgets/sidebar.dart';
import '../widgets/summary_card.dart';
import 'wfp_management_page.dart';
import 'budget_overview_page.dart';
import 'login_page.dart';
import '../utils/currency_formatter.dart';

class DashboardPage extends StatefulWidget {
  final AppState appState;

  const DashboardPage({super.key, required this.appState});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _pageIndex = 0;

  // ── IMPORTANT: pages are created ONCE here, not inside build().
  // IndexedStack keeps all three widgets alive in the tree at all times,
  // so their State objects (and local controllers) are never destroyed
  // when the user switches between sections.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardHome(
        appState: widget.appState,
        onNavigate: (i) => setState(() => _pageIndex = i),
      ),
      WFPManagementPage(appState: widget.appState),
      BudgetOverviewPage(appState: widget.appState),
    ];
  }

  void _onSidebarSelect(int index) {
    if (index == 3) {
      _confirmLogout();
      return;
    }
    setState(() => _pageIndex = index);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
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
      body: Row(
        children: [
          Sidebar(currentIndex: _pageIndex, onSelect: _onSidebarSelect),
          // IndexedStack renders all pages but only shows the active one.
          // This keeps each page's State alive — no resets on tab switch.
          Expanded(
            child: IndexedStack(index: _pageIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Home ───────────────────────────────────────────────────────────

class _DashboardHome extends StatelessWidget {
  final AppState appState;
  final void Function(int) onNavigate;

  const _DashboardHome({required this.appState, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final entries = appState.wfpEntries;
        final totalBudget = entries.fold<double>(0, (s, e) => s + e.amount);

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff2F3E46),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome to PIMS DepED',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 32),

              // Panel cards
              Row(
                children: [
                  Expanded(
                    child: _PanelCard(
                      icon: Icons.list_alt,
                      title: 'WFP Management',
                      subtitle: '${entries.length} WFP entries recorded',
                      color: const Color(0xff2F3E46),
                      onTap: () => onNavigate(1),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _PanelCard(
                      icon: Icons.account_balance_wallet,
                      title: 'Budget Overview',
                      subtitle:
                          'Total: ${CurrencyFormatter.format(totalBudget)}',
                      color: const Color(0xff3A7CA5),
                      onTap: () => onNavigate(2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Total WFP Entries',
                      value: entries.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SummaryCard(
                      title: 'Total WFP Budget',
                      value: CurrencyFormatter.format(totalBudget),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SummaryCard(
                      title: 'Fund Types Used',
                      value: entries
                          .map((e) => e.fundType)
                          .toSet()
                          .length
                          .toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
