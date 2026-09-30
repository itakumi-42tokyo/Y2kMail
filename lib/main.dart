import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'repositories/auth_repository.dart';
import 'repositories/supabase_auth_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // プラグイン（今回はSupabaseのセッション保存）を使う前に必要な初期化。
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(KengaiApp(authRepository: SupabaseAuthRepository(Supabase.instance.client)));
}

class KengaiApp extends StatelessWidget {
  const KengaiApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '圏外',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: AuthGate(authRepository: authRepository),
    );
  }
}

// ログイン状態の変化をStreamBuilderで監視し、
// サインイン中ならホーム画面、そうでなければログイン画面を表示する。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: authRepository.isSignedInStream,
      initialData: authRepository.currentUserId != null,
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data ?? false;
        if (isSignedIn) {
          return HomeScreen(authRepository: authRepository);
        }
        return LoginScreen(authRepository: authRepository);
      },
    );
  }
}
