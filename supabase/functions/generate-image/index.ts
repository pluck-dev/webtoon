// AI 컷 이미지 생성 (구독/무료 쿼터) — 서버에서만 이미지 API 키 사용
//
// 흐름: 사용자 JWT 검증 → User.id 해석 → consume_ai_credit(월 한도) →
//       Gemini 이미지 생성(키 없으면 stub 플레이스홀더) → base64 PNG 반환
//
// 배포: supabase functions deploy generate-image
// 시크릿: supabase secrets set GEMINI_API_KEY=... (없으면 stub 모드)
//        AI_FREE_LIMIT / AI_PRO_LIMIT 로 월 한도 조정(선택)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const FREE_LIMIT = parseInt(Deno.env.get('AI_FREE_LIMIT') ?? '5', 10);
const GEMINI_MODEL =
  Deno.env.get('GEMINI_IMAGE_MODEL') ?? 'gemini-2.5-flash-image-preview';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

// 웹툰 스타일을 일관되게 유지하는 프롬프트 래퍼
function buildPrompt(userPrompt: string): string {
  return (
    'Korean webtoon / manhwa style illustration, clean line art, vibrant flat colors, ' +
    'cinematic single panel, expressive characters, no text, no speech bubbles, no watermark. ' +
    'Scene: ' +
    userPrompt
  );
}

// Gemini 이미지 생성 → base64 PNG (data 부분만)
async function generateWithGemini(prompt: string): Promise<string> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: buildPrompt(prompt) }] }],
      generationConfig: { responseModalities: ['IMAGE'] },
    }),
  });
  if (!res.ok) {
    throw new Error(`gemini ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  for (const p of parts) {
    if (p.inlineData?.data) return p.inlineData.data as string;
  }
  throw new Error('gemini: no image in response');
}

// 키 없을 때 흐름 검증용 1x1 PNG (실서비스 전 stub)
const STUB_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.replace('Bearer ', '');
    if (!jwt) return json({ error: 'unauthorized' }, 401);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    // 1) JWT → auth user
    const { data: userData, error: uErr } = await admin.auth.getUser(jwt);
    if (uErr || !userData.user) return json({ error: 'unauthorized' }, 401);
    const authUid = userData.user.id;

    // 2) User.id 해석
    const { data: urow } = await admin
      .from('User')
      .select('id')
      .eq('supabaseUserId', authUid)
      .maybeSingle();
    if (!urow) return json({ error: 'no_user' }, 400);

    // 3) 프롬프트
    const { prompt } = await req.json().catch(() => ({ prompt: '' }));
    if (!prompt || `${prompt}`.trim().length < 2) {
      return json({ error: 'prompt_required' }, 400);
    }

    // 4) 월 한도 소비 (구독 한도는 추후 RevenueCat 검증으로 상향)
    const { data: credit, error: cErr } = await admin.rpc('consume_ai_credit', {
      p_user: urow.id,
      p_limit: FREE_LIMIT,
    });
    if (cErr) return json({ error: 'quota_error', detail: cErr.message }, 500);
    const row = Array.isArray(credit) ? credit[0] : credit;
    if (!row?.allowed) {
      return json(
        { error: 'quota_exceeded', used: row?.used ?? FREE_LIMIT, limit: FREE_LIMIT },
        402,
      );
    }

    // 5) 생성 (키 없으면 stub)
    let b64: string;
    if (GEMINI_API_KEY) {
      b64 = await generateWithGemini(`${prompt}`.trim());
    } else {
      b64 = STUB_PNG_BASE64; // 흐름 검증용
    }

    return json({
      image: b64, // base64 PNG
      remaining: row.remaining,
      stub: !GEMINI_API_KEY,
    });
  } catch (e) {
    return json({ error: 'server_error', detail: `${e}` }, 500);
  }
});
