// AI 스토리보드 — 전체 상황 → 컷별 [장면 프롬프트 + 화자 + 대사] 추천
//
// 흐름: 사용자 JWT 검증 → 상황 텍스트 → Gemini 텍스트 모델(JSON 스키마) →
//       { title, logline, cuts[] } 반환. 이미지 생성과 별개(텍스트라 매우 저렴).
//
// 배포: supabase functions deploy suggest-cuts
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
    title: { type: 'STRING' },
    logline: { type: 'STRING' },
    cuts: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          scenePrompt: { type: 'STRING' },
          speaker: { type: 'STRING' },
          dialogue: { type: 'STRING' },
          direction: { type: 'STRING' },
        },
        required: ['scenePrompt', 'speaker', 'dialogue'],
      },
    },
  },
  required: ['title', 'logline', 'cuts'],
};

function buildInstruction(situation: string, maxCuts: number): string {
  return (
    '너는 한국 웹툰/숏폼 콘티 작가다. 다음 상황을 ' +
    `${maxCuts}개 내외의 컷으로 나눠라. 각 컷은 다음을 포함한다:\n` +
    '- scenePrompt: 이미지 생성용 장면 묘사(영어, 간결, 인물의 표정/동작/배경/구도 포함, 말풍선·텍스트 없음)\n' +
    '- speaker: 화자 이름(한국어, 일관되게 유지)\n' +
    '- dialogue: 그 컷의 대사(한국어, 짧고 자연스럽게)\n' +
    '- direction: 연기 지시(한국어, 선택, 예: 화내며)\n' +
    'title(한국어 제목)과 logline(한 줄 소개)도 만들어라. ' +
    '같은 인물은 컷마다 같은 화자 이름으로 통일하라.\n상황: ' +
    situation
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
    const situation = `${body?.situation ?? ''}`.trim();
    if (situation.length < 4) return json({ error: 'situation_required' }, 400);
    // 무료 5컷 / Pro 최대 20컷 — 클라가 보낸 maxCuts를 2~20으로 clamp
    const maxCuts = Math.min(Math.max(parseInt(body?.maxCuts ?? 5, 10) || 5, 2), 20);

    if (!GEMINI_API_KEY) {
      // 키 없을 때 흐름 검증용 stub
      return json({
        title: '데모 스토리보드',
        logline: '키 설정 후 실제 추천이 나와요.',
        cuts: [
          { scenePrompt: 'a person standing', speaker: '주인공', dialogue: '안녕?', direction: '' },
        ],
        stub: true,
      });
    }

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${TEXT_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: buildInstruction(situation, maxCuts) }] }],
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
    let obj: Record<string, unknown>;
    try {
      obj = JSON.parse(txt);
    } catch (_) {
      return json({ error: 'parse_error', raw: txt.slice(0, 500) }, 502);
    }
    return json({ ...obj, stub: false });
  } catch (e) {
    return json({ error: 'server_error', detail: `${e}` }, 500);
  }
});
