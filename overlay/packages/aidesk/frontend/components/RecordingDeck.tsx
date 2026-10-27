
import React, { useEffect, useRef, useState } from "react";
import { AlertCircle, ArrowUp, Loader2, Mic, Pause, Play, RotateCw, Square, Trash2 } from "lucide-react";
import { MAX_RECORDING_MS, type DictationCapture } from "@/hooks/useDictation";
import { useI18n } from "@/lib/i18n";

const WAVE_WIDTH = 160;
const WAVE_HEIGHT = 28;
const SAMPLE_INTERVAL_MS = 50;
const BAR_SCALE = 3;

interface RecordingDeckProps {
  captureRef: React.RefObject<DictationCapture>;
  isPaused: boolean;
  isReviewing?: boolean;
  isTranscribing: boolean;
  isPlayingPreview?: boolean;
  previewCurrentTime?: number;
  previewDuration?: number;
  transcribeError: string | null;
  onPauseResume: () => void;
  onConvert: () => void;
  onRetry: () => void;
  onPlayPreview?: () => void;
  onSeekPreview?: (seconds: number) => void;
  onConfirmTranscribe?: () => void;
  onDiscard?: () => void;
}

function formatElapsed(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

function DeckIconButton({
  children,
  onClick,
  title,
  tone,
}: {
  children: React.ReactNode;
  onClick: () => void;
  title: string;
  tone?: "danger" | "accent";
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={title}
      aria-label={title}
      style={{
        display: "flex", alignItems: "center", justifyContent: "center",
        width: 28, height: 28, padding: 0, flexShrink: 0,
        background:
          tone === "danger" ? "color-mix(in srgb, var(--status-error) 15%, transparent)"
          : tone === "accent" ? "var(--bg-subtle)"
          : "var(--bg-subtle)",
        border: `1px solid ${tone === "danger" ? "var(--status-error)" : tone === "accent" ? "var(--accent)" : "var(--border)"}`,
        borderRadius: 7,
        color:
          tone === "danger" ? "var(--status-error)"
          : tone === "accent" ? "var(--accent)"
          : "var(--text-muted)",
        cursor: "pointer",
      }}
    >
      {children}
    </button>
  );
}

export function RecordingDeck({
  captureRef,
  isPaused,
  isReviewing = false,
  isTranscribing,
  isPlayingPreview = false,
  previewCurrentTime = 0,
  previewDuration = 0,
  transcribeError,
  onPauseResume,
  onConvert,
  onRetry,
  onPlayPreview,
  onSeekPreview,
  onConfirmTranscribe,
  onDiscard,
}: RecordingDeckProps) {
  const { t } = useI18n();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const barsRef = useRef<number[]>([]);
  const [elapsed, setElapsed] = useState(0);

  const captureActive = !isTranscribing && !transcribeError && !isReviewing;

  useEffect(() => {
    const compute = () => {
      const capture = captureRef.current;
      if (isReviewing && capture?.finalDurationMs != null) {
        setElapsed(capture.finalDurationMs);
        return;
      }
      setElapsed(
        capture
          ? Math.min(
              MAX_RECORDING_MS,
              Math.max(
                0,
                performance.now() -
                  capture.startedAt -
                  capture.pausedAccum -
                  (capture.pausedAt !== null ? performance.now() - capture.pausedAt : 0),
              ),
            )
          : 0,
      );
    };
    compute();
    const id = window.setInterval(compute, 100);
    return () => window.clearInterval(id);
  }, [captureRef, isReviewing]);

  useEffect(() => {
    const canvas = canvasRef.current;
    // Review mode has no live capture but still draws the recorded bars and
    // the playback progress overlay.
    if (!canvas || (!captureActive && !isReviewing)) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    let lastW = 0;

    const style = getComputedStyle(canvas);
    const barColor = (isPaused || isReviewing ? style.getPropertyValue("--text-muted") : style.getPropertyValue("--status-error")).trim();

    const data = new Uint8Array(256);
    let raf = 0;
    let lastPush = 0;

    const draw = (now: number) => {
      raf = requestAnimationFrame(draw);
      // The canvas flexes with the composer; re-fit the backing store whenever
      // its CSS width changes (mobile <-> desktop, panel resizes).
      const cssW = Math.max(1, canvas.clientWidth || WAVE_WIDTH);
      if (cssW !== lastW) {
        lastW = cssW;
        canvas.width = cssW * dpr;
        canvas.height = WAVE_HEIGHT * dpr;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      }
      const barCount = Math.max(24, Math.min(80, Math.floor(cssW / 6)));
      const bars = barsRef.current;
      const analyser = captureRef.current?.analyser ?? null;
      if (analyser && !isPaused && now - lastPush >= SAMPLE_INTERVAL_MS) {
        lastPush = now;
        analyser.getByteTimeDomainData(data);
        let sum = 0;
        for (let i = 0; i < data.length; i++) {
          const v = (data[i] - 128) / 128;
          sum += v * v;
        }
        const rms = Math.sqrt(sum / data.length);
        bars.push(Math.min(1, rms * BAR_SCALE));
        while (bars.length > barCount) bars.shift();
      }
      while (bars.length > barCount) bars.shift();

      ctx.clearRect(0, 0, cssW, WAVE_HEIGHT);
      const gap = 2;
      const barW = Math.max(1, (cssW - gap * (barCount - 1)) / barCount);
      const visible = bars.slice(-barCount);
      const offset = cssW - visible.length * (barW + gap) + gap;

      // Determine playback progress ratio if previewing or reviewing
      const isPreviewActive = (isReviewing || isPaused) && (isPlayingPreview || previewCurrentTime > 0);
      const activeDuration = previewDuration > 0 ? previewDuration : Math.max(1, elapsed / 1000);
      const progressRatio = isPreviewActive ? Math.min(1, Math.max(0, previewCurrentTime / activeDuration)) : 0;
      const progressCutoff = isPreviewActive ? offset + progressRatio * (cssW - offset) : -1;

      const accentColor = style.getPropertyValue("--accent").trim() || "var(--accent)";

      for (let i = 0; i < visible.length; i++) {
        const h = Math.max(2, visible[i] * (WAVE_HEIGHT - 2));
        const x = offset + i * (barW + gap);
        ctx.fillStyle = isPreviewActive && x <= progressCutoff ? accentColor : barColor;
        ctx.fillRect(x, (WAVE_HEIGHT - h) / 2, barW, h);
      }

      if (isPreviewActive && progressCutoff >= offset) {
        ctx.fillStyle = accentColor;
        ctx.fillRect(Math.min(cssW - 2, progressCutoff), 2, 2, WAVE_HEIGHT - 4);
      }
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [captureRef, captureActive, isPaused, isReviewing, isPlayingPreview, previewCurrentTime, previewDuration]);

  // Playback of a recording that is being, or failed to be, transcribed.
  const jobPlayButton = onPlayPreview ? (
    <DeckIconButton onClick={onPlayPreview} title={isPlayingPreview ? t("chatInput.pausePreview") : t("chatInput.playPreview")}>
      {isPlayingPreview ? <Pause size={12} strokeWidth={2} aria-hidden="true" /> : <Play size={12} strokeWidth={2} aria-hidden="true" style={{ marginLeft: 1 }} />}
    </DeckIconButton>
  ) : null;

  return (
    <div
      role="status"
      aria-label={
        isTranscribing
          ? t("chatInput.transcribing")
          : transcribeError
          ? transcribeError
          : isReviewing
          ? t("chatInput.discardDictation")
          : isPaused
          ? t("chatInput.resumeDictation")
          : t("chatInput.dictationRecording")
      }
      style={{
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        gap: 6,
        minHeight: 24,
        padding: "2px 0",
      }}
    >
      {isTranscribing ? (
        <div style={{ display: "flex", alignItems: "center", gap: 8, color: "var(--text-muted)", fontSize: 12 }}>
          {jobPlayButton}
          <Loader2 size={14} strokeWidth={1.8} className="animate-spin" aria-hidden="true" />
          <span style={{ flexShrink: 0 }}>{t("chatInput.transcribing")}</span>
          <div style={{ flex: 1, height: 3, borderRadius: 2, background: "var(--border)", overflow: "hidden", position: "relative" }}>
            <div className="dictation-indeterminate" style={{ position: "absolute", top: 0, bottom: 0, width: "40%", background: "var(--accent)", borderRadius: 2 }} />
          </div>
        </div>
      ) : transcribeError ? (
        <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, color: "var(--text)", minWidth: 0 }}>
          {jobPlayButton}
          <AlertCircle size={14} strokeWidth={1.8} aria-hidden="true" style={{ color: "var(--status-error)", flexShrink: 0 }} />
          <span title={transcribeError} style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", flex: 1 }}>
            {transcribeError}
          </span>
          {onDiscard ? (
            <DeckIconButton onClick={onDiscard} title={t("chatInput.discardDictation")} tone="danger">
              <Trash2 size={14} strokeWidth={1.8} aria-hidden="true" />
            </DeckIconButton>
          ) : null}
          <DeckIconButton onClick={onRetry} title={t("chatInput.retryDictation")} tone="accent">
            <RotateCw size={14} strokeWidth={1.8} aria-hidden="true" />
          </DeckIconButton>
        </div>
      ) : (
        <>
          <div style={{ display: "flex", alignItems: "center", gap: 8, minWidth: 0 }}>
            {isReviewing ? (
              <DeckIconButton
                onClick={onPlayPreview ?? (() => {})}
                title={isPlayingPreview ? t("chatInput.pausePreview") : t("chatInput.playPreview")}
                tone="accent"
              >
                {isPlayingPreview ? <Pause size={14} strokeWidth={1.8} aria-hidden="true" /> : <Play size={14} strokeWidth={1.8} aria-hidden="true" style={{ marginLeft: 1 }} />}
              </DeckIconButton>
            ) : isPaused ? (
              <DeckIconButton
                onClick={onPlayPreview ?? (() => {})}
                title={isPlayingPreview ? t("chatInput.pausePreview") : t("chatInput.playPreview")}
              >
                {isPlayingPreview ? <Pause size={12} strokeWidth={2} aria-hidden="true" /> : <Play size={12} strokeWidth={2} aria-hidden="true" style={{ marginLeft: 1 }} />}
              </DeckIconButton>
            ) : (
              <span
                aria-hidden="true"
                style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--status-error)", flexShrink: 0 }}
              />
            )}
            <span
              style={{
                fontSize: 12,
                fontVariantNumeric: "tabular-nums",
                color: "var(--text)",
                flexShrink: 0,
                minWidth: isReviewing ? 70 : 34,
              }}
            >
              {isReviewing
                ? `${formatElapsed(previewCurrentTime * 1000)} / ${formatElapsed((previewDuration || elapsed / 1000) * 1000)}`
                : isPlayingPreview
                ? `${formatElapsed(previewCurrentTime * 1000)} / ${formatElapsed(elapsed)}`
                : formatElapsed(elapsed)}
            </span>
            <canvas
              ref={canvasRef}
              style={{ flex: 1, minWidth: 0, height: WAVE_HEIGHT, alignSelf: "center", cursor: isReviewing || isPaused ? "pointer" : "default" }}
              aria-hidden="true"
              onClick={(e) => {
                if (!isReviewing && !isPaused) return;
                const rect = e.currentTarget.getBoundingClientRect();
                const ratio = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
                const totalSec = previewDuration > 0 ? previewDuration : elapsed / 1000;
                onSeekPreview?.(ratio * totalSec);
              }}
            />
            <div style={{ display: "flex", alignItems: "center", gap: 4, marginLeft: "auto", flexShrink: 0 }}>
              {isReviewing ? (
                <>
                  <DeckIconButton onClick={onDiscard ?? onConvert} title={t("chatInput.discardDictation")} tone="danger">
                    <Trash2 size={14} strokeWidth={1.8} aria-hidden="true" />
                  </DeckIconButton>
                  <DeckIconButton onClick={onConfirmTranscribe ?? onConvert} title={t("chatInput.transcribeDictation")} tone="accent">
                    <ArrowUp size={14} strokeWidth={2} aria-hidden="true" />
                  </DeckIconButton>
                </>
              ) : (
                <>
                  <DeckIconButton
                    onClick={onPauseResume}
                    title={isPaused ? t("chatInput.resumeDictation") : t("chatInput.pauseDictation")}
                    tone={isPaused ? "accent" : undefined}
                  >
                    {isPaused ? (
                      <Mic size={14} strokeWidth={1.8} aria-hidden="true" />
                    ) : (
                      <Pause size={14} strokeWidth={1.8} aria-hidden="true" />
                    )}
                  </DeckIconButton>
                  <DeckIconButton onClick={onConvert} title={t("chatInput.stopDictation")}>
                    <Square size={11} strokeWidth={2} aria-hidden="true" />
                  </DeckIconButton>
                </>
              )}
            </div>
          </div>
          <div
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={MAX_RECORDING_MS}
            aria-valuenow={Math.round(elapsed)}
            style={{ height: 2, borderRadius: 1, background: "var(--border)", overflow: "hidden" }}
          >
            <div
              style={{
                height: "100%",
                width: isReviewing ? "100%" : `${Math.min(100, (elapsed / MAX_RECORDING_MS) * 100)}%`,
                background: isReviewing ? "var(--accent)" : isPaused ? "var(--text-muted)" : "var(--status-error)",
                transition: "width 0.1s linear",
              }}
            />
          </div>
        </>
      )}
    </div>
  );
}
