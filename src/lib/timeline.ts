type TimelineCut = {
  id: string;
  order: number;
  imageUrl: string;
  dialogues: {
    id: string;
    text: string;
    recordings?: {
      durationMs: number;
      audioUrl: string;
    }[];
  }[];
};

export function buildHyperlapseTimeline(cuts: TimelineCut[], maxSeconds: number) {
  const items = cuts
    .slice()
    .sort((a, b) => a.order - b.order)
    .map((cut, index) => {
      const audioMs = cut.dialogues.reduce((sum, dialogue) => {
        const recording = dialogue.recordings?.[0];
        return sum + (recording?.durationMs ?? estimateMs(dialogue.text));
      }, 0);

      return {
        cutId: cut.id,
        order: cut.order,
        imageUrl: cut.imageUrl,
        startMs: 0,
        durationMs: Math.max(audioMs + 450, 1800),
        transition: index === 0 ? 'hold' : 'hyper-zoom-fade'
      };
    });

  const total = items.reduce((sum, item) => sum + item.durationMs, 0);
  const maxMs = maxSeconds * 1000;
  const scale = total > maxMs ? maxMs / total : 1;
  let cursor = 0;

  return items.map((item) => {
    const durationMs = Math.round(item.durationMs * scale);
    const timed = { ...item, startMs: cursor, durationMs };
    cursor += durationMs;
    return timed;
  });
}

function estimateMs(text: string) {
  return Math.min(Math.max(text.replace(/\s/g, '').length * 175, 1700), 6500);
}
