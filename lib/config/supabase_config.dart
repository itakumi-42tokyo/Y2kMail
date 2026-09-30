// SupabaseのプロジェクトURLとpublishable（旧anon）キー。
// この鍵はクライアントアプリに埋め込まれる前提で作られた鍵で、
// 実際のデータはSupabase側のRLS（行単位のアクセス制御）で守られている。
// そのため、このファイルをリポジトリにコミットしても問題ない。
// 反対に、強い権限を持つ secret / service_role キーは絶対にここへ書かない。
class SupabaseConfig {
  static const String url = 'https://pjjtnfdgptpemujtjptp.supabase.co';
  static const String publishableKey =
      'sb_publishable_oazK-Tf160B7P9xbg4ru-A_FhtZNyej';
}
