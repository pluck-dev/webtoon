/* eslint-disable @next/next/no-img-element */
'use client';

import { useMemo, useRef, useState } from 'react';

type Episode = {
  id: string;
  title: string;
  maxSeconds: number;
  characters: {
    id: string;
    name: string;
    description: string;
    voiceGuide: string;
    color: string;
  }[];
  cuts: {
    id: string;
    order: number;
    imageUrl: string;
    caption: string;
    dialogues: {
      id: string;
      text: string;
      direction: string;
      characterName: string;
    }[];
  }[];
};

type RecordingState = {
  url: string;
  durationMs: number;
  saved: boolean;
};

export default function EpisodeStudio({ episode }: { episode: Episode }) {
  const [activeCut, setActiveCut] = useState(0);
  const [displayName, setDisplayName] = useState('내 연기');
  const [handle, setHandle] = useState('actor-demo');
  const [performanceId, setPerformanceId] = useState('');
  const [userId, setUserId] = useState('');
  const [recordingDialogue, setRecordingDialogue] = useState('');
  const [recordings, setRecordings] = useState<Record<string, RecordingState>>({});
  const [timeline, setTimeline] = useState('');
  const [status, setStatus] = useState('참여 버전을 만들고 컷별로 녹음하세요.');
  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const startedAt = useRef(0);

  const activeDialogue = episode.cuts[activeCut]?.dialogues[0];
  const progress = ((activeCut + 1) / episode.cuts.length) * 100;
  const allDialogues = useMemo(() => episode.cuts.flatMap((cut) => cut.dialogues), [episode.cuts]);

  async function createPerformance() {
    const response = await fetch('/api/performances', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ episodeId: episode.id, handle, displayName })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('참여 버전 생성 실패');
      return;
    }
    setPerformanceId(body.performance.id);
    setUserId(body.user.id);
    setStatus(`${body.performance.title} 생성 완료`);
  }

  async function toggleRecording(dialogueId: string, cutIndex: number) {
    if (!performanceId || !userId) {
      setStatus('먼저 참여 버전을 만들어야 합니다.');
      return;
    }

    if (recordingDialogue === dialogueId) {
      mediaRecorder.current?.stop();
      return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    chunks.current = [];
    // eslint-disable-next-line react-hooks/purity
    startedAt.current = performance.now();
    setActiveCut(cutIndex);
    setRecordingDialogue(dialogueId);
    setStatus(`CUT ${cutIndex + 1} 녹음 중`);

    const recorder = new MediaRecorder(stream);
    mediaRecorder.current = recorder;
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.current.push(event.data);
    };
    recorder.onstop = async () => {
      const durationMs = Math.max(Math.round(performance.now() - startedAt.current), 1000);
      const blob = new Blob(chunks.current, { type: recorder.mimeType || 'audio/webm' });
      const url = URL.createObjectURL(blob);
      setRecordings((current) => ({ ...current, [dialogueId]: { url, durationMs, saved: false } }));
      setRecordingDialogue('');
      stream.getTracks().forEach((track) => track.stop());
      await uploadRecording(dialogueId, blob, durationMs);
    };
    recorder.start();
  }

  async function uploadRecording(dialogueId: string, blob: Blob, durationMs: number) {
    const formData = new FormData();
    formData.append('performanceId', performanceId);
    formData.append('dialogueId', dialogueId);
    formData.append('userId', userId);
    formData.append('durationMs', String(durationMs));
    formData.append('audio', blob, `${dialogueId}.webm`);

    const response = await fetch('/api/recordings', {
      method: 'POST',
      body: formData
    });
    if (!response.ok) {
      setStatus('녹음 저장 실패');
      return;
    }
    setRecordings((current) => ({
      ...current,
      [dialogueId]: { ...current[dialogueId], saved: true }
    }));
    setStatus('녹음 저장 완료');
  }

  async function buildRenderJob() {
    if (!performanceId) {
      setStatus('먼저 참여 버전을 만들어야 합니다.');
      return;
    }
    const response = await fetch('/api/render-jobs', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ performanceId })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('렌더잡 생성 실패');
      return;
    }
    setTimeline(JSON.stringify(body.timeline, null, 2));
    setStatus('하이퍼랩스 타임라인 생성 완료');
  }

  return (
    <section className="workspace">
      <aside className="phone">
        <div className="phone-head">
          <span>{episode.title}</span>
          <button type="button" onClick={() => setActiveCut((activeCut + 1) % episode.cuts.length)}>다음 컷</button>
        </div>
        <div className="phone-scroll">
          {episode.cuts.map((cut, index) => (
            <article className={`cut-panel ${index === activeCut ? 'active' : ''}`} key={cut.id} onClick={() => setActiveCut(index)}>
              <img src={cut.imageUrl} alt="" />
              {cut.dialogues.map((dialogue, dialogueIndex) => (
                <div className={`bubble ${dialogueIndex % 2 === 0 ? 'left' : 'right'}`} key={dialogue.id}>
                  {dialogue.text}
                </div>
              ))}
              <div className="caption">CUT {cut.order}. {cut.caption}</div>
            </article>
          ))}
        </div>
        <div className="phone-foot">
          <strong>{activeDialogue ? `${activeDialogue.characterName}: ${activeDialogue.text}` : '대사 없음'}</strong>
          <span>{activeDialogue?.direction}</span>
          <div className="progress"><i style={{ width: `${progress}%` }} /></div>
        </div>
      </aside>

      <div className="stack">
        <section className="panel">
          <div className="panel-head">
            <h1>참여 버전 만들기</h1>
            <span>{status}</span>
          </div>
          <div className="panel-content join-form">
            <input value={displayName} onChange={(event) => setDisplayName(event.target.value)} placeholder="표시 이름" />
            <input value={handle} onChange={(event) => setHandle(event.target.value)} placeholder="handle" />
            <button className="primary" type="button" onClick={createPerformance}>내 버전 생성</button>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>캐릭터 보이스 가이드</h2>
            <span>{episode.maxSeconds}초 이하</span>
          </div>
          <div className="panel-content character-grid">
            {episode.characters.map((character) => (
              <div className="character" key={character.id} style={{ borderColor: character.color }}>
                <strong>{character.name}</strong>
                <p>{character.description}</p>
                <small>{character.voiceGuide}</small>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>컷별 녹음</h2>
            <span>{Object.keys(recordings).length}/{allDialogues.length}</span>
          </div>
          <div className="panel-content record-list">
            {episode.cuts.map((cut, cutIndex) => cut.dialogues.map((dialogue) => {
              const recording = recordings[dialogue.id];
              return (
                <div className={`record-card ${cutIndex === activeCut ? 'active' : ''}`} key={dialogue.id}>
                  <button className="cut-button" type="button" onClick={() => setActiveCut(cutIndex)}>CUT {cut.order}</button>
                  <div className="record-copy">
                    <strong>{dialogue.characterName}: {dialogue.text}</strong>
                    <p>{dialogue.direction}</p>
                    <small>{recording ? `${(recording.durationMs / 1000).toFixed(1)}초 ${recording.saved ? '저장됨' : '저장 중'}` : '녹음 전'}</small>
                  </div>
                  <div className="record-actions">
                    <button className="primary" type="button" onClick={() => toggleRecording(dialogue.id, cutIndex)}>
                      {recordingDialogue === dialogue.id ? '정지' : '녹음'}
                    </button>
                    <button type="button" disabled={!recording} onClick={() => recording && new Audio(recording.url).play()}>듣기</button>
                  </div>
                </div>
              );
            }))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>하이퍼랩스 렌더잡</h2>
            <button className="primary" type="button" onClick={buildRenderJob}>타임라인 생성</button>
          </div>
          <div className="panel-content render-box">
            <p className="muted">실제 MP4 렌더러는 이 타임라인 JSON을 ffmpeg 워커에 넘기면 됩니다.</p>
            <pre className="timeline-json">{timeline || '아직 생성된 타임라인이 없습니다.'}</pre>
          </div>
        </section>
      </div>
    </section>
  );
}
