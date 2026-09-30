-- 圏外（Y2K Mail App）MVP 初期スキーマ
-- 段階1: users / friendships / mails の土台となるテーブルとRLS

-- =========================================
-- profiles（利用者）
-- 表示名のみを持つ。Googleの名前・アイコンは使わない
-- =========================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "自分のプロフィールは見える"
  on public.profiles for select
  using (auth.uid() = id);

create policy "自分のプロフィールは作成できる"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "自分のプロフィールは更新できる"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);


-- =========================================
-- friend_exchange_tokens（QR交換用の一時トークン）
-- クライアントからは直接読み書きしない。Edge Function（service_role）専用
-- =========================================
create table public.friend_exchange_tokens (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz
);

alter table public.friend_exchange_tokens enable row level security;
-- ポリシーを作らない → クライアントからのアクセスはすべて拒否される


-- =========================================
-- friendships（電話帳）
-- 作成はEdge Function経由のみ。150件の上限はトリガーでサーバー側が強制する
-- =========================================
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references public.profiles (id) on delete cascade,
  user_b_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint friendships_order check (user_a_id < user_b_id),
  constraint friendships_unique unique (user_a_id, user_b_id)
);

alter table public.friendships enable row level security;

create policy "自分が関係する友達関係だけ見える"
  on public.friendships for select
  using (auth.uid() = user_a_id or auth.uid() = user_b_id);
-- insert/update/delete のポリシーを作らない → Edge Function（service_role）専用

create or replace function public.check_friendship_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from public.friendships
    where user_a_id = new.user_a_id or user_b_id = new.user_a_id
  ) >= 150 then
    raise exception '電話帳の上限（150件）に達しています';
  end if;

  if (
    select count(*) from public.friendships
    where user_a_id = new.user_b_id or user_b_id = new.user_b_id
  ) >= 150 then
    raise exception '相手の電話帳が上限（150件）に達しています';
  end if;

  return new;
end;
$$;

create trigger friendships_limit_check
  before insert on public.friendships
  for each row execute function public.check_friendship_limit();

-- friendshipsができたあとに定義する（このポリシーがfriendshipsを参照するため）
create policy "友達のプロフィールは見える"
  on public.profiles for select
  using (
    exists (
      select 1 from public.friendships
      where (user_a_id = auth.uid() and user_b_id = profiles.id)
         or (user_b_id = auth.uid() and user_a_id = profiles.id)
    )
  );


-- =========================================
-- mails（メール）
-- 送信済みは編集不可: update/delete のポリシーを作らないことで実現する
-- =========================================
create table public.mails (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id) on delete cascade,
  receiver_id uuid not null references public.profiles (id) on delete cascade,
  subject text,
  body text,
  photo_path text,
  created_at timestamptz not null default now(),
  constraint mails_subject_length check (char_length(subject) <= 15),
  constraint mails_not_empty check (body is not null or photo_path is not null),
  constraint mails_not_self check (sender_id <> receiver_id)
);

alter table public.mails enable row level security;

create policy "送受信に関わるメールだけ見える"
  on public.mails for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "友達にだけ送信できる"
  on public.mails for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.friendships
      where (user_a_id = mails.sender_id and user_b_id = mails.receiver_id)
         or (user_b_id = mails.sender_id and user_a_id = mails.receiver_id)
    )
  );
-- update/delete のポリシーを作らない → 誰も変更・削除できない


-- =========================================
-- Storage: mail-photos（ガラケー画質化済みの写真のみを置く）
-- アップロード先は「送信者ID/ファイル名」。送信者本人のフォルダにのみアップロード可
-- ダウンロードは、そのメールの送信者・受信者本人のみ可
-- =========================================
insert into storage.buckets (id, name, public)
values ('mail-photos', 'mail-photos', false);

create policy "自分のフォルダにのみアップロードできる"
  on storage.objects for insert
  with check (
    bucket_id = 'mail-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "送受信に関わる写真だけダウンロードできる"
  on storage.objects for select
  using (
    bucket_id = 'mail-photos'
    and exists (
      select 1 from public.mails
      where photo_path = storage.objects.name
        and (sender_id = auth.uid() or receiver_id = auth.uid())
    )
  );
