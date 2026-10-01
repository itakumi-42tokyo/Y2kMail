import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/mail_repository.dart';
import '../repositories/profile_repository.dart';
import 'debug_photo_preview_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.friendRepository,
    required this.mailRepository,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final FriendRepository friendRepository;
  final MailRepository mailRepository;

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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendsScreen(
                    friendRepository: friendRepository,
                    mailRepository: mailRepository,
                  ),
                ),
              ),
              icon: const Icon(Icons.contacts),
              label: const Text('電話帳'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: authRepository.signOut,
              child: const Text('ログアウト'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DebugPhotoPreviewScreen(),
                ),
              ),
              child: const Text('画質変換の確認（開発用）'),
            ),
          ],
        ),
      ),
    );
  }
}
