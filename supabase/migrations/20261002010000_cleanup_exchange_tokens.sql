-- QR交換用トークンの自動削除。
-- 使用済み・期限切れのトークンは不要なので、1時間おきに消す。
-- （CLAUDE.md「定期処理はPostgresの関数とスケジュール実行で行う」に沿う）

-- 定期実行のための拡張（Supabaseでは利用可能）。
create extension if not exists pg_cron;

-- 1時間おきに、使用済み または 期限切れのトークンを削除する。
select cron.schedule(
  'cleanup-exchange-tokens',
  '0 * * * *',
  $$
    delete from public.friend_exchange_tokens
    where used_at is not null
       or expires_at < now()
  $$
);
