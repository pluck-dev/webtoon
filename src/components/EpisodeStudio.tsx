/* eslint-disable @next/next/no-img-element */
'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

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

type SessionState = {
  performanceId: string;
  userId: string;
};

export default function EpisodeStudio({ episode }: { episode: Episode }) {
  const [activeCut, setActiveCut] = useState(0);
  const [displayName, setDisplayName] = useState('My acting');
  const [handle, setHandle] = useState('actor-demo');
  const [session, setSession] = useState<SessionState | null>(null);
  const [recordingDialogue, setRecordingDialogue] = useState('');
  const [recordings, setRecordings] = useState<Record<string, RecordingState>>({});
  const [timeline, setTimeline] = useState('');
  const [status, setStatus] = useState('녹음 버튼을 누르면 세션을 만들고 마이크 권한을 요청합니다.');
  const [previewing, setPreviewing] = useState(false);

  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const startedAt = useRef(0);
  const activeStream = useRef<MediaStream | null>(null);
  const previewTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previewAudio = useRef<HTMLAudioElement | null>(null);
  const sessionRef = useRef<SessionState | null>(null);

  const activeDialogue = episode.cuts[activeCut]?.dialogues[0];
  const allDialogues = useMemo(() => episode.cuts.flatMap((cut) => cut.dialogues), [episode.cuts]);
  const recordedCount = allDialogues.filter((dialogue) => recordings[dialogue.id]?.saved).length;
  const progress = ((activeCut + 1) / episode.cuts.length) * 100;
  const sessionKey = `webtoon-voice-session:${episode.id}`;

  useEffect(() => {
    const stored = window.localStorage.getItem(sessionKey);
    if (!stored) return;

    let parsed: { performanceId?: string };
    try {
      parsed = JSON.parse(stored);
    } catch {
      window.localStorage.removeItem(sessionKey);
      return;
    }

    if (!parsed.performanceId) return;

    fetch(`/api/performances/${parsed.performanceId}`)
      .then((response) => {
        if (!response.ok) throw new Error('saved performance not found');
        return response.json();
      })
      .then((body) => {
        const restoredRecordings: Record<string, RecordingState> = {};
        for (const recording of body.recordings ?? []) {
          restoredRecordings[recording.dialogueId] = {
            url: recording.audioUrl,
            durationMs: recording.durationMs,
            saved: true
          };
        }

        const restoredSession = {
          performanceId: body.performance.id,
          userId: body.user.id
        };
        sessionRef.current = restoredSession;
        setSession(restoredSession);
        setDisplayName(body.user.displayName);
        setHandle(body.user.handle);
        setRecordings(restoredRecordings);
      setStatus(`${body.user.displayName}님의 저장된 녹음 세션을 불러왔습니다.`);
      })
      .catch(() => {
        window.localStorage.removeItem(sessionKey);
      });
  }, [sessionKey]);

  async function createPerformance() {
    let response: Response;
    try {
      response = await fetch('/api/performances', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ episodeId: episode.id, handle, displayName })
      });
    } catch {
      setStatus('세션 생성 요청이 실패했습니다. 개발 서버와 DB가 켜져 있는지 확인해주세요.');
      return null;
    }

    const body = await response.json().catch(() => null);
    if (!response.ok || !body?.performance || !body?.user) {
      setStatus('세션을 만들지 못했습니다. 핸들은 영문/숫자/_/- 만 사용할 수 있습니다.');
      return null;
    }

    const nextSession = {
      performanceId: body.performance.id,
      userId: body.user.id
    };
    sessionRef.current = nextSession;
    setSession(nextSession);
    window.localStorage.setItem(sessionKey, JSON.stringify({ performanceId: body.performance.id }));
    setStatus(`${body.user.displayName}님 녹음 세션이 준비됐습니다.`);
    return nextSession;
  }

  async function ensureSession() {
    if (sessionRef.current) return sessionRef.current;
    return createPerformance();
  }

  async function toggleRecording(dialogueId: string, cutIndex: number) {
    if (recordingDialogue === dialogueId) {
      mediaRecorder.current?.stop();
      return;
    }

    stopPreview();

    if (!navigator.mediaDevices?.getUserMedia) {
      setStatus('이 브라우저에서는 마이크 녹음을 지원하지 않습니다. Chrome 또는 Edge에서 localhost로 접속해주세요.');
      return;
    }

    const activeSession = await ensureSession();
    if (!activeSession) return;

    let stream: MediaStream;
    try {
      setStatus('마이크 권한을 요청하는 중입니다. 브라우저 권한 팝업에서 허용을 눌러주세요.');
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (error) {
      const message = error instanceof DOMException ? error.name : 'unknown';
      setStatus(`마이크 권한이 막혔습니다. 주소창 왼쪽 권한에서 마이크를 허용한 뒤 다시 눌러주세요. (${message})`);
      return;
    }

    chunks.current = [];
    activeStream.current = stream;
    // eslint-disable-next-line react-hooks/purity
    startedAt.current = performance.now();
    setActiveCut(cutIndex);
    setRecordingDialogue(dialogueId);
    setStatus(`CUT ${cutIndex + 1} 녹음 중입니다. 끝나면 정지를 누르세요.`);

    const mimeType = getSupportedMimeType();
    let recorder: MediaRecorder;
    try {
      recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
    } catch {
      cleanupRecording();
      setRecordingDialogue('');
      setStatus('녹음 장치를 시작하지 못했습니다. 다른 앱이 마이크를 사용 중인지 확인해주세요.');
      return;
    }
    mediaRecorder.current = recorder;
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.current.push(event.data);
    };
    recorder.onerror = () => {
      setStatus('녹음 중 오류가 났습니다. 다시 시도해주세요.');
      cleanupRecording();
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
      cleanupRecording();
      await uploadRecording(activeSession, dialogueId, blob, durationMs);
    };
    recorder.start();
  }

  function cleanupRecording() {
    activeStream.current?.getTracks().forEach((track) => track.stop());
    activeStream.current = null;
    mediaRecorder.current = null;
  }

  async function uploadRecording(activeSession: SessionState, dialogueId: string, blob: Blob, durationMs: number) {
    const formData = new FormData();
    formData.append('performanceId', activeSession.performanceId);
    formData.append('dialogueId', dialogueId);
    formData.append('userId', activeSession.userId);
    formData.append('durationMs', String(durationMs));
    formData.append('audio', blob, `${dialogueId}.webm`);

    const response = await fetch('/api/recordings', {
      method: 'POST',
      body: formData
    });
    if (!response.ok) {
      setStatus('브라우저에는 녹음됐지만 서버 저장에 실패했습니다. DB와 recordings 폴더 권한을 확인해주세요.');
      return;
    }

    setRecordings((current) => ({
      ...current,
      [dialogueId]: { ...current[dialogueId], saved: true }
    }));
    setStatus('녹음이 저장됐습니다. 새로고침해도 이 테이크를 다시 불러옵니다.');
  }

  async function buildRenderJob() {
    const activeSession = await ensureSession();
    if (!activeSession) return;

    const response = await fetch('/api/render-jobs', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ performanceId: activeSession.performanceId })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('렌더 타임라인을 만들지 못했습니다.');
      return;
    }

    setTimeline(JSON.stringify(body.timeline, null, 2));
    setStatus('하이퍼랩스 타임라인을 만들었습니다.');
  }

  function playSingle(dialogueId: string, cutIndex: number) {
    const recording = recordings[dialogueId];
    if (!recording) return;
    stopPreview();
    setActiveCut(cutIndex);
    new Audio(recording.url).play();
  }

  function playFullPreview() {
    if (recordedCount === 0) {
      setStatus('아직 녹음된 컷이 없습니다. 컷 하나 이상 먼저 녹음해주세요.');
      return;
    }

    stopPreview();
    setPreviewing(true);
    setStatus('전체 미리보기를 재생합니다.');

    let cutIndex = 0;
    const playNextCut = () => {
      if (cutIndex >= episode.cuts.length) {
        stopPreview('전체 미리보기가 끝났습니다.');
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

  function stopPreview(nextStatus = '미리보기를 정지했습니다.') {
    if (previewTimer.current) {
      clearTimeout(previewTimer.current);
      previewTimer.current = null;
    }
    if (previewAudio.current) {
      previewAudio.current.pause();
      previewAudio.current = null;
    }
    if (previewing) setStatus(nextStatus);
    setPreviewing(false);
  }

  return (
    <section className="workspace">
      <aside className="phone">
        <div className="phone-head">
          <span>{episode.title}</span>
          <button type="button" onClick={previewing ? () => stopPreview() : playFullPreview}>
            {previewing ? '정지' : '재생'}
          </button>
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
            <h1>계정</h1>
            <span>{session ? '세션 활성화' : '게스트 모드'}</span>
          </div>
          <div className="panel-content">
            <div className="join-form">
              <input value={displayName} onChange={(event) => setDisplayName(event.target.value)} placeholder="Display name" />
              <input value={handle} onChange={(event) => setHandle(event.target.value)} placeholder="handle" />
              <button className="primary" type="button" onClick={createPerformance}>
                {session ? '새 버전 만들기' : '녹음 시작'}
              </button>
            </div>
            <p className="account-note">
              지금은 MVP 계정 흐름입니다. 녹음 시작 시 세션이 자동 생성되고, 저장된 녹음은 새로고침 후 다시 불러옵니다.
            </p>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>전체 미리보기</h2>
            <span>{recordedCount}/{allDialogues.length} saved</span>
          </div>
          <div className="panel-content preview-console">
            <div>
              <strong>{status}</strong>
              <p>녹음 후 컷 전환과 대사 타이밍을 한 번에 확인합니다.</p>
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

        <section className="panel" id="cast">
          <div className="panel-head">
            <h2>연기 가이드</h2>
            <span>{episode.maxSeconds}s max</span>
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
                    <small>{recording ? `${(recording.durationMs / 1000).toFixed(1)}초 ${recording.saved ? '저장됨' : '저장 중'}` : '미녹음'}</small>
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
            <h2>렌더 작업</h2>
            <button className="primary" type="button" onClick={buildRenderJob}>타임라인 만들기</button>
          </div>
          <div className="panel-content render-box">
            <p className="muted">최종 MP4 렌더러는 컷 이미지와 녹음 파일이 담긴 이 타임라인 JSON을 사용합니다.</p>
            <pre className="timeline-json">{timeline || '아직 생성된 타임라인이 없습니다.'}</pre>
          </div>
        </section>
      </div>
    </section>
  );
}

function getSupportedMimeType() {
  const candidates = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4'];
  return candidates.find((candidate) => typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported(candidate));
}
