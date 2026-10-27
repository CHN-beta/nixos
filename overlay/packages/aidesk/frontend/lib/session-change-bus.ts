// The running-events stream is consumed by the sidebar, but the open
// transcript lives in useAgentSession under a sibling component. This carries
// "these session files changed on disk" from one to the other without
// threading a callback through the tree.

type Listener = (sessionIds: string[]) => void;

const listeners = new Set<Listener>();

export function publishSessionsChanged(sessionIds: string[]): void {
  if (sessionIds.length === 0) return;
  for (const listener of [...listeners]) {
    try {
      listener(sessionIds);
    } catch {
      // a failing subscriber must not stop the others
    }
  }
}

export function subscribeSessionsChanged(listener: Listener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
