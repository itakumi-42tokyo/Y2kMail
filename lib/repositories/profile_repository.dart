import 'dart:typed_data';

abstract class ProfileRepository {
  /// 今ログイン中の利用者の行が、profilesテーブルにすでにあるか。
  Future<bool> hasProfile();

  /// 表示名を指定して、自分のプロフィール行を作る。
  Future<void> createProfile(String displayName);

  /// 今ログイン中の利用者の表示名を取得する。
  Future<String> fetchDisplayName();

  /// 自己紹介写真を設定する。元の写真を端末内でガラケー加工してから保存する。
  Future<void> setIntroPhoto(Uint8List originalPhotoBytes);

  /// 設定済みの自己紹介写真を取得する。未設定ならnull。
  Future<Uint8List?> fetchIntroPhoto();
}
