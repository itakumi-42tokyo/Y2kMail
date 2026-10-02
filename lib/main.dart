import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'engine/bdf_font.dart';
import 'engine/font_loader.dart';
import 'repositories/auth_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/supabase_auth_repository.dart';
import 'repositories/supabase_profile_repository.dart';
import 'screens_px/login_screen.dart';
import 'screens_px/menu_screen.dart';
import 'screens_px/profile_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const KengaiApp());
}

class KengaiApp extends StatelessWidget {
  const KengaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(settings, builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (c, a, b) => builder(c)),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final Future<BdfFont> _fontFuture = loadUnifont();
  final _client = Supabase.instance.client;
  late final AuthRepository _auth = SupabaseAuthRepository(_client);
  late final ProfileRepository _profile = SupabaseProfileRepository(_client);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: FutureBuilder<BdfFont>(
        future: _fontFuture,
        builder: (context, fontSnap) {
          if (!fontSnap.hasData) {
            return const ColoredBox(color: Color(0xFF000000));
          }
          final font = fontSnap.data!;
          return StreamBuilder<bool>(
            stream: _auth.isSignedInStream,
            initialData: _auth.currentUserId != null,
            builder: (context, authSnap) {
              final signedIn = authSnap.data ?? false;
              if (!signedIn) {
                return LoginScreen(font: font, authRepository: _auth);
              }
              return _ProfileGate(
                font: font,
                auth: _auth,
                profile: _profile,
              );
            },
          );
        },
      ),
    );
  }
}

// ログイン済みの人に、プロフィール（表示名）が無ければ作成画面を挟む。
class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
    required this.font,
    required this.auth,
    required this.profile,
  });

  final BdfFont font;
  final AuthRepository auth;
  final ProfileRepository profile;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<bool> _hasProfile = widget.profile.hasProfile();

  void _onActivate(String item) {
    switch (item) {
      case 'ログアウト':
        widget.auth.signOut();
      // ほかの項目（電話帳・自己紹介・着せ替え）は移植でき次第つなぐ。
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProfile,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const ColoredBox(color: Color(0xFF000000));
        }
        if (!snap.data!) {
          return ProfileSetupScreen(
            font: widget.font,
            profileRepository: widget.profile,
            onCreated: () => setState(() {
              _hasProfile = Future.value(true);
            }),
          );
        }
        return MenuScreen(
          font: widget.font,
          profileRepository: widget.profile,
          onActivate: _onActivate,
        );
      },
    );
  }
}
