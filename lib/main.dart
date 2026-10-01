import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'repositories/auth_repository.dart';
import 'repositories/friend_repository.dart';
import 'repositories/mail_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/supabase_auth_repository.dart';
import 'repositories/supabase_friend_repository.dart';
import 'repositories/supabase_mail_repository.dart';
import 'repositories/supabase_profile_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';

Future<void> main() async {
  // プラグイン（今回はSupabaseのセッション保存）を使う前に必要な初期化。
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final client = Supabase.instance.client;
  runApp(KengaiApp(
    authRepository: SupabaseAuthRepository(client),
    profileRepository: SupabaseProfileRepository(client),
    friendRepository: SupabaseFriendRepository(client),
    mailRepository: SupabaseMailRepository(client),
  ));
}

class KengaiApp extends StatelessWidget {
  const KengaiApp({
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
    return MaterialApp(
      title: '圏外',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: AuthGate(
        authRepository: authRepository,
        profileRepository: profileRepository,
        friendRepository: friendRepository,
        mailRepository: mailRepository,
      ),
    );
  }
}

// ログイン状態の変化をStreamBuilderで監視し、
// サインイン中なら_ProfileGate、そうでなければログイン画面を表示する。
class AuthGate extends StatelessWidget {
  const AuthGate({
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
    return StreamBuilder<bool>(
      stream: authRepository.isSignedInStream,
      initialData: authRepository.currentUserId != null,
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data ?? false;
        if (!isSignedIn) {
          return LoginScreen(authRepository: authRepository);
        }
        return _ProfileGate(
          authRepository: authRepository,
          profileRepository: profileRepository,
          friendRepository: friendRepository,
          mailRepository: mailRepository,
        );
      },
    );
  }
}

// ログイン済みの人だけを対象に、プロフィール（表示名）が
// すでにあるかを確認し、なければ作成画面を挟む。
class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
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
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<bool> _hasProfileFuture;

  @override
  void initState() {
    super.initState();
    _hasProfileFuture = widget.profileRepository.hasProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProfileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!) {
          return HomeScreen(
            authRepository: widget.authRepository,
            profileRepository: widget.profileRepository,
            friendRepository: widget.friendRepository,
            mailRepository: widget.mailRepository,
          );
        }
        return ProfileSetupScreen(
          profileRepository: widget.profileRepository,
          onCreated: () => setState(() {
            _hasProfileFuture = Future.value(true);
          }),
        );
      },
    );
  }
}
