// AI 키워드 추천 — 장면 설명 → 후보 키워드 중 어울리는 것 자동 선택
//
// 흐름: 사용자 JWT 검증 → { scene, candidates[] } → Gemini 텍스트 모델 →
//       후보 중 적합한 영문 키워드 배열 반환. 이미지 쿼터와 무관(텍스트라 저렴).
//
// 앱이 후보(우리 키워드 en 목록)를 보내고 모델은 그 안에서만 고른다 →
// 반환값이 앱의 _frags(영문 조각)와 정확히 일치해 바로 체크할 수 있다.
//
// 배포: supabase functions deploy suggest-keywords
// 시크릿: GEMINI_API_KEY 재사용. 모델은 GEMINI_TEXT_MODEL 로 교체 가능.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const TEXT_MODEL = Deno.env.get('GEMINI_TEXT_MODEL') ?? 'gemini-2.5-flash';

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

const SCHEMA = {
  type: 'OBJECT',
  properties: {
    keywords: {
      type: 'ARRAY',
      items: { type: 'STRING' },
    },
  },
  required: ['keywords'],
};

function buildInstruction(scene: string, candidates: string[]): string {
  return (
    '너는 한국 웹툰/숏폼 촬영·연출 디렉터다. 아래 "장면"에 가장 잘 어울리는 ' +
    '촬영/연출/분위기 키워드를 "후보 목록"에서만 골라라.\n' +
    '규칙:\n' +
    '- 반드시 후보 목록에 있는 문자열을 토씨 하나 안 틀리게 그대로 반환한다(새로 만들지 않는다).\n' +
    '- 5~12개 정도, 장면에 정말 어울리는 것만. 화각/조명/분위기/색감 등 서로 다른 범주를 고르게 섞어라.\n' +
    '- 화풍(실사/웹툰 등)은 장면에서 명시했을 때만 고른다.\n' +
    'keywords 배열로만 답하라.\n\n' +
    '장면: ' +
    scene +
    '\n\n후보 목록:\n' +
    candidates.map((c) => `- ${c}`).join('\n')
  );
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.replace('Bearer ', '');
    if (!jwt) return json({ error: 'unauthorized' }, 401);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: userData, error: uErr } = await admin.auth.getUser(jwt);
    if (uErr || !userData.user) return json({ error: 'unauthorized' }, 401);

    const body = await req.json().catch(() => ({}));
    const scene = `${body?.scene ?? ''}`.trim();
    if (scene.length < 2) return json({ error: 'scene_required' }, 400);
    const candidates: string[] = Array.isArray(body?.candidates)
      ? body.candidates
          .map((s: unknown) => `${s}`.trim())
          .filter((s: string) => s.length > 0)
          .slice(0, 400)
      : [];
    if (candidates.length === 0) return json({ error: 'candidates_required' }, 400);

    if (!GEMINI_API_KEY) {
      // 키 없을 때 흐름 검증용 stub — 앞 3개만 반환
      return json({ keywords: candidates.slice(0, 3), stub: true });
    }

    const allow = new Set(candidates);
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${TEXT_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: buildInstruction(scene, candidates) }] }],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: SCHEMA,
        },
      }),
    });
    if (!res.ok) {
      return json({ error: 'gemini_error', detail: await res.text() }, 502);
    }
    const data = await res.json();
    const txt = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    let obj: { keywords?: unknown };
    try {
      obj = JSON.parse(txt);
    } catch (_) {
      return json({ error: 'parse_error', raw: txt.slice(0, 500) }, 502);
    }
    // 후보에 실제로 있는 것만 통과(환각 방지)
    const picked = Array.isArray(obj.keywords)
      ? obj.keywords
          .map((s: unknown) => `${s}`.trim())
          .filter((s: string) => allow.has(s))
      : [];
    return json({ keywords: picked, stub: false });
  } catch (e) {
    return json({ error: 'server_error', detail: `${e}` }, 500);
  }
});
