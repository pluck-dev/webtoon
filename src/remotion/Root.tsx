import { Composition } from 'remotion';

import { WebtoonShort } from './WebtoonShort';
import { RENDER_FPS, RENDER_HEIGHT, RENDER_WIDTH, type RenderInput } from './types';

const defaultProps: RenderInput = {
  fps: RENDER_FPS,
  width: RENDER_WIDTH,
  height: RENDER_HEIGHT,
  cuts: []
};

export function RemotionRoot() {
  return (
    <Composition
      id="WebtoonShort"
      component={WebtoonShort}
      durationInFrames={300}
      fps={RENDER_FPS}
      width={RENDER_WIDTH}
      height={RENDER_HEIGHT}
      defaultProps={defaultProps}
      // 컷 길이 합으로 전체 길이를 동적으로 계산한다
      calculateMetadata={({ props }) => {
        const total = props.cuts.reduce((sum, cut) => sum + cut.durationInFrames, 0);
        return {
          durationInFrames: Math.max(total, 1),
          fps: props.fps,
          width: props.width,
          height: props.height
        };
      }}
    />
  );
}
