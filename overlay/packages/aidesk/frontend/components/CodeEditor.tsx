
import { useMemo } from "react";
import CodeMirror, { type Extension } from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { python } from "@codemirror/lang-python";
import { rust } from "@codemirror/lang-rust";
import { json } from "@codemirror/lang-json";
import { markdown } from "@codemirror/lang-markdown";
import { oneDark } from "@codemirror/theme-one-dark";
import { keymap, EditorView } from "@codemirror/view";
import { Prec } from "@codemirror/state";
import { useTheme } from "@/hooks/useTheme";

interface CodeEditorProps {
  value: string;
  onChange: (value: string) => void;
  onSave?: () => void;
  language?: string;
  readOnly?: boolean;
  wrapLines?: boolean;
  fontSize?: number;
}

const lightTheme = EditorView.theme({
  "&": {
    color: "var(--text)",
    backgroundColor: "var(--bg)",
    fontFamily: "var(--font-mono)",
    fontSize: "13px",
    height: "100%",
  },
  ".cm-content": {
    padding: "8px 0",
    caretColor: "var(--text)",
  },
  ".cm-cursor, .cm-dropCursor": {
    borderLeftColor: "var(--text)",
  },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection": {
    backgroundColor: "var(--bg-selected) !important",
  },
  ".cm-gutters": {
    backgroundColor: "var(--bg-panel)",
    color: "var(--text-dim)",
    borderRight: "1px solid var(--border)",
  },
  ".cm-activeLine": {
    backgroundColor: "var(--bg-subtle)",
  },
  ".cm-activeLineGutter": {
    backgroundColor: "var(--bg-hover)",
    color: "var(--text)",
  },
}, { dark: false });

const darkTheme = EditorView.theme({
  "&": {
    color: "var(--text)",
    backgroundColor: "var(--bg)",
    fontFamily: "var(--font-mono)",
    fontSize: "13px",
    height: "100%",
  },
  ".cm-content": {
    padding: "8px 0",
    caretColor: "var(--text)",
  },
  ".cm-cursor, .cm-dropCursor": {
    borderLeftColor: "var(--text)",
  },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection": {
    backgroundColor: "var(--bg-selected) !important",
  },
  ".cm-gutters": {
    backgroundColor: "var(--bg-panel)",
    color: "var(--text-dim)",
    borderRight: "1px solid var(--border)",
  },
  ".cm-activeLine": {
    backgroundColor: "var(--bg-subtle)",
  },
  ".cm-activeLineGutter": {
    backgroundColor: "var(--bg-hover)",
    color: "var(--text)",
  },
}, { dark: true });

export function CodeEditor({
  value,
  onChange,
  onSave,
  language,
  readOnly = false,
  wrapLines = false,
  fontSize = 13,
}: CodeEditorProps) {
  const { isDark } = useTheme();

  const extensions = useMemo(() => {
    const exts: Extension[] = [];

    const lang = (language ?? "").toLowerCase();
    if (lang === "typescript" || lang === "tsx") {
      exts.push(javascript({ jsx: true, typescript: true }));
    } else if (lang === "javascript" || lang === "jsx" || lang === "mjs" || lang === "cjs") {
      exts.push(javascript({ jsx: true }));
    } else if (lang === "python" || lang === "py") {
      exts.push(python());
    } else if (lang === "rust" || lang === "rs") {
      exts.push(rust());
    } else if (lang === "json" || lang === "jsonl") {
      exts.push(json());
    } else if (lang === "markdown" || lang === "md" || lang === "mdx") {
      exts.push(markdown());
    }

    if (wrapLines) {
      exts.push(EditorView.lineWrapping);
    }

    if (onSave) {
      exts.push(
        Prec.highest(
          keymap.of([
            {
              key: "Mod-s",
              run: () => {
                onSave();
                return true;
              },
            },
          ])
        )
      );
    }

    if (isDark) {
      exts.push(darkTheme);
      exts.push(oneDark);
    } else {
      exts.push(lightTheme);
    }

    return exts;
  }, [language, wrapLines, onSave, isDark]);

  return (
    <div style={{ height: "100%", width: "100%", overflow: "hidden", fontSize }}>
      <CodeMirror
        value={value}
        height="100%"
        style={{ height: "100%" }}
        extensions={extensions}
        onChange={onChange}
        readOnly={readOnly}
        theme="none"
        basicSetup={{
          lineNumbers: true,
          foldGutter: true,
          dropCursor: true,
          allowMultipleSelections: true,
          indentOnInput: true,
          bracketMatching: true,
          closeBrackets: true,
          autocompletion: true,
          highlightActiveLine: true,
          highlightSelectionMatches: true,
        }}
      />
    </div>
  );
}
