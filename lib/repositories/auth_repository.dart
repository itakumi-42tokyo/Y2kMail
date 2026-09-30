// 認証を抽象化するリポジトリ。
// 画面はこのクラスだけを見て実装し、Supabaseを直接知らない。
// 将来バックエンドをRailsに移行するときは、この抽象クラスに対する
// 別の実装（RailsAuthRepositoryなど）を用意すればよい。
abstract class AuthRepository {
  /// ログイン状態が変わるたびに、サインイン中かどうかを流すストリーム。
  Stream<bool> get isSignedInStream;

  /// 現在ログインしている利用者のID。ログインしていなければnull。
  String? get currentUserId;

  /// メールアドレス宛てに、ログイン用リンク（マジックリンク）を送る。
  /// リンクをタップしてアプリに戻ってくると、自動でログインが完了する。
  Future<void> sendEmailOtp(String email);

  /// Googleアカウントでログインする。
  Future<void> signInWithGoogle();

  /// ログアウトする。
  Future<void> signOut();
}
