import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.login(
        name: _nameController.text,
        password: _passwordController.text,
      );
    } catch (_) {
      setState(() {
        _error = 'Nombre o contraseña incorrectos';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 350,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Party Likes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('Ingresar'),
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