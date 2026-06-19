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
    <>
      {/* ════════ 모바일 퍼포머 모드 (장면 메인 + 하단 플로팅 자막/녹음) ════════ */}
      <div className="lg:hidden">
        {/* 장면 캔버스 */}
        <div className="relative aspect-[3/4] w-full overflow-hidden rounded-2xl border border-[#3a4650] bg-[#080b0d]">
          {activeCutData && (
            <img src={activeCutData.imageUrl} alt="" className="absolute inset-0 h-full w-full object-cover" />
          )}
          {activeCutData?.dialogues.map((dialogue, dialogueIndex) => (
            <div
              key={dialogue.id}
              className={
                'absolute z-[1] max-w-[78%] rounded-[20px] border-[3px] border-[#080b0d] bg-[#fffdf6] px-3.5 py-2.5 text-[15px] font-black leading-snug text-[#151515] break-keep ' +
                (dialogue.id === activeDialogue?.id ? 'ring-2 ring-gold ' : 'opacity-60 ') +
                (dialogueIndex % 2 === 0 ? 'left-3 top-4' : 'right-3 bottom-24')
              }
            >
              {dialogue.text}
            </div>
          ))}
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

        {/* 하단 플로팅 자막 + 컨트롤 */}
        <div className="sticky bottom-3 z-10 mt-3 rounded-2xl border border-[#2a2a2a] bg-ink p-4 text-paper shadow-[0_-10px_34px_rgba(0,0,0,.28)]">
          <div className="mb-3 min-h-[64px]">
            <span className="text-xs font-black text-gold">
              {activeDialogue?.characterName ?? '대사 없음'}
              {activeDialogue?.direction ? ` · ${activeDialogue.direction}` : ''}
            </span>
            <p className="mt-1 text-[clamp(20px,5.5vw,28px)] font-black leading-tight break-keep">
              {activeDialogue?.text ?? '이 컷에는 녹음할 대사가 없어요. 다음으로 이동하세요.'}
            </p>
          </div>

          <div className="flex items-center justify-between gap-3">
            <button
              type="button"
              onClick={() => goToLine(currentLineIndex - 1)}
              disabled={currentLineIndex <= 0 || isRecordingActive}
              className="grid h-12 w-12 shrink-0 place-items-center rounded-full border border-[rgba(255,250,240,.28)] text-lg text-paper disabled:opacity-35"
              aria-label="이전 대사"
            >
              ◀
            </button>

            <div className="flex flex-col items-center gap-1">
              <button
                type="button"
                onClick={() => activeDialogue && toggleRecording(activeDialogue.id, activeCut)}
                disabled={
                  !isSignedIn ||
                  !activeDialogue ||
                  Boolean(activeRecording?.saving) ||
                  (Boolean(recordingDialogue) && !isRecordingActive)
                }
                className={
                  'grid h-[72px] w-[72px] place-items-center rounded-full text-2xl font-black shadow-lg disabled:opacity-45 ' +
                  (isRecordingActive ? 'animate-soft-pulse bg-coral text-white' : 'bg-gold text-ink')
                }
                aria-label={isRecordingActive ? '녹음 정지' : '녹음 시작'}
              >
                {isRecordingActive ? '■' : activeRecording?.saving ? '⋯' : activeRecording ? '↺' : '●'}
              </button>
              <span className="text-xs font-black text-paper/70">
                {isRecordingActive
                  ? `정지 ${formatClock(elapsedMs)}`
                  : activeRecording?.saved
                    ? '다시 녹음'
                    : '녹음'}
              </span>
            </div>

            <button
              type="button"
              onClick={() => goToLine(currentLineIndex + 1)}
              disabled={currentLineIndex >= flatLines.length - 1 || isRecordingActive}
              className="grid h-12 w-12 shrink-0 place-items-center rounded-full border border-[rgba(255,250,240,.28)] text-lg text-paper disabled:opacity-35"
              aria-label="다음 대사"
            >
              ▶
            </button>
          </div>

          <div className="mt-3 flex items-center justify-between gap-2 border-t border-[rgba(255,250,240,.14)] pt-3 text-xs">
            <button
              type="button"
              disabled={!activeRecording?.url}
              onClick={() => activeDialogue && playSingle(activeDialogue.id, activeCut)}
              className="font-extrabold text-paper/80 underline-offset-2 hover:underline disabled:opacity-35"
            >
              ▷ 내 녹음 듣기
            </button>
            <span className="font-extrabold">
              {!isSignedIn ? (
                <span className="text-gold">로그인 후 저장</span>
              ) : activeRecording?.saving ? (
                <span className="text-gold">저장 중…</span>
              ) : activeRecording?.error ? (
                <span className="text-coral">저장 실패</span>
              ) : activeRecording?.saved ? (
                <span className="text-[#6fcf97]">저장됨 ✓</span>
              ) : (
                <span className="text-paper/50">미녹음</span>
              )}
            </span>
          </div>
        </div>
      </div>

      {/* ════════ 데스크톱 스튜디오 (2열) ════════ */}
      <section className="hidden gap-4 lg:grid lg:[grid-template-columns:minmax(360px,440px)_minmax(0,1fr)]">

      {/* ── 폰 목업 미리보기 (모바일에선 녹음 패널 아래로) ── */}
      <aside className="order-2 h-[56vh] min-h-[420px] overflow-hidden rounded-[28px] border border-[#3a4650] bg-[#080b0d] shadow-[0_24px_70px_rgba(0,0,0,.42)] lg:order-1 lg:sticky lg:top-[76px] lg:h-[calc(100vh-100px)] lg:min-h-[620px]">

        {/* phone-head */}
        <div className="relative z-[2] flex items-center justify-between min-h-[56px] px-4 border-b border-[#252d35] bg-[rgba(8,11,13,.94)] backdrop-blur-[12px] text-[#f0bd62] text-xs font-black">
          <span>{previewing ? '전체 미리보기 재생 중' : episode.title}</span>
          <button
            type="button"
            onClick={previewing ? () => stopPreview() : playFullPreview}
            className="min-h-[40px] border border-[#3a4650] rounded-lg bg-[#141a20] text-[#f5f0e8] px-[13px]"
          >
            {previewing ? '정지' : '미리보기'}
          </button>
        </div>

        {/* phone-scroll */}
        <div className="h-[calc(100%-154px)] overflow-auto p-2">
          {episode.cuts.map((cut, index) => (
            <article
              className={
                'relative min-h-[520px] overflow-hidden border-4 border-[#050607] rounded-[5px] mb-2 bg-[#1a2027]' +
                (index === activeCut ? ' outline outline-[3px] outline-[#f0bd62] -outline-offset-[7px]' : '')
              }
              key={cut.id}
              onClick={() => setActiveCut(index)}
              ref={(element) => {
                cutRefs.current[index] = element;
              }}
            >
              <img src={cut.imageUrl} alt="" className="block w-full h-full min-h-[520px] object-cover" />
              {cut.dialogues.map((dialogue, dialogueIndex) => (
                <div
                  className={
                    'absolute z-[1] max-w-[78%] border-[3px] border-[#080b0d] rounded-[22px] bg-[#fffdf6] text-[#151515] px-4 py-[13px] leading-[1.4] text-lg font-black break-keep' +
                    (dialogueIndex % 2 === 0 ? ' left-[18px] top-[28px]' : ' right-[18px] bottom-[54px]')
                  }
                  key={dialogue.id}
                >
                  {dialogue.text}
                </div>
              ))}
              {/* caption */}
              <div className="absolute left-[14px] right-[14px] bottom-3 z-[1] border-2 border-[#050607] bg-[rgba(5,6,7,.84)] text-[#f5f0e8] px-[11px] py-[9px] font-extrabold leading-[1.4]">
                CUT {cut.order}. {cut.caption}
              </div>
            </article>
          ))}
        </div>

        {/* phone-foot */}
        <div className="relative z-[2] grid gap-[10px] px-4 py-[14px] border-t border-[#252d35] bg-[rgba(8,11,13,.94)] backdrop-blur-[12px]">
          <strong className="block">{activeDialogue ? `${activeDialogue.characterName}: ${activeDialogue.text}` : '대사 없음'}</strong>
          <span className="block mt-1 text-[#aeb8bf] text-xs">{activeDialogue?.direction}</span>
          {/* progress (dark phone 내부 – 어두운 배경 유지) */}
          <div className="h-2 overflow-hidden rounded-full bg-[#2a3138]">
            <i className="block h-full bg-gradient-to-r from-coral to-[#f0bd62]" style={{ width: `${((activeCut + 1) / episode.cuts.length) * 100}%` }} />
          </div>
        </div>
      </aside>

      {/* ── 녹음 패널 스택 (모바일에선 최상단으로) ── */}
      <div className="order-1 grid content-start gap-3 lg:order-2">

        {/* current-take: dark ink 패널 */}
        <section className="overflow-hidden border border-line rounded-lg bg-ink text-[#fffaf0]">

          {/* studio-panel-head (current-take) */}
          <div className="flex items-end justify-between gap-[14px] border-b border-[rgba(255,250,240,.16)] px-4 py-[14px]">
            <div>
              <span className="text-[#f0bd62] text-xs font-black">현재 녹음</span>
              <h2 className="mt-1 text-lg">CUT {activeCutData?.order}. {activeDialogue?.characterName ?? '대사 없음'}</h2>
            </div>
            <strong className="text-[#f0bd62] text-xs font-black">{recordedCount}/{allDialogues.length}</strong>
          </div>

          {/* dialogue-tabs */}
          {activeCutData && activeCutData.dialogues.length > 1 && (
            <div className="flex flex-wrap gap-[6px] px-4 pt-3">
              {activeCutData.dialogues.map((dialogue, index) => {
                const isActive = dialogue.id === activeDialogue?.id;
                const isDone = Boolean(recordings[dialogue.id]?.saved);
                return (
                  <button
                    key={dialogue.id}
                    type="button"
                    className={
                      'rounded-full px-[14px] py-[6px] text-[13px] font-extrabold border min-h-0' +
                      (isActive && isDone
                        ? ' bg-[#6fcf97] border-[#6fcf97] text-ink'
                        : isActive
                          ? ' bg-[#f0bd62] border-[#f0bd62] text-ink'
                          : isDone
                            ? ' bg-transparent border-[#6fcf97] text-[#6fcf97]'
                            : ' bg-transparent border-[rgba(255,250,240,.28)] text-[#fffaf0]')
                    }
                    onClick={() => setActiveDialogueId(dialogue.id)}
                    disabled={Boolean(recordingDialogue)}
                  >
                    대사 {index + 1}{recordings[dialogue.id]?.saved ? ' ✓' : ''}
                  </button>
                );
              })}
            </div>
          )}

          {/* current-line / current-line.empty */}
          {activeDialogue ? (
            <div className="px-4 pt-[18px] pb-[6px]">
              <p className="text-[clamp(22px,3vw,36px)] font-black leading-[1.2] break-keep">{activeDialogue.text}</p>
              <small className="block mt-[10px] text-[#d8cfc0] leading-[1.5]">{activeDialogue.direction}</small>
            </div>
          ) : (
            <div className="px-4 pt-[18px] pb-[6px]">
              <p className="text-[20px] text-[#d8cfc0] font-bold leading-[1.2]">이 컷에는 녹음할 대사가 없습니다.</p>
              <small className="block mt-[10px] text-[#d8cfc0] leading-[1.5]">다음 컷으로 이동해 녹음을 이어가세요.</small>
            </div>
          )}

          {/* mic-blocked */}
          {micBlocked && (
            <div className="flex flex-wrap items-center gap-[10px] mx-4 mt-3 px-[14px] py-3 border border-coral rounded-lg bg-[rgba(239,111,94,.14)] text-[#ffd9d2] leading-[1.5]">
              <span>마이크가 차단돼 있습니다. 주소창 권한에서 마이크를 허용한 뒤 다시 시도하세요.</span>
              <button
                type="button"
                className="ml-auto border border-coral rounded-[6px] bg-coral text-ink px-3 py-[6px] font-extrabold min-h-0"
                onClick={() => activeDialogue && toggleRecording(activeDialogue.id, activeCut)}
              >
                다시 시도
              </button>
            </div>
          )}

          {/* take-actions */}
          <div className="flex flex-wrap gap-2 px-4 py-[14px]">
            <button
              className={
                'min-w-[130px] min-h-[40px] rounded-lg px-[13px] font-black border-0' +
                (recordingDialogue === activeDialogue?.id
                  ? ' bg-coral border-coral text-white animate-soft-pulse'
                  : ' bg-ink text-[#fffaf0]')
              }
              type="button"
              onClick={() => activeDialogue && toggleRecording(activeDialogue.id, activeCut)}
              disabled={
                !isSignedIn ||
                !activeDialogue ||
                Boolean(activeRecording?.saving) ||
                (Boolean(recordingDialogue) && recordingDialogue !== activeDialogue?.id)
              }
            >
              {recordingDialogue === activeDialogue?.id
                ? `■ 정지 ${formatClock(elapsedMs)}`
                : activeRecording?.saving
                  ? '저장 중...'
                  : activeRecording
                    ? '다시 녹음'
                    : '녹음 시작'}
            </button>
            <button
              type="button"
              disabled={!activeRecording?.url}
              onClick={() => activeDialogue && playSingle(activeDialogue.id, activeCut)}
              className="min-h-[40px] border border-[rgba(255,250,240,.28)] rounded-lg bg-transparent text-[#fffaf0] px-[13px]"
            >
              내 녹음 듣기
            </button>
            <button
              type="button"
              onClick={() => setActiveCut(nextCutIndex)}
              disabled={activeCut === episode.cuts.length - 1}
              className="min-h-[40px] border border-[rgba(255,250,240,.28)] rounded-lg bg-transparent text-[#fffaf0] px-[13px]"
            >
              다음 컷
            </button>
          </div>

          {/* 현재 테이크 저장 상태 – take-state */}
          {activeRecording?.saving && (
            <p className="flex items-center gap-[10px] px-4 pt-2 font-extrabold text-[#f0bd62]">
              계정에 저장하는 중...
            </p>
          )}
          {activeRecording?.error && (
            <p className="flex items-center gap-[10px] px-4 pt-2 font-extrabold text-coral">
              저장 실패
              <button
                type="button"
                className="border border-coral rounded-[6px] bg-transparent text-coral px-[10px] py-1 font-extrabold min-h-0"
                onClick={() => activeDialogue && retryUpload(activeDialogue.id)}
              >
                다시 저장
              </button>
            </p>
          )}
          {activeRecording?.saved && (
            <p className="flex items-center gap-[10px] px-4 pt-2 font-extrabold text-[#6fcf97]">
              저장됨 · {(activeRecording.durationMs / 1000).toFixed(1)}초
            </p>
          )}

          {/* studio-status */}
          <p className="border-t border-[rgba(255,250,240,.14)] px-4 py-3 text-[#d8cfc0] leading-[1.5]">
            {status}
          </p>
          {/* studio-status.warn */}
          {!isSignedIn && (
            <p className="border-t border-[rgba(255,250,240,.14)] px-4 py-3 text-[#f0bd62] leading-[1.5]">
              로그인하면 녹음을 저장하고 나만의 더빙 버전을 만들 수 있어요.
            </p>
          )}
        </section>

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
              onClick={buildVideoJob}
              disabled={!isSignedIn || !allRecorded || rendering}
            >
              {rendering ? '생성 중...' : '영상 생성'}
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
    </>
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
