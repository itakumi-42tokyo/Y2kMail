// 読み取ったQRトークンを使って友達関係を作るEdge Function。
// トークンの検証（存在・期限・未使用・自分以外）を行い、
// friendshipsに1行作る。150件上限はDBのトリガーが強制する。
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "ログインが必要です" }, 401);
    }

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return json({ error: "ログインが必要です" }, 401);
    }

    const { token } = await req.json().catch(() => ({ token: null }));
    if (!token || typeof token !== "string") {
      return json({ error: "トークンがありません" }, 400);
    }

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // トークンを引く。
    const { data: tokenRow, error: tokenError } = await adminClient
      .from("friend_exchange_tokens")
      .select("owner_id, expires_at, used_at")
      .eq("token", token)
      .maybeSingle();
    if (tokenError) {
      return json({ error: tokenError.message }, 400);
    }
    if (!tokenRow) {
      return json({ error: "無効なQRコードです" }, 400);
    }
    if (tokenRow.used_at) {
      return json({ error: "このQRコードは使用済みです" }, 400);
    }
    if (new Date(tokenRow.expires_at) < new Date()) {
      return json({ error: "QRコードの有効期限が切れています" }, 400);
    }
    if (tokenRow.owner_id === user.id) {
      return json({ error: "自分のQRコードは読み取れません" }, 400);
    }

    // 2人のIDを小さい順に並べる（friendshipsの制約に合わせる）。
    const [userA, userB] = [tokenRow.owner_id, user.id].sort();

    // 友達関係を作る。150件上限はDBのトリガーが弾く。
    const { error: friendshipError } = await adminClient
      .from("friendships")
      .insert({ user_a_id: userA, user_b_id: userB });
    if (friendshipError) {
      // 重複（すでに友達）の場合も、使い回し防止のためトークンは消費せずに返す。
      if (friendshipError.code === "23505") {
        return json({ error: "すでに友達です" }, 409);
      }
      return json({ error: friendshipError.message }, 400);
    }

    // 成功したらトークンを使用済みにする（ワンタイム化）。
    await adminClient
      .from("friend_exchange_tokens")
      .update({ used_at: new Date().toISOString() })
      .eq("token", token);

    // 1通目の自己紹介写メールを、両者へ自動で送る。
    // 事前に設定した自己紹介写真を使う。未設定の人の分は送らない。
    await sendIntroMails(adminClient, tokenRow.owner_id, user.id);

    // 交換成立の演出のため、相手（QRを出した側）の表示名を返す。
    const { data: friendProfile } = await adminClient
      .from("profiles")
      .select("display_name")
      .eq("id", tokenRow.owner_id)
      .maybeSingle();

    return json({
      ok: true,
      friend_id: tokenRow.owner_id,
      friend_name: friendProfile?.display_name ?? "",
    }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

// 2人それぞれの自己紹介写真を、相手あての1通目メールとして作る。
// deno-lint-ignore no-explicit-any
async function sendIntroMails(admin: any, userA: string, userB: string) {
  const { data: profiles } = await admin
    .from("profiles")
    .select("id, intro_photo_path")
    .in("id", [userA, userB]);
  if (!profiles) return;

  const introPhotoById: Record<string, string | null> = {};
  for (const p of profiles) {
    introPhotoById[p.id] = p.intro_photo_path ?? null;
  }

  const mails: Array<Record<string, unknown>> = [];
  for (const [sender, receiver] of [[userA, userB], [userB, userA]]) {
    const photoPath = introPhotoById[sender];
    if (!photoPath) continue; // 自己紹介写真が未設定なら送らない。
    mails.push({
      sender_id: sender,
      receiver_id: receiver,
      subject: "はじめまして",
      photo_path: photoPath,
    });
  }

  if (mails.length > 0) {
    await admin.from("mails").insert(mails);
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
