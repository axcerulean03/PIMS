import 'package:flutter/material.dart';
import '../services/app_state.dart';

class SettingsPage extends StatefulWidget {
  final AppState appState;
  const SettingsPage({super.key, required this.appState});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _operatingUnitCtrl;
  late final TextEditingController _currencyCtrl;
  bool _savingUnit     = false;
  bool _savingCurrency = false;

  @override
  void initState() {
    super.initState();
    _operatingUnitCtrl = TextEditingController(text: widget.appState.operatingUnit);
    _currencyCtrl      = TextEditingController(text: widget.appState.currencySymbol);
  }

  @override
  void dispose() {
    _operatingUnitCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveOperatingUnit() async {
    setState(() => _savingUnit = true);
    await widget.appState.setOperatingUnit(_operatingUnitCtrl.text);
    if (mounted) {
      setState(() => _savingUnit = false);
      _showSnack('Operating unit saved.');
    }
  }

  Future<void> _saveCurrency() async {
    if (_currencyCtrl.text.trim().isEmpty) {
      _showSnack('Currency symbol cannot be empty.', isError: true);
      return;
    }
    setState(() => _savingCurrency = true);
    await widget.appState.setCurrencySymbol(_currencyCtrl.text);
    if (mounted) {
      setState(() => _savingCurrency = false);
      _showSnack('Currency symbol saved.');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                    color: Color(0xff2F3E46))),
              const SizedBox(height: 4),
              Text('System preferences and configuration.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 32),

              // ── Organization Settings ─────────────────────────────────
              _settingsCard(
                title: 'Organization',
                icon: Icons.business_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Operating Unit',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'This name appears in Excel and PDF report headers.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _operatingUnitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Operating Unit Name',
                            hintText: 'Department of Education',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2F3E46),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _savingUnit ? null : _saveOperatingUnit,
                        child: _savingUnit
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save'),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Current: ${widget.appState.operatingUnit}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Currency Settings ─────────────────────────────────────
              _settingsCard(
                title: 'Currency',
                icon: Icons.attach_money_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Currency Symbol',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Shown before all monetary values throughout the app.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _currencyCtrl,
                          maxLength: 5,
                          decoration: const InputDecoration(
                            labelText: 'Symbol',
                            hintText: '₱',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2F3E46),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _savingCurrency ? null : _saveCurrency,
                        child: _savingCurrency
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save'),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Preview: ${widget.appState.currencySymbol}1,234,567.89',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff2F3E46),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Current: "${widget.appState.currencySymbol}"',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Deadline Notifications ────────────────────────────────
              _settingsCard(
                title: 'Deadline Notifications',
                icon: Icons.schedule_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Warning Window',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      'Show a badge on the Deadlines sidebar item when a WFP due date '
                      'or activity target date is within this many days.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      children: [7, 14, 30].map((days) {
                        final selected = widget.appState.warningDays == days;
                        return ChoiceChip(
                          label: Text('$days days'),
                          selected: selected,
                          selectedColor: const Color(0xff2F3E46),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : const Color(0xff2F3E46),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => widget.appState.setWarningDays(days),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current: ${widget.appState.warningDays} days  •  '
                      '${widget.appState.deadlineWarningCount} item(s) flagged right now',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.appState.deadlineWarningCount > 0
                            ? Colors.red.shade600 : Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── App Info ──────────────────────────────────────────────
              _settingsCard(
                title: 'Application',
                icon: Icons.info_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('System', 'PIMS DepED — Personnel Information Management System'),
                    const SizedBox(height: 8),
                    _infoRow('Agency', widget.appState.operatingUnit),
                    const SizedBox(height: 8),
                    _infoRow('Database', 'Documents/pims_deped.db (SQLite)'),
                    const SizedBox(height: 8),
                    _infoRow('Currency', widget.appState.currencySymbol),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xff2F3E46), size: 20),
              const SizedBox(width: 10),
              Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: Color(0xff2F3E46))),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90,
        child: Text(label,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
              color: Colors.grey.shade600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
    ]);
  }
}