import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

// アプリからSupabaseに接続する部分を、直接ではなくこのクラス経由にする。
// 「移行を見据えた設計ルール」に沿って、Supabase固有のAPIはここだけに閉じ込める。
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  // onAuthStateChangeはSupabaseのログイン状態の変化を通知するStream。
  // .map()で「サインイン中かどうか(bool)」だけを取り出した、別のStreamに変換している。
  @override
  Stream<bool> get isSignedInStream => _client.auth.onAuthStateChange
      .map((event) => event.session != null);

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> sendEmailOtp(String email) {
    return _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'io.supabase.kengai://login-callback/',
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.kengai://login-callback/',
    );
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
