
import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { sanitizeTextForSpeech } from "@/lib/speech-sanitizer";

export const TTS_AUTOPLAY_PREF_KEY = "omp-tts-autoplay";
export const TTS_VOICE_PREF_KEY = "omp-tts-voice";
export const TTS_PREF_EVENT = "omp-tts-pref-change";
export const TTS_STATE_EVENT = "omp-tts-state-change";

export interface SpeechSynthesisState {
  isSupported: boolean;
  isSpeaking: boolean;
  speakingId: string | null;
  voices: SpeechSynthesisVoice[];
  selectedVoiceURI: string | null;
  autoPlayEnabled: boolean;
  speak: (id: string, text: string) => void;
  stop: () => void;
  toggle: (id: string, text: string) => void;
  setAutoPlay: (enabled: boolean) => void;
  setSelectedVoiceURI: (uri: string | null) => void;
}

// Module-level reference to the active utterance to prevent Chromium GC bug
let activeGlobalUtterance: SpeechSynthesisUtterance | null = null;
let currentSpeakingId: string | null = null;

export function getActiveUtterance(): SpeechSynthesisUtterance | null {
  return activeGlobalUtterance;
}

function broadcastState(speakingId: string | null, isSpeaking: boolean) {
  currentSpeakingId = speakingId;
  if (typeof window !== "undefined") {
    window.dispatchEvent(
      new CustomEvent(TTS_STATE_EVENT, { detail: { speakingId, isSpeaking } })
    );
  }
}

