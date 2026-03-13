import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

void main() async {
  // Required before any async work or plugin initialization.
  WidgetsFlutterBinding.ensureInitialized();

  // Boot the shared state and pre-load WFP entries from SQLite.
  final appState = AppState();
  await appState.init();

  runApp(PIMSApp(appState: appState));
}

class PIMSApp extends StatelessWidget {
  final AppState appState;

  const PIMSApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PIMS DepED',
      debugShowCheckedModeBanner: false,
      // Use the centrally-defined theme instead of an inline one.
      theme: AppTheme.theme,
      home: LoginPage(appState: appState),
    );
  }
}
