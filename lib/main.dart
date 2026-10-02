import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'engine/bdf_font.dart';
import 'engine/font_loader.dart';
import 'repositories/auth_repository.dart';
import 'repositories/supabase_auth_repository.dart';
import 'screens_px/login_screen.dart';
import 'screens_px/menu_screen.dart';

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
    // MaterialApp/Scaffold等は使わず、WidgetsAppを土台にする。
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
  late final AuthRepository _auth =
      SupabaseAuthRepository(Supabase.instance.client);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: FutureBuilder<BdfFont>(
        future: _fontFuture,
        builder: (context, fontSnap) {
          if (!fontSnap.hasData) {
            // フォント読み込み中は黒画面。
            return const ColoredBox(color: Color(0xFF000000));
          }
          final font = fontSnap.data!;
          // ログイン状態で画面を出し分ける。
          return StreamBuilder<bool>(
            stream: _auth.isSignedInStream,
            initialData: _auth.currentUserId != null,
            builder: (context, authSnap) {
              final signedIn = authSnap.data ?? false;
              if (signedIn) {
                return MenuScreen(font: font, onLogout: _auth.signOut);
              }
              return LoginScreen(font: font, authRepository: _auth);
            },
          );
        },
      ),
    );
  }
}