export function useSpeechSynthesis(): SpeechSynthesisState {
  const [isSupported, setIsSupported] = useState<boolean>(false);
  const [isSpeaking, setIsSpeaking] = useState<boolean>(() => currentSpeakingId !== null);
  const [speakingId, setSpeakingId] = useState<string | null>(() => currentSpeakingId);
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [selectedVoiceURI, setSelectedVoiceURIState] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    try {
      return localStorage.getItem(TTS_VOICE_PREF_KEY) || null;
    } catch {
      return null;
    }
  });
  const [autoPlayEnabled, setAutoPlayEnabledState] = useState<boolean>(() => {
    if (typeof window === "undefined") return false;
    try {
      return localStorage.getItem(TTS_AUTOPLAY_PREF_KEY) === "true";
    } catch {
      return false;
    }
  });

  const voicesRef = useRef<SpeechSynthesisVoice[]>([]);
  const selectedVoiceURIRef = useRef<string | null>(selectedVoiceURI);

  useEffect(() => {
    voicesRef.current = voices;
  }, [voices]);

  useEffect(() => {
    selectedVoiceURIRef.current = selectedVoiceURI;
  }, [selectedVoiceURI]);

  // Initial browser support check and voice loading
  useEffect(() => {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) {
      setIsSupported(false);
      return;
    }

    setIsSupported(true);

    const updateVoices = () => {
      try {
        const available = window.speechSynthesis.getVoices() || [];
        setVoices(available);
      } catch {
        setVoices([]);
      }
    };

    updateVoices();

    window.speechSynthesis.addEventListener("voiceschanged", updateVoices);

    return () => {
      if (typeof window !== "undefined" && "speechSynthesis" in window) {
        window.speechSynthesis.removeEventListener("voiceschanged", updateVoices);
      }
    };
  }, []);

  // Listen to global TTS state changes across components
  useEffect(() => {
    if (typeof window === "undefined") return;

    const handleStateChange = (e: Event) => {
      const detail = (e as CustomEvent<{ speakingId: string | null; isSpeaking: boolean }>).detail;
      if (!detail) return;
      setSpeakingId(detail.speakingId);
      setIsSpeaking(detail.isSpeaking);
    };

    window.addEventListener(TTS_STATE_EVENT, handleStateChange);
    return () => window.removeEventListener(TTS_STATE_EVENT, handleStateChange);
  }, []);

  // Sync preference changes across components
  useEffect(() => {
    if (typeof window === "undefined") return;

    const handlePrefChange = (e: Event) => {
      const detail = (e as CustomEvent<{ autoPlay?: boolean; voiceURI?: string | null }>).detail;
      if (!detail) return;
      if (typeof detail.autoPlay === "boolean") {
        setAutoPlayEnabledState(detail.autoPlay);
      }
      if (detail.voiceURI !== undefined) {
        setSelectedVoiceURIState(detail.voiceURI);
      }
    };

    window.addEventListener(TTS_PREF_EVENT, handlePrefChange);
    return () => window.removeEventListener(TTS_PREF_EVENT, handlePrefChange);
  }, []);

  const stop = useCallback(() => {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
    try {
      window.speechSynthesis.cancel();
    } catch {
      // ignore
    }
    activeGlobalUtterance = null;
    broadcastState(null, false);
  }, []);

  // Stop playback on Escape key
  useEffect(() => {
    if (typeof window === "undefined") return;

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && currentSpeakingId !== null) {
        stop();
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [stop]);

  const speak = useCallback(
    (id: string, text: string) => {
      if (typeof window === "undefined" || !("speechSynthesis" in window)) return;

      const cleanText = sanitizeTextForSpeech(text);
      if (!cleanText) return;

      try {
        window.speechSynthesis.cancel();
      } catch {
        // ignore
      }

      const utterance = new SpeechSynthesisUtterance(cleanText);
      activeGlobalUtterance = utterance;

      const voice = voicesRef.current.find((v) => v.voiceURI === selectedVoiceURIRef.current);
      if (voice) {
        utterance.voice = voice;
      }

      // A cancelled utterance can still fire a late callback after `speak`
      // installed its replacement — identity-check before touching state.
      utterance.onstart = () => {
        if (activeGlobalUtterance !== utterance) return;
        broadcastState(id, true);
      };

      utterance.onend = () => {
        if (activeGlobalUtterance !== utterance) return;
        activeGlobalUtterance = null;
        broadcastState(null, false);
      };

      utterance.onerror = (e) => {
        if (e.error !== "canceled" && e.error !== "interrupted") {
          console.warn("SpeechSynthesis error:", e.error);
        }
        if (activeGlobalUtterance !== utterance) return;
        activeGlobalUtterance = null;
        broadcastState(null, false);
      };

      try {
        window.speechSynthesis.speak(utterance);
      } catch (err) {
        console.warn("Failed to speak utterance:", err);
        activeGlobalUtterance = null;
        broadcastState(null, false);
      }
    },
    []
  );

  const toggle = useCallback(
    (id: string, text: string) => {
      if (currentSpeakingId === id) {
        stop();
      } else {
        speak(id, text);
      }
    },
    [speak, stop]
  );

  const setAutoPlay = useCallback((enabled: boolean) => {
    setAutoPlayEnabledState(enabled);
    if (typeof window !== "undefined") {
      try {
        localStorage.setItem(TTS_AUTOPLAY_PREF_KEY, String(enabled));
      } catch {
        // ignore
      }
      window.dispatchEvent(
        new CustomEvent(TTS_PREF_EVENT, { detail: { autoPlay: enabled } })
      );
    }
  }, []);

  const setSelectedVoiceURI = useCallback((uri: string | null) => {
    setSelectedVoiceURIState(uri);
    if (typeof window !== "undefined") {
      try {
        if (uri) {
          localStorage.setItem(TTS_VOICE_PREF_KEY, uri);
        } else {
          localStorage.removeItem(TTS_VOICE_PREF_KEY);
        }
      } catch {
        // ignore
      }
      window.dispatchEvent(
        new CustomEvent(TTS_PREF_EVENT, { detail: { voiceURI: uri } })
      );
    }
  }, []);

  return {
    isSupported,
    isSpeaking,
    speakingId,
    voices,
    selectedVoiceURI,
    autoPlayEnabled,
    speak,
    stop,
    toggle,
    setAutoPlay,
    setSelectedVoiceURI,
  };
}

const SpeechSynthesisContext = createContext<SpeechSynthesisState | null>(null);

export function SpeechSynthesisProvider({ value, children }: { value: SpeechSynthesisState; children: ReactNode }) {
  return (
    <SpeechSynthesisContext.Provider value={value}>
      {children}
    </SpeechSynthesisContext.Provider>
  );
}

// Outside a provider there is no controller to share. Returning an inert state
// keeps consumers renderable (the read-aloud action just stays hidden) without
// mounting one more controller — and its window listeners — per message row.
const INERT_SPEECH_STATE: SpeechSynthesisState = {
  isSupported: false,
  isSpeaking: false,
  speakingId: null,
  voices: [],
  selectedVoiceURI: null,
  autoPlayEnabled: false,
  speak: () => {},
  stop: () => {},
  toggle: () => {},
  setAutoPlay: () => {},
  setSelectedVoiceURI: () => {},
};

export function useSpeechContext(): SpeechSynthesisState {
  return useContext(SpeechSynthesisContext) ?? INERT_SPEECH_STATE;
}
