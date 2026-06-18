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
  const [status, setStatus] = useState('로그인 후 컷별 대사를 녹음하세요.');
  const [previewing, setPreviewing] = useState(false);

  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const startedAt = useRef(0);
  const previewTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previewAudio = useRef<HTMLAudioElement | null>(null);

  const activeDialogue = episode.cuts[activeCut]?.dialogues[0];
  const allDialogues = useMemo(() => episode.cuts.flatMap((cut) => cut.dialogues), [episode.cuts]);
  const recordedCount = allDialogues.filter((dialogue) => recordings[dialogue.id]?.saved).length;
  const progress = ((activeCut + 1) / episode.cuts.length) * 100;
  const isLoggedIn = Boolean(performanceId && userId);

  async function createPerformance() {
    const response = await fetch('/api/performances', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ episodeId: episode.id, handle, displayName })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('로그인/참여 버전 생성에 실패했습니다.');
      return;
    }

    setPerformanceId(body.performance.id);
    setUserId(body.user.id);
    setStatus(`${body.user.displayName} 계정으로 참여 중입니다.`);
  }

  async function toggleRecording(dialogueId: string, cutIndex: number) {
    if (!isLoggedIn) {
      setStatus('먼저 로그인하고 내 참여 버전을 만들어야 합니다.');
      return;
    }

    if (recordingDialogue === dialogueId) {
      mediaRecorder.current?.stop();
      return;
    }

    stopPreview();

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    chunks.current = [];
    // eslint-disable-next-line react-hooks/purity
    startedAt.current = performance.now();
    setActiveCut(cutIndex);
    setRecordingDialogue(dialogueId);
    setStatus(`CUT ${cutIndex + 1} 녹음 중입니다.`);

    const recorder = new MediaRecorder(stream);
    mediaRecorder.current = recorder;
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.current.push(event.data);
    };
    recorder.onstop = async () => {
      const durationMs = Math.max(Math.round(performance.now() - startedAt.current), 1000);
      const blob = new Blob(chunks.current, { type: recorder.mimeType || 'audio/webm' });
      const url = URL.createObjectURL(blob);

      setRecordings((current) => ({
        ...current,
        [dialogueId]: { url, durationMs, saved: false }
      }));
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
      setStatus('녹음 저장에 실패했습니다.');
      return;
    }

    setRecordings((current) => ({
      ...current,
      [dialogueId]: { ...current[dialogueId], saved: true }
    }));
    setStatus('녹음이 저장되었습니다.');
  }

  async function buildRenderJob() {
    if (!isLoggedIn) {
      setStatus('먼저 로그인하고 내 참여 버전을 만들어야 합니다.');
      return;
    }

    const response = await fetch('/api/render-jobs', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ performanceId })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('타임라인 생성에 실패했습니다.');
      return;
    }

    setTimeline(JSON.stringify(body.timeline, null, 2));
    setStatus('하이퍼랩스 타임라인이 생성되었습니다.');
  }

  function playSingle(dialogueId: string, cutIndex: number) {
    const recording = recordings[dialogueId];
    if (!recording) return;
    stopPreview();
    setActiveCut(cutIndex);
    const audio = new Audio(recording.url);
    audio.play();
  }

  function playFullPreview() {
    if (recordedCount === 0) {
      setStatus('재생할 녹음이 없습니다. 먼저 컷별 대사를 녹음하세요.');
      return;
    }

    stopPreview();
    setPreviewing(true);
    setStatus('전체 재생으로 컷별 녹음을 확인 중입니다.');

    let cutIndex = 0;
    const playNextCut = () => {
      if (cutIndex >= episode.cuts.length) {
        stopPreview('전체 재생이 끝났습니다.');
        return;
      }

      const cut = episode.cuts[cutIndex];
      const dialogue = cut.dialogues[0];
      const recording = dialogue ? recordings[dialogue.id] : null;
      setActiveCut(cutIndex);

      if (recording) {
        const audio = new Audio(recording.url);
        previewAudio.current = audio;
        audio.onended = () => {
          cutIndex += 1;
          previewTimer.current = setTimeout(playNextCut, 350);
        };
        audio.play();
        return;
      }

      cutIndex += 1;
      previewTimer.current = setTimeout(playNextCut, 1400);
    };

    playNextCut();
  }

  function stopPreview(nextStatus = '전체 재생이 정지되었습니다.') {
    if (previewTimer.current) {
      clearTimeout(previewTimer.current);
      previewTimer.current = null;
    }
    if (previewAudio.current) {
      previewAudio.current.pause();
      previewAudio.current = null;
    }
    if (previewing) {
      setStatus(nextStatus);
    }
    setPreviewing(false);
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
        <section className="panel account-panel">
          <div className="panel-head">
            <h1>계정 로그인</h1>
            <span>{isLoggedIn ? '로그인됨' : '게스트 시작'}</span>
          </div>
          <div className="panel-content">
            <div className="join-form">
              <input value={displayName} onChange={(event) => setDisplayName(event.target.value)} placeholder="표시 이름" />
              <input value={handle} onChange={(event) => setHandle(event.target.value)} placeholder="handle" />
              <button className="primary" type="button" onClick={createPerformance}>
                {isLoggedIn ? '버전 새로 만들기' : '로그인하고 시작'}
              </button>
            </div>
            <p className="account-note">
              지금은 MVP용 간단 로그인입니다. 나중에 OAuth/이메일 로그인을 붙이면 이 참여 버전이 실제 계정에 연결됩니다.
            </p>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>전체 재생 검수</h2>
            <span>{recordedCount}/{allDialogues.length} 녹음 완료</span>
          </div>
          <div className="panel-content preview-console">
            <div>
              <strong>{status}</strong>
              <p>녹음이 끝나면 전체 재생으로 컷 전환과 대사 타이밍을 확인하세요.</p>
            </div>
            <div className="preview-actions">
              <button className="primary" type="button" onClick={playFullPreview} disabled={previewing}>
                전체 재생
              </button>
              <button type="button" onClick={() => stopPreview()} disabled={!previewing}>
                정지
              </button>
            </div>
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
            <span>{recordedCount}/{allDialogues.length}</span>
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
                    <button type="button" disabled={!recording} onClick={() => playSingle(dialogue.id, cutIndex)}>듣기</button>
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
