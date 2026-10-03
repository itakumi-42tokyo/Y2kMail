String _pad2(int n) => n.toString().padLeft(2, '0');

// 一覧の日時: 今日なら HH:MM、それ以前なら MM/DD。
String listDate(DateTime dtUtc, {DateTime? now}) {
  final dt = dtUtc.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  if (dt.year == n.year && dt.month == n.month && dt.day == n.day) {
    return '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
  }
  return '${_pad2(dt.month)}/${_pad2(dt.day)}';
}

// 詳細の日時: YYYY/MM/DD HH:MM。
String detailDate(DateTime dtUtc) {
  final dt = dtUtc.toLocal();
  return '${dt.year}/${_pad2(dt.month)}/${_pad2(dt.day)} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';
}
