
import { useState, useCallback, useRef, useEffect } from "react";

function isAttachableDragItem(item: DataTransferItem): boolean {
  return item.type.startsWith("image/") || item.type === "text/plain" || item.type === "text/markdown";
}

export function useDragDrop(onDrop: (files: File[]) => void) {
  const [isDragOver, setIsDragOver] = useState(false);
  const counterRef = useRef(0);

  // A drag can end outside the drop target (release over browser chrome, ESC,
  // OS-level cancel) with no balancing dragleave, which would leave the
  // overlay stuck visible until the next drag cycle. Reset on any window-level
  // drop/dragend — handleDrop's own reset stays, this covers the rest.
  useEffect(() => {
    const reset = () => {
      counterRef.current = 0;
      setIsDragOver(false);
    };
    window.addEventListener("drop", reset);
    window.addEventListener("dragend", reset);
    return () => {
      window.removeEventListener("drop", reset);
      window.removeEventListener("dragend", reset);
    };
  }, []);

  const handleDragEnter = useCallback((e: React.DragEvent) => {
    const hasAttachables = Array.from(e.dataTransfer.items).some(isAttachableDragItem);
    if (!hasAttachables) return;
    e.preventDefault();
    counterRef.current += 1;
    setIsDragOver(true);
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    const hasAttachables = Array.from(e.dataTransfer.items).some(isAttachableDragItem);
    if (!hasAttachables) return;
    e.preventDefault();
  }, []);

  const handleDragLeave = useCallback(() => {
    counterRef.current -= 1;
    if (counterRef.current <= 0) {
      counterRef.current = 0;
      setIsDragOver(false);
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    counterRef.current = 0;
    setIsDragOver(false);
    const files = Array.from(e.dataTransfer.files);
    onDrop(files);
  }, [onDrop]);

  return { isDragOver, handleDragEnter, handleDragOver, handleDragLeave, handleDrop };
}