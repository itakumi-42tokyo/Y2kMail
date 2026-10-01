import '../models/friend.dart';

/// 友達交換の結果。画面にメッセージを出すために使う。
enum RedeemResult { success, alreadyFriends, invalid, expired, used, selfQr, error }

/// 近距離でのアドレス交換（QR）と友達一覧を扱うリポジトリ。
/// トークンの発行・検証はサーバー側（Edge Function）に任せる。
abstract class FriendRepository {
  /// 自分のQR表示用に、ワンタイムの交換トークンを発行する。
  Future<String> issueExchangeToken();

  /// 読み取ったトークンで友達になる。結果を種類で返す。
  Future<RedeemResult> redeemToken(String token);

  /// 今の友達一覧を取得する。
  Future<List<Friend>> fetchFriends();
}
