/* eslint-disable @next/next/no-img-element */
'use client';

import { useUser } from '@clerk/nextjs';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

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
  const { isSignedIn, user } = useUser();
  const [activeCut, setActiveCut] = useState(0);
  const [recordingDialogue, setRecordingDialogue] = useState('');
  const [recordings, setRecordings] = useState<Record<string, RecordingState>>({});
  const [timeline, setTimeline] = useState<unknown>(null);
  const [status, setStatus] = useState('헤더에서 로그인하면 녹음이 계정에 저장됩니다.');
  const [previewing, setPreviewing] = useState(false);
  const [videoReady, setVideoReady] = useState(false);

  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const startedAt = useRef(0);
  const activeStream = useRef<MediaStream | null>(null);
  const previewTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previewAudio = useRef<HTMLAudioElement | null>(null);
  const sessionRef = useRef<SessionState | null>(null);
  const cutRefs = useRef<(HTMLElement | null)[]>([]);

  const activeCutData = episode.cuts[activeCut];
  const activeDialogue = activeCutData?.dialogues[0];
  const allDialogues = useMemo(() => episode.cuts.flatMap((cut) => cut.dialogues), [episode.cuts]);
  const recordedCount = allDialogues.filter((dialogue) => recordings[dialogue.id]?.saved).length;
  const allRecorded = recordedCount === allDialogues.length && allDialogues.length > 0;
  const progress = (recordedCount / Math.max(allDialogues.length, 1)) * 100;
  const activeRecording = activeDialogue ? recordings[activeDialogue.id] : null;
  const nextCutIndex = Math.min(activeCut + 1, episode.cuts.length - 1);

  const loadPerformance = useCallback(async () => {
    const response = await fetch(`/api/performances?episodeId=${episode.id}`);
    if (response.status === 401) {
      setStatus('저장된 녹음을 불러오려면 로그인하세요.');
      return;
    }

    const body = await response.json().catch(() => null);
    if (!response.ok) {
      setStatus('저장된 녹음 버전을 불러오지 못했습니다.');
      return;
    }

    if (!body?.performance) {
      setStatus('준비 완료. 첫 컷부터 녹음해보세요.');
      return;
    }

    sessionRef.current = {
      performanceId: body.performance.id,
      userId: body.performance.userId
    };

    const restored: Record<string, RecordingState> = {};
    for (const recording of body.recordings ?? []) {
      restored[recording.dialogueId] = {
        url: recording.audioUrl,
        durationMs: recording.durationMs,
        saved: true
      };
    }
    setRecordings(restored);
    setStatus(`저장된 녹음 ${Object.keys(restored).length}개를 불러왔습니다.`);
  }, [episode.id]);

  useEffect(() => {
    if (!isSignedIn) {
      queueMicrotask(() => {
        sessionRef.current = null;
        setRecordings({});
        setTimeline(null);
        setVideoReady(false);
        setStatus('헤더에서 로그인하면 녹음이 계정에 저장됩니다.');
      });
      return;
    }

    queueMicrotask(() => {
      void loadPerformance();
    });
  }, [isSignedIn, user?.id, loadPerformance]);

  useEffect(() => {
    cutRefs.current[activeCut]?.scrollIntoView({
      behavior: previewing ? 'smooth' : 'auto',
      block: 'nearest'
    });
  }, [activeCut, previewing]);

  async function ensurePerformance() {
    if (sessionRef.current) return sessionRef.current;
    if (!isSignedIn) {
      setStatus('녹음 저장을 위해 먼저 로그인하세요.');
      return null;
    }

    const response = await fetch('/api/performances', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ episodeId: episode.id })
    });
    const body = await response.json().catch(() => null);
    if (!response.ok || !body?.performance) {
      setStatus('내 녹음 버전을 만들지 못했습니다.');
      return null;
    }

    const nextSession = {
      performanceId: body.performance.id,
      userId: body.performance.userId
    };
    sessionRef.current = nextSession;
    return nextSession;
  }

  async function toggleRecording(dialogueId: string, cutIndex: number) {
    if (recordingDialogue === dialogueId) {
      mediaRecorder.current?.stop();
      return;
    }

    stopPreview();

    if (!navigator.mediaDevices?.getUserMedia) {
      setStatus('이 브라우저는 마이크 녹음을 지원하지 않습니다. Chrome 또는 Edge에서 localhost로 접속하세요.');
      return;
    }

    const activeSession = await ensurePerformance();
    if (!activeSession) return;

    let stream: MediaStream;
    try {
      setStatus('마이크 권한을 요청하는 중입니다.');
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (error) {
      const message = error instanceof DOMException ? error.name : 'unknown';
      setStatus(`마이크 권한이 차단됐습니다. 주소창 권한에서 마이크를 허용하세요. (${message})`);
      return;
    }

    chunks.current = [];
    activeStream.current = stream;
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
      setStatus('녹음 장치를 시작하지 못했습니다.');
      return;
    }

    mediaRecorder.current = recorder;
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.current.push(event.data);
    };
    recorder.onerror = () => {
      setStatus('녹음 중 오류가 났습니다. 다시 시도하세요.');
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
      setVideoReady(false);
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
    formData.append('durationMs', String(durationMs));
    formData.append('audio', blob, `${dialogueId}.webm`);

    const response = await fetch('/api/recordings', {
      method: 'POST',
      body: formData
    });
    if (!response.ok) {
      setStatus('브라우저에는 녹음됐지만 계정 저장에 실패했습니다.');
      return;
    }

    setRecordings((current) => ({
      ...current,
      [dialogueId]: { ...current[dialogueId], saved: true }
    }));
    setStatus('녹음이 계정에 저장됐습니다.');
  }

  async function buildVideoJob() {
    const activeSession = await ensurePerformance();
    if (!activeSession) return;
    if (!allRecorded) {
      setStatus('모든 컷 녹음이 끝나야 영상을 생성할 수 있습니다.');
      return;
    }

    const response = await fetch('/api/render-jobs', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ performanceId: activeSession.performanceId })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('영상 생성 작업을 만들지 못했습니다.');
      return;
    }

    setTimeline(body.timeline);
    setVideoReady(true);
    setStatus('영상 생성 준비가 끝났습니다. 전체 미리보기로 컷 전환과 싱크를 확인하세요.');
  }

  function playSingle(dialogueId: string, cutIndex: number) {
    const recording = recordings[dialogueId];
    if (!recording) return;
    stopPreview();
    setActiveCut(cutIndex);
    void new Audio(recording.url).play();
  }

  function playFullPreview() {
    if (recordedCount === 0) {
      setStatus('미리보기 전에 최소 한 컷을 녹음하세요.');
      return;
    }

    stopPreview();
    setPreviewing(true);
    setStatus('전체 미리보기를 재생합니다. 컷 장면이 녹음 길이에 맞춰 넘어갑니다.');

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
          previewTimer.current = setTimeout(playNextCut, 320);
        };
        void audio.play();
        return;
      }

      cutIndex += 1;
      previewTimer.current = setTimeout(playNextCut, 1200);
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
    <section className="studio-workspace">
      <aside className="phone studio-phone">
        <div className="phone-head">
          <span>{previewing ? '전체 미리보기 재생 중' : episode.title}</span>
          <button type="button" onClick={previewing ? () => stopPreview() : playFullPreview}>
            {previewing ? '정지' : '미리보기'}
          </button>
        </div>
        <div className="phone-scroll">
          {episode.cuts.map((cut, index) => (
            <article
              className={`cut-panel ${index === activeCut ? 'active' : ''}`}
              key={cut.id}
              onClick={() => setActiveCut(index)}
              ref={(element) => {
                cutRefs.current[index] = element;
              }}
            >
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
          <div className="progress"><i style={{ width: `${((activeCut + 1) / episode.cuts.length) * 100}%` }} /></div>
        </div>
      </aside>

      <div className="studio-stack">
        <section className="studio-panel current-take">
          <div className="studio-panel-head">
            <div>
              <span>현재 녹음</span>
              <h2>CUT {activeCutData?.order}. {activeDialogue?.characterName}</h2>
            </div>
            <strong>{recordedCount}/{allDialogues.length}</strong>
          </div>
          <div className="current-line">
            <p>{activeDialogue?.text}</p>
            <small>{activeDialogue?.direction}</small>
          </div>
          <div className="take-actions">
            <button
              className="primary take-record"
              type="button"
              onClick={() => activeDialogue && toggleRecording(activeDialogue.id, activeCut)}
              disabled={!isSignedIn || !activeDialogue}
            >
              {recordingDialogue === activeDialogue?.id ? '녹음 정지' : activeRecording ? '다시 녹음' : '녹음 시작'}
            </button>
            <button type="button" disabled={!activeRecording} onClick={() => activeDialogue && playSingle(activeDialogue.id, activeCut)}>
              내 녹음 듣기
            </button>
            <button type="button" onClick={() => setActiveCut(nextCutIndex)} disabled={activeCut === episode.cuts.length - 1}>
              다음 컷
            </button>
          </div>
          <p className="studio-status">{status}</p>
          {!isSignedIn && <p className="studio-status warn">헤더의 로그인/회원가입 버튼을 누르면 Clerk 팝업이 열립니다.</p>}
        </section>

        <section className="studio-panel cut-tracker">
          <div className="studio-panel-head compact">
            <h2>컷별 녹음 진행</h2>
            <span>{Math.round(progress)}%</span>
          </div>
          <div className="cut-progress"><i style={{ width: `${progress}%` }} /></div>
          <div className="take-list">
            {episode.cuts.map((cut, cutIndex) => cut.dialogues.map((dialogue) => {
              const recording = recordings[dialogue.id];
              return (
                <button
                  className={`take-row ${cutIndex === activeCut ? 'active' : ''}`}
                  type="button"
                  onClick={() => setActiveCut(cutIndex)}
                  key={dialogue.id}
                >
                  <span>CUT {cut.order}</span>
                  <strong>{dialogue.text}</strong>
                  <small>{recording ? `${(recording.durationMs / 1000).toFixed(1)}초 저장됨` : '미녹음'}</small>
                </button>
              );
            }))}
          </div>
        </section>

        <section className="studio-panel preview-panel">
          <div className="studio-panel-head compact">
            <h2>전체 영상 미리보기</h2>
            <span>{previewing ? '재생 중' : '컷 전환 확인'}</span>
          </div>
          <p>녹음 길이에 맞춰 현재 컷이 유지되고, 다음 컷으로 자연스럽게 넘어갑니다.</p>
          <div className="take-actions">
            <button className="primary" type="button" onClick={playFullPreview} disabled={previewing || recordedCount === 0}>
              전체 재생
            </button>
            <button type="button" onClick={() => stopPreview()} disabled={!previewing}>
              정지
            </button>
          </div>
        </section>

        <section className="studio-panel video-panel">
          <div className="studio-panel-head compact">
            <h2>영상 생성</h2>
            <span>{videoReady ? '생성 준비 완료' : allRecorded ? '생성 가능' : '녹음 필요'}</span>
          </div>
          <p>컷 이미지, 말풍선, 녹음 파일을 묶어 1분 미만 쇼츠 영상으로 생성합니다.</p>
          <div className="video-preview-box">
            <strong>{videoReady ? '영상 패키지가 준비됐습니다.' : `${allDialogues.length - recordedCount}개 컷 녹음이 남았습니다.`}</strong>
            <span>{timeline ? '컷별 녹음 싱크와 전환 정보가 저장됐습니다.' : '녹음 완료 후 영상 생성 버튼을 누르세요.'}</span>
          </div>
          <div className="take-actions">
            <button className="primary" type="button" onClick={buildVideoJob} disabled={!isSignedIn || !allRecorded}>
              영상 생성
            </button>
            <button type="button" disabled={!videoReady}>
              공유하기
            </button>
            <button type="button" disabled={!videoReady}>
              다운로드
            </button>
          </div>
        </section>

        <details className="studio-panel guide-panel">
          <summary>캐스트 가이드 보기</summary>
          <div className="compact-character-grid">
            {episode.characters.map((character) => (
              <div className="character" key={character.id} style={{ borderColor: character.color }}>
                <strong>{character.name}</strong>
                <p>{character.description}</p>
                <small>{character.voiceGuide}</small>
              </div>
            ))}
          </div>
        </details>
      </div>
    </section>
  );
}

function getSupportedMimeType() {
  const candidates = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4'];
  return candidates.find((candidate) => typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported(candidate));
}
