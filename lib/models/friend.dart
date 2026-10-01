// 友達1人を表すモデル。表示名だけを持つ（原則どおり、余計な情報は持たない）。
class Friend {
  const Friend({required this.id, required this.displayName});

  final String id;
  final String displayName;
}
