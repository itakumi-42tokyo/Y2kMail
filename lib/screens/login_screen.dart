import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();

  bool _sent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.sendEmailOtp(_emailController.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圏外 - ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_sent) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _sendLink,
                child: const Text('ログイン用リンクを送る'),
              ),
            ] else
              Text(
                '${_emailController.text} にログイン用のメールを送りました。\n'
                'メール内のリンクをタップすると、このアプリに戻ってログインが完了します。',
                textAlign: TextAlign.center,
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
