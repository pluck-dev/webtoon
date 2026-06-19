import { loadFont } from '@remotion/google-fonts/NotoSansKR';
import { AbsoluteFill, Audio, Img, Sequence, interpolate, useCurrentFrame } from 'remotion';

import type { RenderBubble, RenderCut, RenderInput } from './types';

// 한글 자막용 폰트 (렌더 시 자동으로 로드 완료를 기다린다)
const { fontFamily } = loadFont('normal', {
  weights: ['700', '900'],
  subsets: ['korean', 'latin'],
  ignoreTooManyRequestsWarning: true
});

// 한 컷: 이미지 + 줌/페이드 + 말풍선 + 음성
function Cut({ cut }: { cut: RenderCut }) {
  const frame = useCurrentFrame();
  const { durationInFrames, transition } = cut;

  // hyper-zoom-fade: 천천히 줌인 + 시작/끝 페이드. hold: 정적.
  const zoom = transition === 'hold'
    ? 1
    : interpolate(frame, [0, durationInFrames], [1.05, 1.16], { extrapolateRight: 'clamp' });

  const fadeIn = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: 'clamp' });
  const fadeOut = interpolate(frame, [durationInFrames - 8, durationInFrames], [1, 0], {
    extrapolateLeft: 'clamp'
  });
  const opacity = Math.min(fadeIn, fadeOut);

  return (
    <AbsoluteFill style={{ backgroundColor: '#000', opacity }}>
      <AbsoluteFill style={{ transform: `scale(${zoom})` }}>
        <Img src={cut.imageUrl} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
      </AbsoluteFill>

      <Bubbles bubbles={cut.bubbles} frame={frame} />

      {cut.audios.map((audio, i) => (
        <Sequence key={i} from={audio.startInFrames} durationInFrames={audio.durationInFrames}>
          <Audio src={audio.src} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
}

// 하단 자막 오버레이 (모던 쇼츠 스타일) — 현재 말하는 대사 하나만 순차 표시
function Bubbles({ bubbles, frame }: { bubbles: RenderBubble[]; frame: number }) {
  if (bubbles.length === 0) return null;
  // 지금 프레임 기준, 이미 시작된 대사 중 가장 최근 것을 보여준다(끝나도 다음 대사 전까진 유지)
  const bubble = [...bubbles].reverse().find((item) => frame >= item.startInFrames) ?? bubbles[0];
  return (
    <AbsoluteFill
      style={{
        justifyContent: 'flex-end',
        alignItems: 'center',
        padding: 72,
        paddingBottom: 140,
        gap: 16
      }}
    >
        <div
          style={{
            maxWidth: '90%',
            background: 'rgba(8,8,11,0.64)',
            borderRadius: 30,
            padding: '26px 38px',
            textAlign: 'center',
            boxShadow: '0 12px 60px rgba(0,0,0,0.45)'
          }}
        >
          {bubble.speaker ? (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 11,
                marginBottom: 14
              }}
            >
              <span
                style={{
                  width: 18,
                  height: 18,
                  borderRadius: 999,
                  background: bubble.color,
                  boxShadow: '0 0 0 4px rgba(255,255,255,0.16)'
                }}
              />
              <span
                style={{
                  fontFamily,
                  color: '#ffe7a3',
                  fontSize: 32,
                  fontWeight: 700,
                  letterSpacing: '0.01em'
                }}
              >
                {bubble.speaker}
              </span>
            </div>
          ) : null}
          <div
            style={{
              fontFamily,
              color: '#ffffff',
              fontSize: 56,
              fontWeight: 900,
              lineHeight: 1.28,
              letterSpacing: '-0.01em',
              wordBreak: 'keep-all',
              textShadow: '0 2px 16px rgba(0,0,0,0.5)'
            }}
          >
            {bubble.text}
          </div>
        </div>
    </AbsoluteFill>
  );
}

export function WebtoonShort({ cuts }: RenderInput) {
  let from = 0;
  return (
    <AbsoluteFill style={{ backgroundColor: '#000' }}>
      {cuts.map((cut, i) => {
        const start = from;
        from += cut.durationInFrames;
        return (
          <Sequence key={i} from={start} durationInFrames={cut.durationInFrames}>
            <Cut cut={cut} />
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
}
