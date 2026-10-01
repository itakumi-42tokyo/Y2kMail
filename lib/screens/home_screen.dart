import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.authRepository,
    required this.profileRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圏外')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FutureBuilder<String>(
              future: profileRepository.fetchDisplayName(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                return Text('ログイン中: ${snapshot.data}');
              },
            ),
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
