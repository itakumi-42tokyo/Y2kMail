-- 段階4: 自己紹介写真（1通目の写メール）用の追加。

-- プロフィールに、自己紹介写真のStorage上のパスを持たせる（未設定ならnull）。
alter table public.profiles
  add column intro_photo_path text;

-- 自己紹介写真の設定画面で、自分がアップした写真を自分で確認できるように、
-- 「自分のフォルダの写真は自分で見える」ポリシーを追加する。
-- （これまでは、メールに紐づく写真しかダウンロードできなかった）
create policy "自分のフォルダの写真は見える"
  on storage.objects for select
  using (
    bucket_id = 'mail-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
