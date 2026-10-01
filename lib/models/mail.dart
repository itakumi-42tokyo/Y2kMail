// メール1通を表すモデル。
class Mail {
  const Mail({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.isMine,
    this.subject,
    this.body,
    this.photoPath,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;

  /// 自分が送ったメールかどうか（表示の左右を分けるのに使う）。
  final bool isMine;

  final String? subject;
  final String? body;
  final String? photoPath;
  final DateTime createdAt;

  bool get hasPhoto => photoPath != null;
}
