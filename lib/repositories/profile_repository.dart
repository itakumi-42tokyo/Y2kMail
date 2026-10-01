abstract class ProfileRepository {
  /// 今ログイン中の利用者の行が、profilesテーブルにすでにあるか。
  Future<bool> hasProfile();

  /// 表示名を指定して、自分のプロフィール行を作る。
  Future<void> createProfile(String displayName);

  /// 今ログイン中の利用者の表示名を取得する。
  Future<String> fetchDisplayName();
}
