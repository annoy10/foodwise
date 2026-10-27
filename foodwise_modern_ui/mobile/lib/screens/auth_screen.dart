import 'package:flutter/material.dart';
import '../services/api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onLogin});
  final Api api;
  final VoidCallback onLogin;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registerMode = false;
  bool busy = false;

  @override
  void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (registerMode) {
        await widget.api.register(name.text.trim(), email.text.trim(), password.text);
      } else {
        await widget.api.login(email.text.trim(), password.text);
      }
      if (mounted) widget.onLogin();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FoodWise')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        Text(registerMode ? 'Create account' : 'Welcome back', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        if (registerMode) TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 8 characters)')),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : registerMode ? 'Register' : 'Login')),
        TextButton(onPressed: busy ? null : () => setState(() => registerMode = !registerMode),
          child: Text(registerMode ? 'Already have an account? Login' : 'New user? Register')),
      ]),
    )),
  );
}
