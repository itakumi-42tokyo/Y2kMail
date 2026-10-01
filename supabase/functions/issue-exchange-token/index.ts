// QR交換用のワンタイムトークンを発行するEdge Function。
// ログイン中の本人のためにトークンを1つ作り、その文字列を返す。
// 返ったトークンをQRコードにして画面に表示する。
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

// トークンの有効期限（分）。対面での交換を想定し、短くする。
const EXPIRES_MINUTES = 5;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 呼び出した本人を、渡されたJWTから特定する。
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "ログインが必要です" }, 401);
    }

    // 本人確認はユーザーのJWTで、DBへの書き込みはservice_roleで行う。
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return json({ error: "ログインが必要です" }, 401);
    }

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 推測されないよう、ランダムなトークンを生成する。
    const token = crypto.randomUUID() + crypto.randomUUID().replaceAll("-", "");
    const expiresAt = new Date(Date.now() + EXPIRES_MINUTES * 60 * 1000);

    const { error: insertError } = await adminClient
      .from("friend_exchange_tokens")
      .insert({
        owner_id: user.id,
        token,
        expires_at: expiresAt.toISOString(),
      });
    if (insertError) {
      return json({ error: insertError.message }, 400);
    }

    return json({ token, expires_at: expiresAt.toISOString() }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
