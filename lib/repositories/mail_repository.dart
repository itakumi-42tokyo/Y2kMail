import 'dart:typed_data';

import '../models/mail.dart';

/// 1対1のメール送受信を扱うリポジトリ。
abstract class MailRepository {
  /// 指定した友達とのメールのやり取りを、古い順に取得する（件数上限あり）。
  Future<List<Mail>> fetchConversation(String friendId);

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
