import 'package:flutter/material.dart';
import '../services/app_state.dart';

class Sidebar extends StatelessWidget {
  final Function(int) onSelect;
  final int currentIndex;
  final AppState appState;

  const Sidebar({
    super.key,
    required this.onSelect,
    required this.appState,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Container(
          width: 220,
          color: const Color(0xff2F3E46),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'PIMS DepED',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'DepED Management System',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _item(Icons.dashboard_outlined, 'Dashboard', 0),
              _item(Icons.list_alt_outlined, 'WFP Management', 1),
              _item(Icons.account_balance_wallet_outlined, 'Budget Overview', 2),
              _item(Icons.summarize_outlined, 'Reports', 3),
              _badgeItem(Icons.schedule_outlined, 'Deadlines', 4, appState.deadlineWarningCount),
              _item(Icons.settings_outlined, 'Settings', 5),
              _item(Icons.person_outline, 'Profile', 6),
              _item(Icons.history, 'Audit Log', 7),
              const Spacer(),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),
              _item(Icons.logout, 'Log Out', 8),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _item(IconData icon, String label, int index) {
    final active = currentIndex == index && index != 8;
    return _tile(icon, label, index, active, null);
  }

  Widget _badgeItem(IconData icon, String label, int index, int count) {
    final active = currentIndex == index;
    return _tile(icon, label, index, active, count > 0 ? count : null);
  }

  Widget _tile(IconData icon, String label, int index, bool active, int? badge) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: active ? Colors.white : Colors.white70, size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: () => onSelect(index),
      ),
    );
  }
}
