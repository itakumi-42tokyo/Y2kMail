// 一覧・詳細で使うメール1通。
// partner は相手（受信BOXなら送信者、送信BOXなら宛先）。
class Mail {
  const Mail({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    this.subject,
    this.body,
    this.photoPath,
    required this.createdAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String? subject;
  final String? body;
  final String? photoPath;
  final DateTime createdAt;

  bool get hasPhoto => photoPath != null;

  /// 一覧2行目に出す見出し（件名が空なら本文の冒頭）。
  String get listTitle {
    final s = subject?.trim();
    if (s != null && s.isNotEmpty) return s;
    final b = body?.trim() ?? '';
    return b.isEmpty ? '(本文なし)' : b;
  }
}
