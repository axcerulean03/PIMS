import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  final AppState appState;

  const LoginPage({super.key, required this.appState});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  void _login() {
    // Basic validation — replace with real auth logic when ready.
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username and password.');
      return;
    }

    // TODO: Replace with actual credential check.
    setState(() => _errorMessage = null);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(appState: widget.appState),
      ),
    );
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Title
                  const Text(
                    'PIMS DepED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff2F3E46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Personnel Information Management System',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),

                  const SizedBox(height: 32),

                  // Error banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Username
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _login(),
                  ),

                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),

                  const SizedBox(height: 28),

                  // Login button
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2F3E46),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _login,
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
