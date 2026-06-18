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
  const [timeline, setTimeline] = useState('');
  const [status, setStatus] = useState('Sign in to save your own voice version.');
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

  const loadPerformance = useCallback(async () => {
    const response = await fetch(`/api/performances?episodeId=${episode.id}`);
    if (response.status === 401) {
      setStatus('Sign in to load your saved recordings.');
      return;
    }

    const body = await response.json().catch(() => null);
    if (!response.ok) {
      setStatus('Could not load your saved version.');
      return;
    }

    if (!body?.performance) {
      setStatus('Ready. Record a cut to create your voice version.');
      return;
    }

    const nextSession = {
      performanceId: body.performance.id,
      userId: body.performance.userId
    };
    sessionRef.current = nextSession;

    const restored: Record<string, RecordingState> = {};
    for (const recording of body.recordings ?? []) {
      restored[recording.dialogueId] = {
        url: recording.audioUrl,
        durationMs: recording.durationMs,
        saved: true
      };
    }
    setRecordings(restored);
    setStatus(`Loaded your saved version with ${Object.keys(restored).length} recordings.`);
  }, [episode.id]);

  useEffect(() => {
    if (!isSignedIn) {
      queueMicrotask(() => {
        sessionRef.current = null;
        setRecordings({});
        setTimeline('');
        setStatus('Sign in to save your own voice version.');
      });
      return;
    }

    queueMicrotask(() => {
      void loadPerformance();
    });
  }, [isSignedIn, user?.id, loadPerformance]);

  async function ensurePerformance() {
    if (sessionRef.current) return sessionRef.current;
    if (!isSignedIn) {
      setStatus('Sign in before recording.');
      return null;
    }

    const response = await fetch('/api/performances', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ episodeId: episode.id })
    });
    const body = await response.json().catch(() => null);
    if (!response.ok || !body?.performance) {
      setStatus('Could not create your episode version.');
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
      setStatus('This browser cannot record audio. Use Chrome or Edge on localhost.');
      return;
    }

    const activeSession = await ensurePerformance();
    if (!activeSession) return;

    let stream: MediaStream;
    try {
      setStatus('Requesting microphone permission.');
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (error) {
      const message = error instanceof DOMException ? error.name : 'unknown';
      setStatus(`Microphone permission was blocked. Allow microphone access and try again. (${message})`);
      return;
    }

    chunks.current = [];
    activeStream.current = stream;
    // eslint-disable-next-line react-hooks/purity
    startedAt.current = performance.now();
    setActiveCut(cutIndex);
    setRecordingDialogue(dialogueId);
    setStatus(`Recording CUT ${cutIndex + 1}. Press stop when finished.`);

    const mimeType = getSupportedMimeType();
    let recorder: MediaRecorder;
    try {
      recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
    } catch {
      cleanupRecording();
      setRecordingDialogue('');
      setStatus('Could not start the microphone recorder.');
      return;
    }

    mediaRecorder.current = recorder;
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.current.push(event.data);
    };
    recorder.onerror = () => {
      setStatus('Recording failed. Try again.');
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
    formData.append('durationMs', String(durationMs));
    formData.append('audio', blob, `${dialogueId}.webm`);

    const response = await fetch('/api/recordings', {
      method: 'POST',
      body: formData
    });
    if (!response.ok) {
      setStatus('Recorded locally, but saving to your account failed.');
      return;
    }

    setRecordings((current) => ({
      ...current,
      [dialogueId]: { ...current[dialogueId], saved: true }
    }));
    setStatus('Recording saved to your account.');
  }

  async function buildRenderJob() {
    const activeSession = await ensurePerformance();
    if (!activeSession) return;

    const response = await fetch('/api/render-jobs', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ performanceId: activeSession.performanceId })
    });
    const body = await response.json();
    if (!response.ok) {
      setStatus('Could not create the render timeline.');
      return;
    }

    setTimeline(JSON.stringify(body.timeline, null, 2));
    setStatus('Render timeline created.');
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
      setStatus('Record at least one cut before previewing.');
      return;
    }

    stopPreview();
    setPreviewing(true);
    setStatus('Playing your full preview.');

    let cutIndex = 0;
    const playNextCut = () => {
      if (cutIndex >= episode.cuts.length) {
        stopPreview('Full preview finished.');
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
        void audio.play();
        return;
      }

      cutIndex += 1;
      previewTimer.current = setTimeout(playNextCut, 1400);
    };

    playNextCut();
  }

  function stopPreview(nextStatus = 'Preview stopped.') {
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
            {previewing ? 'Stop' : 'Preview'}
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
          <strong>{activeDialogue ? `${activeDialogue.characterName}: ${activeDialogue.text}` : 'No dialogue'}</strong>
          <span>{activeDialogue?.direction}</span>
          <div className="progress"><i style={{ width: `${progress}%` }} /></div>
        </div>
      </aside>

      <div className="stack">
        <section className="panel">
          <div className="panel-head">
            <h2>Preview</h2>
            <span>{isSignedIn ? `${recordedCount}/${allDialogues.length} saved` : 'Sign in from header'}</span>
          </div>
          <div className="panel-content preview-console">
            <div>
              <strong>{status}</strong>
              <p>{isSignedIn ? 'Play the whole episode after recording to check cut transitions and dialogue timing.' : 'Use the header sign-in button to open the Clerk login popup and save recordings to your account.'}</p>
            </div>
            <div className="preview-actions">
              <button className="primary" type="button" onClick={playFullPreview} disabled={previewing}>
                Play all
              </button>
              <button type="button" onClick={() => stopPreview()} disabled={!previewing}>
                Stop
              </button>
            </div>
          </div>
        </section>

        <section className="panel" id="cast">
          <div className="panel-head">
            <h2>Cast Guide</h2>
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
            <h2>Record by Cut</h2>
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
                    <small>{recording ? `${(recording.durationMs / 1000).toFixed(1)}s ${recording.saved ? 'saved' : 'saving'}` : 'not recorded'}</small>
                  </div>
                  <div className="record-actions">
                    <button className="primary" type="button" onClick={() => toggleRecording(dialogue.id, cutIndex)} disabled={!isSignedIn}>
                      {recordingDialogue === dialogue.id ? 'Stop' : 'Record'}
                    </button>
                    <button type="button" disabled={!recording} onClick={() => playSingle(dialogue.id, cutIndex)}>Listen</button>
                  </div>
                </div>
              );
            }))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>Render Timeline</h2>
            <button className="primary" type="button" onClick={buildRenderJob} disabled={!isSignedIn}>Create</button>
          </div>
          <div className="panel-content render-box">
            <p className="muted">The MP4 renderer will use this timeline with cut images and account recordings.</p>
            <pre className="timeline-json">{timeline || 'No timeline has been created yet.'}</pre>
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
