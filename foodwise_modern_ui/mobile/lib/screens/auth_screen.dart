
import 'package:flutter/material.dart';
import '../services/api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.onLogin,
  });

  final Api api;
  final VoidCallback onLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool registerMode = false;
  bool busy = false;
  bool showPassword = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      final userEmail = email.text.trim().toLowerCase();
      final userPassword = password.text;

      if (registerMode) {
        // api.register() automatically logs in
        // after successful registration.
        await widget.api.register(
          name.text.trim(),
          userEmail,
          userPassword,
        );
      } else {
        await widget.api.login(
          userEmail,
          userPassword,
        );
      }

      if (!mounted) return;

      widget.onLogin();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodWise'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  registerMode
                      ? 'Create account'
                      : 'Welcome back',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium,
                ),

                const SizedBox(height: 24),

                if (registerMode) ...[
                  TextFormField(
                    controller: name,
                    textCapitalization:
                    TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(text)) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: password,
                  obscureText: !showPassword,
                  autofillHints: [
                    registerMode
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password (min 8 characters)',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }

                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!busy) submit();
                  },
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                    ),
                    child: busy
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      registerMode
                          ? 'Register'
                          : 'Login',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                    setState(() {
                      registerMode = !registerMode;
                      showPassword = false;
                      _formKey.currentState?.reset();
                    });
                  },
                  child: Text(
                    registerMode
                        ? 'Already have an account? Login'
                        : 'New user? Register',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
