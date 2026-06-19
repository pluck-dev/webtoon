import { AbsoluteFill, Audio, Img, Sequence, interpolate, useCurrentFrame } from 'remotion';

import type { RenderBubble, RenderCut, RenderInput } from './types';

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

      <Bubbles bubbles={cut.bubbles} />

      {cut.audios.map((audio, i) => (
        <Sequence key={i} from={audio.startInFrames} durationInFrames={audio.durationInFrames}>
          <Audio src={audio.src} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
}

// 하단 말풍선/자막 오버레이
function Bubbles({ bubbles }: { bubbles: RenderBubble[] }) {
  if (bubbles.length === 0) return null;
  return (
    <AbsoluteFill
      style={{
        justifyContent: 'flex-end',
        alignItems: 'center',
        padding: 64,
        gap: 16
      }}
    >
      {bubbles.map((bubble, i) => (
        <div
          key={i}
          style={{
            maxWidth: '88%',
            background: 'rgba(0,0,0,0.72)',
            borderRadius: 28,
            padding: '24px 32px',
            borderLeft: `8px solid ${bubble.color}`
          }}
        >
          {bubble.speaker ? (
            <div style={{ color: bubble.color, fontSize: 30, fontWeight: 800, marginBottom: 8 }}>
              {bubble.speaker}
            </div>
          ) : null}
          <div style={{ color: '#fff', fontSize: 44, fontWeight: 600, lineHeight: 1.3 }}>
            {bubble.text}
          </div>
        </div>
      ))}
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
