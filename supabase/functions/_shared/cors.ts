// アプリ（Flutter）からの呼び出しに必要なCORSヘッダ。
// モバイルアプリからの呼び出しが主だが、共通で付けておく。
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
