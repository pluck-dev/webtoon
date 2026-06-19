// Remotion 렌더 입력 타입 — 워커가 DB에서 만들어 컴포지션에 props로 넘긴다

export const RENDER_FPS = 30;
export const RENDER_WIDTH = 1080;
export const RENDER_HEIGHT = 1920;

export type RenderBubble = {
  speaker: string;
  text: string;
  color: string;
  // 이 대사가 화면에 보일 구간(컷 내부 프레임 기준) — 음성과 동기
  startInFrames: number;
  durationInFrames: number;
};

export type RenderAudio = {
  /** 재생 가능한 URL (녹음은 private 버킷의 서명 URL) */
  src: string;
  startInFrames: number;
  durationInFrames: number;
};

export type RenderCut = {
  /** 절대 URL (컷 이미지) */
  imageUrl: string;
  durationInFrames: number;
  transition: 'hold' | 'hyper-zoom-fade' | string;
  bubbles: RenderBubble[];
  audios: RenderAudio[];
};

export type RenderInput = {
  fps: number;
  width: number;
  height: number;
  cuts: RenderCut[];
};
