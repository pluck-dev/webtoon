import { createClient } from '@supabase/supabase-js';

// Storage 버킷 이름 상수 — 스크립트/라우트에서 공통 사용한다
export const BUCKET_IMAGES = 'webtoon-images';
export const BUCKET_RECORDINGS = 'recordings';
export const BUCKET_VIDEOS = 'rendered-videos';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`환경변수 ${name} 가 설정되지 않았습니다`);
  }
  return value;
}

// 서버 전용 Supabase 클라이언트.
// secret key(service role)를 사용하므로 절대 클라이언트 번들에 노출되면 안 된다.
let cached: ReturnType<typeof createClient> | undefined;

export function getSupabaseAdmin() {
  if (!cached) {
    cached = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SECRET_KEY'), {
      auth: { persistSession: false, autoRefreshToken: false }
    });
  }
  return cached;
}

type UploadInput = {
  bucket: string;
  /** 버킷 내부 경로(키). 예: "borrowed-tomorrow/cut-01.png" */
  key: string;
  body: Buffer | ArrayBuffer | Uint8Array;
  contentType: string;
};

/**
 * Storage 버킷에 파일을 업로드하고 공개 URL을 반환한다.
 * 버킷은 public 읽기로 생성되어 있어 반환 URL을 그대로 <img>/audio src에 쓸 수 있다.
 */
export async function uploadToBucket({ bucket, key, body, contentType }: UploadInput) {
  const supabase = getSupabaseAdmin();
  const bytes = body instanceof Buffer ? body : Buffer.from(body as ArrayBuffer);

  const { error } = await supabase.storage.from(bucket).upload(key, bytes, {
    contentType,
    upsert: true
  });

  if (error) {
    throw new Error(`Storage 업로드 실패 (${bucket}/${key}): ${error.message}`);
  }

  const { data } = supabase.storage.from(bucket).getPublicUrl(key);
  return { publicUrl: data.publicUrl, storageKey: key };
}

/**
 * private 버킷용 임시 서명 URL을 발급한다.
 * 녹음 음성처럼 "본인만 듣기"가 필요한 파일은 public URL 대신 이걸 쓴다.
 */
export async function createSignedUrl(bucket: string, key: string, expiresInSeconds = 3600) {
  const supabase = getSupabaseAdmin();
  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(key, expiresInSeconds);
  if (error || !data) {
    throw new Error(`서명 URL 생성 실패 (${bucket}/${key}): ${error?.message ?? 'unknown'}`);
  }
  return data.signedUrl;
}
