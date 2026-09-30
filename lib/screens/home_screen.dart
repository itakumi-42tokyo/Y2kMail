import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圏外')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ログイン中: ${authRepository.currentUserId}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: authRepository.signOut,
              child: const Text('ログアウト'),
            ),
          ],
        ),
      ),
    );
  }
}
