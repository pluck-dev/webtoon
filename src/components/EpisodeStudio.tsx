/* eslint-disable @next/next/no-img-element */
'use client';

import { useClerk, useUser } from '@clerk/nextjs';
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
  saving?: boolean;
  error?: boolean;
  blob?: Blob;
};

type SessionState = {
  performanceId: string;
  userId: string;
};

export default function EpisodeStudio({ episode }: { episode: Episode }) {
  const { isSignedIn, user } = useUser();
  const { openSignIn } = useClerk();
  const [activeCut, setActiveCut] = useState(0);
  const [recordingDialogue, setRecordingDialogue] = useState('');
  const [recordings, setRecordings] = useState<Record<string, RecordingState>>({});
  const [timeline, setTimeline] = useState<unknown>(null);
  const [status, setStatus] = useState('로그인하면 녹음이 내 계정에 자동 저장돼요.');
  const [previewing, setPreviewing] = useState(false);
  const [videoReady, setVideoReady] = useState(false);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [rendering, setRendering] = useState(false);
  const [activeDialogueId, setActiveDialogueId] = useState('');
  const [elapsedMs, setElapsedMs] = useState(0);
  const [micBlocked, setMicBlocked] = useState(false);
  const [loadingRecordings, setLoadingRecordings] = useState(false);

  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const startedAt = useRef(0);
  const activeStream = useRef<MediaStream | null>(null);
  const previewTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previewAudio = useRef<HTMLAudioElement | null>(null);
  const sessionRef = useRef<SessionState | null>(null);
  const cutRefs = useRef<(HTMLElement | null)[]>([]);
  const elapsedTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const activeCutData = episode.cuts[activeCut];
  // 컷에 대사가 여러 개여도 선택된 대사를 녹음 대상으로 삼는다 (기본: 컷 첫 대사)
  const activeDialogue =
    activeCutData?.dialogues.find((dialogue) => dialogue.id === activeDialogueId) ??
    activeCutData?.dialogues[0];
  const allDialogues = useMemo(() => episode.cuts.flatMap((cut) => cut.dialogues), [episode.cuts]);
  const recordedCount = allDialogues.filter((dialogue) => recordings[dialogue.id]?.saved).length;
  const allRecorded = recordedCount === allDialogues.length && allDialogues.length > 0;
  const progress = (recordedCount / Math.max(allDialogues.length, 1)) * 100;
  const activeRecording = activeDialogue ? recordings[activeDialogue.id] : null;
  const nextCutIndex = Math.min(activeCut + 1, episode.cuts.length - 1);

  // 모바일 퍼포머 모드: 전체 대사를 순서대로 탐색
  const flatLines = useMemo(
    () => episode.cuts.flatMap((cut, cutIndex) => cut.dialogues.map((dialogue) => ({ cutIndex, dialogue }))),
    [episode.cuts]
  );
  const currentLineIndex = flatLines.findIndex((line) => line.dialogue.id === activeDialogue?.id);
  const goToLine = (index: number) => {
    const line = flatLines[index];
    if (!line) return;
    setActiveCut(line.cutIndex);
    setActiveDialogueId(line.dialogue.id);
  };
  const isRecordingActive = recordingDialogue === activeDialogue?.id;

  const loadPerformance = useCallback(async () => {
    setLoadingRecordings(true);
    try {
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
      const count = Object.keys(restored).length;
      setStatus(count > 0 ? `저장된 녹음 ${count}개를 불러왔습니다.` : '준비 완료. 첫 컷부터 녹음해보세요.');
    } finally {
      setLoadingRecordings(false);
    }
  }, [episode.id]);

  useEffect(() => {
    if (!isSignedIn) {
      queueMicrotask(() => {
        sessionRef.current = null;
        setRecordings({});
        setTimeline(null);
        setVideoReady(false);
        setStatus('로그인하면 녹음이 내 계정에 자동 저장돼요.');
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

  // 언마운트 시 경과 타이머 정리
  useEffect(() => () => {
    if (elapsedTimer.current) clearInterval(elapsedTimer.current);
  }, []);

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

  function startElapsedTimer() {
    startedAt.current = performance.now();
    setElapsedMs(0);
    if (elapsedTimer.current) clearInterval(elapsedTimer.current);
    elapsedTimer.current = setInterval(() => {
      setElapsedMs(performance.now() - startedAt.current);
    }, 100);
  }

  function stopElapsedTimer() {
    if (elapsedTimer.current) {
      clearInterval(elapsedTimer.current);
      elapsedTimer.current = null;
    }
    setElapsedMs(0);
  }

  async function toggleRecording(dialogueId: string, cutIndex: number) {
    // 같은 대사 녹음 중이면 정지
    if (recordingDialogue === dialogueId) {
      mediaRecorder.current?.stop();
      return;
    }
    // 다른 대사를 녹음 중이면 동시 녹음을 막는다
    if (recordingDialogue) {
      setStatus('다른 대사를 녹음 중입니다. 먼저 정지한 뒤 시작하세요.');
      return;
    }

    stopPreview();

    if (!navigator.mediaDevices?.getUserMedia) {
      setStatus('이 브라우저는 마이크 녹음을 지원하지 않아요. Chrome 또는 Edge 최신 버전에서 다시 시도해 주세요.');
      return;
    }

    const activeSession = await ensurePerformance();
    if (!activeSession) return;

    let stream: MediaStream;
    try {
      setStatus('마이크 권한을 요청하는 중입니다.');
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      setMicBlocked(false);
    } catch {
      setMicBlocked(true);
      setStatus('마이크 권한이 차단됐어요. 브라우저 주소창의 권한 설정에서 마이크를 허용해 주세요.');
      return;
    }

    chunks.current = [];
    activeStream.current = stream;
    setActiveCut(cutIndex);
    setActiveDialogueId(dialogueId);
    setRecordingDialogue(dialogueId);
    startElapsedTimer();
    setStatus(`CUT ${cutIndex + 1} 녹음 중입니다. 끝나면 정지를 누르세요.`);

    const mimeType = getSupportedMimeType();
    let recorder: MediaRecorder;
    try {
      recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
    } catch {
      cleanupRecording();
      stopElapsedTimer();
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
      stopElapsedTimer();
      setRecordingDialogue('');
      cleanupRecording();
    };
    recorder.onstop = async () => {
      const durationMs = Math.max(Math.round(performance.now() - startedAt.current), 1000);
      const blob = new Blob(chunks.current, { type: recorder.mimeType || 'audio/webm' });
      const url = URL.createObjectURL(blob);

      stopElapsedTimer();
      setRecordingDialogue('');
      cleanupRecording();
      // 즉시 로컬 재생 가능 상태 + 저장 중 표시
      setRecordings((current) => ({
        ...current,
        [dialogueId]: { url, durationMs, saved: false, saving: true, error: false, blob }
      }));
      setVideoReady(false);
      setVideoUrl(null);
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

    setStatus('녹음을 계정에 저장하는 중입니다...');
    try {
      const response = await fetch('/api/recordings', { method: 'POST', body: formData });
      if (!response.ok) throw new Error('upload failed');
      setRecordings((current) => ({
        ...current,
        [dialogueId]: { ...current[dialogueId], saved: true, saving: false, error: false }
      }));
      setStatus('녹음이 계정에 저장됐습니다.');
    } catch {
      // 로컬 녹음은 유지하고 저장 실패만 표시 → 재시도 가능
      setRecordings((current) => ({
        ...current,
        [dialogueId]: { ...current[dialogueId], saved: false, saving: false, error: true }
      }));
      setStatus('계정 저장에 실패했습니다. 테이크의 "다시 저장"으로 재시도하세요.');
    }
  }

  // 저장 실패한 테이크를 같은 blob으로 재업로드한다
  async function retryUpload(dialogueId: string) {
    const recording = recordings[dialogueId];
    if (!recording?.blob) {
      setStatus('재시도할 데이터가 없습니다. 다시 녹음해 주세요.');
      return;
    }
    const activeSession = await ensurePerformance();
    if (!activeSession) return;
    setRecordings((current) => ({
      ...current,
      [dialogueId]: { ...current[dialogueId], saving: true, error: false }
    }));
    await uploadRecording(activeSession, dialogueId, recording.blob, recording.durationMs);
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
    setVideoUrl(null);
    setRendering(true);
    setStatus('영상 생성 대기열에 등록됐습니다. 렌더가 끝나면 자동으로 표시됩니다.');

    // 워커가 처리할 때까지 잡 상태를 폴링한다 (앱은 막히지 않음)
    const jobId = body.job?.id as string | undefined;
    if (!jobId) {
      setRendering(false);
      setVideoReady(true);
      return;
    }

    for (;;) {
      await new Promise((resolve) => setTimeout(resolve, 3000));
      const poll = await fetch(`/api/render-jobs/${jobId}`);
      if (!poll.ok) {
        setRendering(false);
        setStatus('영상 상태 확인에 실패했습니다.');
        return;
      }
      const state = await poll.json();
      if (state.status === 'DONE' && state.video?.url) {
        setVideoUrl(state.video.url);
        setVideoReady(true);
        setRendering(false);
        setStatus('영상 생성이 완료됐습니다.');
        return;
      }
      if (state.status === 'FAILED') {
        setRendering(false);
        setStatus('영상 생성에 실패했어요. 잠시 후 다시 시도해 주세요.');
        return;
      }
      setStatus(state.status === 'RUNNING' ? '영상을 렌더링하는 중입니다...' : '대기열에서 처리 대기 중입니다...');
    }
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
    <section className="grid gap-4 lg:grid-cols-[minmax(380px,500px)_minmax(0,1fr)] lg:items-start">
      {/* ════════ 퍼포머 (메인, 전 사이즈) ════════ */}
      <div className="lg:sticky lg:top-[76px]">
        {/* 장면 캔버스 */}
        <div className="relative aspect-[3/4] w-full overflow-hidden rounded-2xl border border-[#3a4650] bg-[#080b0d]">
          {activeCutData && (
            <img src={activeCutData.imageUrl} alt="" className="absolute inset-0 h-full w-full object-cover" />
          )}
          <div className="absolute left-3 top-3 z-[2] rounded-full bg-black/55 px-3 py-1.5 text-xs font-black text-paper backdrop-blur">
            CUT {activeCutData?.order} / {episode.cuts.length}
          </div>
          <div className="absolute right-3 top-3 z-[2] rounded-full bg-black/55 px-3 py-1.5 text-xs font-black text-gold backdrop-blur">
            {recordedCount}/{allDialogues.length} 완료
          </div>
          <div className="absolute inset-x-0 bottom-0 z-[1] bg-gradient-to-t from-black/85 to-transparent p-3 pt-10">
            <p className="text-xs font-bold text-paper/80">
              {activeCutData ? `CUT ${activeCutData.order}. ${activeCutData.caption}` : ''}
            </p>
          </div>
        </div>

        {/* 노래방 스타일 자막 + 컨트롤 */}
        <div className="sticky bottom-2 z-10 mt-3 rounded-2xl border border-[#2a2a2a] bg-ink px-4 py-3.5 text-paper shadow-[0_-10px_34px_rgba(0,0,0,.28)] lg:static lg:bottom-auto">
          {/* 대본 (이전 / 현재 / 다음) */}
          <div className="mb-3">
            {currentLineIndex > 0 && (
              <p className="mb-1 truncate text-[13px] font-bold text-paper/30">
                {flatLines[currentLineIndex - 1].dialogue.text}
              </p>
            )}
            <span className="text-[11px] font-black uppercase tracking-wide text-gold">
              {activeDialogue?.characterName ?? '대사 없음'}
              {activeDialogue?.direction ? ` · ${activeDialogue.direction}` : ''}
            </span>
            <p className="text-[clamp(21px,5.4vw,30px)] font-black leading-tight break-keep">
              {activeDialogue?.text ?? '이 컷엔 녹음할 대사가 없어요.'}
            </p>
            {currentLineIndex < flatLines.length - 1 && (
              <p className="mt-1 truncate text-[13px] font-bold text-paper/30">
                ▾ {flatLines[currentLineIndex + 1].dialogue.text}
              </p>
            )}
          </div>

          {/* 컨트롤: 이전 · 녹음 · 다음 */}
          <div className="flex items-center justify-center gap-6">
            <button
              type="button"
              onClick={() => goToLine(currentLineIndex - 1)}
              disabled={currentLineIndex <= 0 || isRecordingActive}
              className="grid h-11 w-11 shrink-0 place-items-center rounded-full border border-white/20 bg-white/10 text-base text-paper transition-colors hover:bg-white/20 disabled:opacity-30"
              aria-label="이전 대사"
            >
              ◀
            </button>
            <button
              type="button"
              onClick={() => {
                // 로그인 안 됐으면 막지 말고 로그인 팝업으로 유도
                if (!isSignedIn) {
                  openSignIn();
                  return;
                }
                if (activeDialogue) toggleRecording(activeDialogue.id, activeCut);
              }}
              disabled={
                !activeDialogue ||
                Boolean(activeRecording?.saving) ||
                (Boolean(recordingDialogue) && !isRecordingActive)
              }
              className={
                'grid h-[60px] w-[60px] shrink-0 place-items-center rounded-full text-2xl font-black shadow-lg transition-transform active:scale-95 disabled:opacity-45 ' +
                (isRecordingActive ? 'animate-soft-pulse bg-coral text-white' : 'bg-gold text-ink')
              }
              aria-label={isRecordingActive ? '녹음 정지' : isSignedIn ? '녹음 시작' : '로그인하고 녹음'}
            >
              {isRecordingActive ? '■' : activeRecording?.saving ? '⋯' : activeRecording ? '↺' : '●'}
            </button>
            <button
              type="button"
              onClick={() => goToLine(currentLineIndex + 1)}
              disabled={currentLineIndex >= flatLines.length - 1 || isRecordingActive}
              className="grid h-11 w-11 shrink-0 place-items-center rounded-full border border-white/20 bg-white/10 text-base text-paper transition-colors hover:bg-white/20 disabled:opacity-30"
              aria-label="다음 대사"
            >
              ▶
            </button>
          </div>

          {/* 보조: 내 녹음 듣기 / 상태 */}
          <div className="mt-3 flex items-center justify-between gap-2 border-t border-[rgba(255,250,240,.14)] pt-2.5 text-xs font-extrabold">
            <button
              type="button"
              disabled={!activeRecording?.url}
              onClick={() => activeDialogue && playSingle(activeDialogue.id, activeCut)}
              className="text-paper/80 underline-offset-2 hover:underline disabled:opacity-30"
            >
              ▷ 내 녹음 듣기
            </button>
            <span>
              {isRecordingActive ? (
                <span className="text-coral">● 녹음 중 {formatClock(elapsedMs)}</span>
              ) : !isSignedIn ? (
                <button type="button" onClick={() => openSignIn()} className="text-gold underline underline-offset-2">
                  로그인하고 저장하기
                </button>
              ) : activeRecording?.saving ? (
                <span className="text-gold">저장 중…</span>
              ) : activeRecording?.error ? (
                <span className="text-coral">저장 실패</span>
              ) : activeRecording?.saved ? (
                <span className="text-[#6fcf97]">저장됨 ✓ {(activeRecording.durationMs / 1000).toFixed(1)}초</span>
              ) : (
                <span className="text-paper/50">미녹음</span>
              )}
            </span>
          </div>
        </div>
      </div>



      {/* ── 보조 패널 ── */}
      <div className="grid content-start gap-3">


        {/* cut-tracker 패널 (라이트 bg-paper) */}
        <section className="overflow-hidden border border-line rounded-lg bg-paper text-ink">
          {/* studio-panel-head compact */}
          <div className="flex items-center justify-between gap-[14px] min-h-[50px] border-b border-line-soft px-4">
            <h2 className="text-lg">컷별 녹음 진행</h2>
            <span className="text-muted text-xs font-black">{Math.round(progress)}%</span>
          </div>
          {/* cut-progress */}
          <div className="h-2 overflow-hidden bg-[#e6dfd2]">
            <i className="block h-full bg-gradient-to-r from-coral to-[#f0bd62]" style={{ width: `${progress}%` }} />
          </div>
          {/* take-loading */}
          {loadingRecordings && (
            <p className="px-3 pt-[10px] text-[#675f54] font-bold">
              저장된 녹음을 불러오는 중...
            </p>
          )}
          {/* take-list */}
          <div className="grid gap-2 p-3">
            {episode.cuts.map((cut, cutIndex) => cut.dialogues.map((dialogue) => {
              const recording = recordings[dialogue.id];
              const isRec = recordingDialogue === dialogue.id;
              let badge = '미녹음';
              let badgeClass = 'text-ink-soft';
              if (isRec) {
                badge = '● 녹음 중';
                badgeClass = 'text-coral';
              } else if (recording?.saving) {
                badge = '저장 중';
                badgeClass = 'text-[#c79a3a]';
              } else if (recording?.error) {
                badge = '저장 실패';
                badgeClass = 'text-coral';
              } else if (recording?.saved) {
                badge = `${(recording.durationMs / 1000).toFixed(1)}초`;
                badgeClass = 'text-[#2f9e6b]';
              } else if (recording?.url) {
                badge = '로컬만';
              }
              const isActive = dialogue.id === activeDialogue?.id;
              return (
                <button
                  className={
                    'grid [grid-template-columns:70px_1fr_auto] items-center gap-[10px] w-full min-h-[56px] border rounded text-left' +
                    (isActive
                      ? ' border-ink bg-card'
                      : ' border-line-soft bg-[#f7f2e8]')
                  }
                  type="button"
                  onClick={() => {
                    setActiveCut(cutIndex);
                    setActiveDialogueId(dialogue.id);
                  }}
                  key={dialogue.id}
                >
                  <span className="text-[#f0bd62] text-xs font-black pl-[10px]">CUT {cut.order}</span>
                  <strong className="overflow-hidden text-ellipsis whitespace-nowrap text-ink">{dialogue.text}</strong>
                  <small className={`font-black pr-[10px] ${badgeClass}`}>{badge}</small>
                </button>
              );
            }))}
          </div>
        </section>

        {/* preview-panel (라이트 bg-paper) */}
        <section className="overflow-hidden border border-line rounded-lg bg-paper text-ink">
          {/* studio-panel-head compact */}
          <div className="flex items-center justify-between gap-[14px] min-h-[50px] border-b border-line-soft px-4">
            <h2 className="text-lg">전체 영상 미리보기</h2>
            <span className="text-muted text-xs font-black">{previewing ? '재생 중' : '컷 전환 확인'}</span>
          </div>
          <p className="px-4 pt-[14px] text-[#675f54] leading-[1.55]">
            녹음 길이에 맞춰 현재 컷이 유지되고, 다음 컷으로 자연스럽게 넘어갑니다.
          </p>
          {/* take-actions */}
          <div className="flex flex-wrap gap-2 px-4 py-[14px]">
            <button
              className="min-h-[40px] border-0 rounded-lg bg-ink text-[#fffaf0] font-black px-[13px]"
              type="button"
              onClick={playFullPreview}
              disabled={previewing || recordedCount === 0}
            >
              전체 재생
            </button>
            <button
              type="button"
              onClick={() => stopPreview()}
              disabled={!previewing}
              className="min-h-[40px] border border-line rounded-lg bg-card text-ink px-[13px]"
            >
              정지
            </button>
          </div>
        </section>

        {/* video-panel (라이트 bg-paper) */}
        <section className="overflow-hidden border border-line rounded-lg bg-paper text-ink">
          {/* studio-panel-head compact */}
          <div className="flex items-center justify-between gap-[14px] min-h-[50px] border-b border-line-soft px-4">
            <h2 className="text-lg">영상 생성</h2>
            <span className="text-muted text-xs font-black">{videoReady ? '생성 준비 완료' : allRecorded ? '생성 가능' : '녹음 필요'}</span>
          </div>
          <p className="px-4 pt-[14px] text-[#675f54] leading-[1.55]">
            컷 이미지, 말풍선, 녹음 파일을 묶어 1분 미만 쇼츠 영상으로 생성합니다.
          </p>
          {/* video-preview-box */}
          <div className="grid gap-1 mx-4 mt-[14px] border border-dashed border-[#cfc6b8] rounded-lg bg-[#f7f2e8] p-[14px]">
            {videoUrl ? (
              <video src={videoUrl} controls playsInline style={{ width: '100%', borderRadius: 12 }} />
            ) : (
              <>
                <strong className="text-ink">
                  {rendering
                    ? '영상을 만드는 중입니다...'
                    : videoReady
                      ? '영상 패키지가 준비됐습니다.'
                      : `${allDialogues.length - recordedCount}개 컷 녹음이 남았습니다.`}
                </strong>
                <span className="text-[#675f54]">{timeline ? '컷별 녹음 싱크와 전환 정보가 저장됐습니다.' : '녹음 완료 후 영상 생성 버튼을 누르세요.'}</span>
              </>
            )}
          </div>
          {/* take-actions */}
          <div className="flex flex-wrap gap-2 px-4 py-[14px]">
            <button
              className="min-h-[40px] border-0 rounded-lg bg-ink text-[#fffaf0] font-black px-[13px]"
              type="button"
              onClick={() => (isSignedIn ? buildVideoJob() : openSignIn())}
              disabled={(isSignedIn && !allRecorded) || rendering}
            >
              {rendering ? '생성 중...' : isSignedIn ? '영상 생성' : '로그인하고 영상 만들기'}
            </button>
            <button
              type="button"
              disabled={!videoUrl}
              className="min-h-[40px] border border-line rounded-lg bg-card text-ink px-[13px]"
            >
              공유하기
            </button>
            {/* take-actions a */}
            <a
              className={
                'inline-flex items-center justify-center min-h-[40px] px-4 border border-ink rounded-[6px] bg-card text-ink font-extrabold no-underline' +
                (!videoUrl ? ' pointer-events-none opacity-45' : '')
              }
              href={videoUrl ?? undefined}
              download={videoUrl ? `webtoon-${episode.id}.mp4` : undefined}
              aria-disabled={!videoUrl}
            >
              다운로드
            </a>
          </div>
        </section>

        {/* guide-panel */}
        <details className="overflow-hidden border border-line rounded-lg bg-paper text-ink">
          <summary className="cursor-pointer px-4 py-[15px] font-black">캐스트 가이드 보기</summary>
          {/* compact-character-grid */}
          <div className="grid gap-[10px] border-t border-line-soft p-3">
            {episode.characters.map((character) => (
              <div
                className="border rounded-lg bg-[#f7f2e8] p-[14px]"
                key={character.id}
                style={{ borderColor: character.color }}
              >
                <strong className="block mb-[6px] text-[#f0bd62]">{character.name}</strong>
                <p className="text-[#675f54] leading-[1.5]">{character.description}</p>
                <small className="text-[#675f54] leading-[1.5]">{character.voiceGuide}</small>
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

// 경과 시간을 m:ss 로 표기
function formatClock(ms: number) {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
}
