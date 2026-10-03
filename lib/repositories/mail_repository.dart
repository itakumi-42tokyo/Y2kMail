import 'dart:typed_data';

import '../models/mail.dart';

/// メール送受信を扱うリポジトリ。
/// 受信BOX・送信BOXはスレッドにせず、時系列のページ送りで扱う。
abstract class MailRepository {
  /// 受信メールの総数（ページ数の算出用）。
  Future<int> countInbox();

  /// 送信メールの総数。
  Future<int> countOutbox();

  /// 受信メールを新しい順に1ページ取得する。
  Future<List<Mail>> fetchInbox({required int page, required int pageSize});

  /// 送信メールを新しい順に1ページ取得する。
  Future<List<Mail>> fetchOutbox({required int page, required int pageSize});

  /// メールを送る。本文か写真のどちらかは必須。
  /// [originalPhotoBytes] は元の写真。端末内でガラケー加工してからアップロードする。
  Future<void> sendMail({
    required String receiverId,
    String? subject,
    String? body,
    Uint8List? originalPhotoBytes,
  });

  /// メールに添付された写真（加工済み）をダウンロードする。
  Future<Uint8List> downloadPhoto(String photoPath);
}
