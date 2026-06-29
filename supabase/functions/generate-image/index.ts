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
// 개발/테스트용 기본 50회. 출시 전 5회로 낮추거나 RevenueCat 구독으로 게이트.
const FREE_LIMIT = parseInt(Deno.env.get('AI_FREE_LIMIT') ?? '50', 10);
// 2026-06: '-preview' 정식 출시되며 모델명 변경됨. 기본은 저렴한 flash(Nano Banana).
// 더 고품질 원하면 GEMINI_IMAGE_MODEL=gemini-3-pro-image (비쌈) 등으로 교체.
const GEMINI_MODEL =
  Deno.env.get('GEMINI_IMAGE_MODEL') ?? 'gemini-2.5-flash-image';

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

// 공통 규칙만 강제한다. 화풍(웹툰/실사/3D/시네마틱 등)은 사용자가 키워드로
// 지정하며, 여기서 특정 스타일을 박지 않는다 — 실사 인플루언서 등 모든 스타일 허용.
const BASE_RULES =
  'A single story-cut image. No text, no speech bubbles, no captions, no watermark. ' +
  // 키워드(화각/조명 등)만 와도 텍스트로 답하지 말고 반드시 이미지를 그리게 강제
  'ALWAYS output a single image, never text. ' +
  // 세로(9:16) 가득 + 주요 피사체가 프레임 안에 들어오게(가장자리 잘림 방지)
  'Vertical 9:16 portrait composition, full-bleed, keep the main subject centered and ' +
  'fully inside the frame so nothing important is cropped at the edges. ' +
  'If the subject is not specified, invent a fitting character and setting that matches the given keywords. ';

// 프롬프트 래퍼. 두 종류의 참조 이미지를 구분해 지시한다:
//  - charCount: 캐릭터 레퍼런스(앞쪽 N장) → 동일 인물·화풍 유지
//  - sceneCount: 장면 참고(뒤쪽 M장) → 배경/구도/사물/분위기만 참고(인물 복제 금지)
function buildPrompt(
  userPrompt: string,
  charCount: number,
  sceneCount: number,
): string {
  let rules = BASE_RULES;
  if (charCount > 0) {
    rules +=
      'IMPORTANT: the FIRST ' +
      charCount +
      ' reference image(s) are CHARACTER references — keep those character(s) ' +
      'identical (same face, hairstyle, outfit) and the same art style ' +
      '(if photorealistic real person, stay photorealistic; if illustrated, stay illustrated). ';
  }
  if (sceneCount > 0) {
    rules +=
      'The ' +
      (charCount > 0 ? 'NEXT ' : '') +
      sceneCount +
      ' reference image(s) are SCENE references — use them ONLY as guidance for ' +
      'background, composition, props, lighting and mood; do NOT copy any person from these scene images. ';
  }
  if (charCount > 0) {
    rules += 'Only change the scene/pose/expression of the character(s). ';
  }
  return rules + 'Scene: ' + userPrompt;
}

// Gemini 이미지 생성 → base64 PNG (data 부분만)
// refImages: 캐릭터 일관성용 참조 이미지(base64, data 부분만). 있으면 멀티 이미지 입력.
// 이미지가 나오면 base64 반환, Gemini가 텍스트만 반환(이미지 없음)하면 null.
async function generateWithGemini(
  prompt: string,
  refImages: string[],
  sceneRefs: string[],
): Promise<string | null> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;
  // 캐릭터 레퍼런스 먼저, 그다음 장면 참고, 마지막에 텍스트 지시(순서가 프롬프트와 일치)
  const parts: unknown[] = [
    ...refImages.map((b64) => ({
      inlineData: { mimeType: 'image/png', data: b64 },
    })),
    ...sceneRefs.map((b64) => ({
      inlineData: { mimeType: 'image/png', data: b64 },
    })),
  ];
  parts.push({ text: buildPrompt(prompt, refImages.length, sceneRefs.length) });
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts }],
      generationConfig: {
        responseModalities: ['IMAGE'],
        // 세로 9:16 — 더빙 화면(세로 전체)에 맞춰 컷을 세로로 생성
        imageConfig: { aspectRatio: '9:16' },
      },
    }),
  });
  if (!res.ok) {
    throw new Error(`gemini ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  const out = data?.candidates?.[0]?.content?.parts ?? [];
  for (const p of out) {
    if (p.inlineData?.data) return p.inlineData.data as string;
  }
  return null; // 텍스트만 반환됨(주제 부족/거부) → 호출부에서 친절 안내
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

    // 3) 프롬프트 + 참조 이미지(선택, 캐릭터 일관성용)
    const body = await req.json().catch(() => ({}));
    const prompt = body?.prompt;
    if (!prompt || `${prompt}`.trim().length < 2) {
      return json({ error: 'prompt_required' }, 400);
    }
    // 캐릭터 레퍼런스(최대 3장), data URL 접두사 제거
    const refImages: string[] = Array.isArray(body?.refImages)
      ? body.refImages
          .slice(0, 3)
          .map((s: string) => `${s}`.replace(/^data:image\/\w+;base64,/, ''))
          .filter((s: string) => s.length > 0)
      : [];
    // 장면 참고 이미지(최대 3장) — 배경/구도/사물 참고용(인물 복제 안 함)
    const sceneRefs: string[] = Array.isArray(body?.sceneRefs)
      ? body.sceneRefs
          .slice(0, 3)
          .map((s: string) => `${s}`.replace(/^data:image\/\w+;base64,/, ''))
          .filter((s: string) => s.length > 0)
      : [];

    // 4) 한도 체크(읽기, 미소비) — 생성 실패해도 쿼터 안 깎이게
    const { data: chk, error: chkErr } = await admin.rpc('check_ai_credit', {
      p_user: urow.id,
      p_limit: FREE_LIMIT,
    });
    if (chkErr) return json({ error: 'quota_error', detail: chkErr.message }, 500);
    const c = Array.isArray(chk) ? chk[0] : chk;
    if (!c?.allowed) {
      return json(
        { error: 'quota_exceeded', used: c?.used ?? FREE_LIMIT, limit: FREE_LIMIT },
        402,
      );
    }

    // 5) 생성 (키 없으면 stub)
    let b64: string | null;
    if (GEMINI_API_KEY) {
      b64 = await generateWithGemini(`${prompt}`.trim(), refImages, sceneRefs);
      // 이미지가 안 나오면(주제 부족 등) 쿼터 소비 없이 친절 안내
      if (b64 === null) {
        return json(
          {
            error: 'no_image',
            message: '무엇을 그릴지(인물·장면)도 한 줄 적어 주세요. 예: 카페에서 웃는 여성',
          },
          422,
        );
      }
    } else {
      b64 = STUB_PNG_BASE64; // 흐름 검증용
    }

    // 6) 성공 → 이제 월 한도 소비 (구독 한도는 추후 RevenueCat로 상향)
    const { data: credit, error: cErr } = await admin.rpc('consume_ai_credit', {
      p_user: urow.id,
      p_limit: FREE_LIMIT,
    });
    if (cErr) return json({ error: 'quota_error', detail: cErr.message }, 500);
    const row = Array.isArray(credit) ? credit[0] : credit;
    if (!row?.allowed) {
      // 경합으로 막 한도 도달 → 이미 생성된 이미지는 버리고 안내
      return json(
        { error: 'quota_exceeded', used: row?.used ?? FREE_LIMIT, limit: FREE_LIMIT },
        402,
      );
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
