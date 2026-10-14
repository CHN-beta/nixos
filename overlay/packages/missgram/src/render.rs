use crate::misskey::{Job, NoteKind};
use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd};
use reqwest::Url;
use std::sync::LazyLock;

const MESSAGE_LIMIT: usize = 4096;

pub struct Rendered {
    pub messages: Vec<String>,
    pub preview_url: Option<Url>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum Format {
    Bold,
    Italic,
    Strike,
    Code,
    Pre,
    Spoiler,
    Link(Url),
}

impl Format {
    fn open(&self, html: &mut String) {
        match self {
            Self::Bold => html.push_str("<b>"),
            Self::Italic => html.push_str("<i>"),
            Self::Strike => html.push_str("<s>"),
            Self::Code => html.push_str("<code>"),
            Self::Pre => html.push_str("<pre>"),
            Self::Spoiler => html.push_str("<span class=\"tg-spoiler\">"),
            Self::Link(url) => {
                html.push_str("<a href=\"");
                escape_into(url.as_str(), html);
                html.push_str("\">");
            }
        }
    }

    fn close(&self) -> &'static str {
        match self {
            Self::Bold => "</b>",
            Self::Italic => "</i>",
            Self::Strike => "</s>",
            Self::Code => "</code>",
            Self::Pre => "</pre>",
            Self::Spoiler => "</span>",
            Self::Link(_) => "</a>",
        }
    }
}

enum Token {
    Text(String),
    Open(Format),
    Close,
}

#[derive(Default)]
struct Document {
    tokens: Vec<Token>,
    has_text: bool,
    trailing_newlines: usize,
    pending_breaks: usize,
}

impl Document {
    fn text(&mut self, text: &str) {
        if text.is_empty() {
            return;
        }
        self.flush_breaks();
        self.push_text(text);
    }

    fn flush_breaks(&mut self) {
        if self.has_text && self.pending_breaks > self.trailing_newlines {
            let breaks = "\n".repeat(self.pending_breaks - self.trailing_newlines);
            self.push_text(&breaks);
        }
        self.pending_breaks = 0;
    }

    fn push_text(&mut self, text: &str) {
        if let Some(Token::Text(previous)) = self.tokens.last_mut() {
            previous.push_str(text);
        } else {
            self.tokens.push(Token::Text(text.to_owned()));
        }
        self.has_text = true;
        let newlines = text.chars().rev().take_while(|&c| c == '\n').count();
        if newlines == text.len() {
            self.trailing_newlines += newlines;
        } else {
            self.trailing_newlines = newlines;
        }
    }

    fn breaks(&mut self, count: usize) {
        self.pending_breaks = self.pending_breaks.max(count);
    }

    fn open(&mut self, format: Format) {
        self.flush_breaks();
        self.tokens.push(Token::Open(format));
    }

    fn close(&mut self) {
        self.tokens.push(Token::Close);
    }

    fn link(&mut self, label: &str, url: &Url) {
        let safe = safe_url(url.as_str());
        if let Some(url) = safe.as_ref() {
            self.open(Format::Link(url.clone()));
        }
        self.text(label);
        if safe.is_some() {
            self.close();
        }
    }
}

pub fn render(job: &Job, reply_id: Option<i32>) -> Rendered {
    let mut document = Document::default();
    if let Some(cw) = &job.note.cw {
        if cw.trim().is_empty() {
            document.text("内容警告");
        } else {
            markdown(&mut document, cw);
        }
        document.breaks(2);
        document.open(Format::Spoiler);
    }

    let renote_url = job
        .note
        .renote
        .as_ref()
        .map(|renote| job.note_url(&renote.id));
    let mut preview_url = None;
    match job.note.kind() {
        NoteKind::Forward => {
            document.text("转发了");
            if reply_id.is_none() {
                if let Some(url) = &renote_url {
                    document.link("帖子", url);
                } else {
                    document.text("帖子");
                }
            } else {
                document.text("帖子");
            }
        }
        NoteKind::Quote => {
            if reply_id.is_none()
                && let Some(url) = &renote_url
            {
                document.text("引用了");
                document.link("帖子", url);
                document.breaks(2);
            }
            if let Some(text) = &job.note.text {
                preview_url = markdown(&mut document, text);
            }
        }
        NoteKind::Post => {
            if let Some(text) = &job.note.text {
                preview_url = markdown(&mut document, text);
            }
        }
    }

    if job.note.cw.is_some() {
        document.close();
    }
    document.breaks(2);
    document.link("在联邦宇宙查看", &job.note_url(&job.note.id));
    if reply_id.is_none() && renote_url.is_some() {
        preview_url = renote_url;
    }
    if job.note.cw.is_some() {
        preview_url = None;
    }
    Rendered {
        messages: split(document.tokens, MESSAGE_LIMIT),
        preview_url,
    }
}

fn safe_url(value: &str) -> Option<Url> {
    let url = Url::parse(value).ok()?;
    matches!(url.scheme(), "http" | "https" | "tg").then_some(url)
}

fn http_url(value: &str) -> Option<Url> {
    let url = safe_url(value)?;
    matches!(url.scheme(), "http" | "https").then_some(url)
}

fn first_http_url(text: &str) -> Option<(usize, Url)> {
    static URL_PATTERN: LazyLock<regex::Regex> = LazyLock::new(|| {
        regex::Regex::new(r#"(?i)https?://[^\s<>"'`*~]+"#).expect("constant URL pattern")
    });
    URL_PATTERN.find_iter(text).find_map(|found| {
        let mut candidate = found
            .as_str()
            .trim_end_matches(['.', ',', ';', ':', '!', '?']);
        // A final balanced parenthesis can be part of a URL, unlike Markdown delimiters.
        for (open, close) in [('(', ')'), ('[', ']'), ('{', '}')] {
            while candidate.ends_with(close)
                && candidate.chars().filter(|&c| c == close).count()
                    > candidate.chars().filter(|&c| c == open).count()
            {
                candidate = &candidate[..candidate.len() - close.len_utf8()];
            }
        }
        http_url(candidate).map(|url| (found.start(), url))
    })
}

struct Frame {
    end: TagEnd,
    formatted: bool,
    destination: Option<String>,
}

fn markdown(document: &mut Document, text: &str) -> Option<Url> {
    let options =
        Options::ENABLE_STRIKETHROUGH | Options::ENABLE_TABLES | Options::ENABLE_TASKLISTS;
    let mut frames = Vec::new();
    let mut lists: Vec<Option<u64>> = Vec::new();
    let mut preview = first_http_url(text);
    for (event, range) in Parser::new_ext(text, options).into_offset_iter() {
        match event {
            Event::Start(tag) => {
                let end = tag.to_end();
                let mut destination = None;
                let format = match tag {
                    Tag::Heading { .. } => {
                        document.breaks(2);
                        Some(Format::Bold)
                    }
                    Tag::Strong => Some(Format::Bold),
                    Tag::Emphasis => Some(Format::Italic),
                    Tag::Strikethrough => Some(Format::Strike),
                    Tag::CodeBlock(_) => {
                        document.breaks(2);
                        Some(Format::Pre)
                    }
                    Tag::Link { dest_url, .. } => {
                        if let Some(url) = http_url(&dest_url)
                            && preview
                                .as_ref()
                                .is_none_or(|(start, _)| range.start <= *start)
                        {
                            preview = Some((range.start, url));
                        }
                        let url = safe_url(&dest_url);
                        if url.is_none() && !dest_url.is_empty() {
                            destination = Some(dest_url.to_string());
                        }
                        url.map(Format::Link)
                    }
                    Tag::Image { dest_url, .. } => {
                        if let Some(url) = http_url(&dest_url)
                            && preview
                                .as_ref()
                                .is_none_or(|(start, _)| range.start <= *start)
                        {
                            preview = Some((range.start, url));
                        }
                        document.text("[image: ");
                        destination = Some(dest_url.to_string());
                        None
                    }
                    Tag::List(start) => {
                        document.breaks(1);
                        lists.push(start);
                        None
                    }
                    Tag::Item => {
                        document.breaks(1);
                        document.text(&"  ".repeat(lists.len().saturating_sub(1)));
                        if let Some(Some(next)) = lists.last_mut() {
                            document.text(&format!("{next}. "));
                            *next = next.saturating_add(1);
                        } else {
                            document.text("• ");
                        }
                        None
                    }
                    Tag::BlockQuote(_) => {
                        document.breaks(1);
                        document.text("› ");
                        None
                    }
                    Tag::Paragraph
                    | Tag::HtmlBlock
                    | Tag::Table(_)
                    | Tag::TableHead
                    | Tag::TableRow => {
                        document.breaks(1);
                        None
                    }
                    _ => None,
                };
                let formatted = format.is_some();
                if let Some(format) = format {
                    document.open(format);
                }
                frames.push(Frame {
                    end,
                    formatted,
                    destination,
                });
            }
            Event::End(end) => {
                let frame = frames.pop().expect("balanced Markdown events");
                debug_assert_eq!(frame.end, end);
                if frame.formatted {
                    document.close();
                }
                if end == TagEnd::Image {
                    document.text("]");
                }
                if let Some(destination) = frame.destination.filter(|value| !value.is_empty()) {
                    document.text(" (");
                    if let Some(url) = safe_url(&destination) {
                        document.link(&destination, &url);
                    } else {
                        document.text(&destination);
                    }
                    document.text(")");
                }
                match end {
                    TagEnd::Paragraph
                    | TagEnd::Heading(_)
                    | TagEnd::CodeBlock
                    | TagEnd::HtmlBlock
                    | TagEnd::BlockQuote(_)
                    | TagEnd::Table => document.breaks(2),
                    TagEnd::Item | TagEnd::TableHead | TagEnd::TableRow => document.breaks(1),
                    TagEnd::TableCell => document.text(" | "),
                    TagEnd::List(_) => {
                        lists.pop();
                        document.breaks(1);
                    }
                    _ => {}
                }
            }
            Event::Text(value) | Event::InlineMath(value) | Event::DisplayMath(value) => {
                document.text(&value);
            }
            Event::Code(value) => {
                document.open(Format::Code);
                document.text(&value);
                document.close();
            }
            Event::Html(value) | Event::InlineHtml(value) => {
                raw_html(document, &value);
            }
            Event::SoftBreak | Event::HardBreak => document.text("\n"),
            Event::Rule => {
                document.breaks(1);
                document.text("———");
                document.breaks(1);
            }
            Event::FootnoteReference(value) => {
                document.text("[^");
                document.text(&value);
                document.text("]");
            }
            Event::TaskListMarker(checked) => document.text(if checked { "☑ " } else { "☐ " }),
        }
    }
    preview.map(|(_, url)| url)
}

// Raw HTML is visible text, never trusted markup. Only a bare br tag is a newline.
fn raw_html(document: &mut Document, value: &str) {
    let mut rest = value;
    while let Some(start) = rest.find('<') {
        document.text(&rest[..start]);
        rest = &rest[start..];
        let Some(end) = rest.find('>') else {
            document.text(rest);
            return;
        };
        let tag = &rest[..=end];
        let inside = tag[1..tag.len() - 1].trim();
        let name = inside.strip_suffix('/').unwrap_or(inside).trim_end();
        if name.eq_ignore_ascii_case("br") {
            document.text("\n");
        } else {
            document.text(tag);
        }
        rest = &rest[end + 1..];
    }
    document.text(rest);
}

fn escape_char(character: char, html: &mut String) {
    match character {
        '&' => html.push_str("&amp;"),
        '<' => html.push_str("&lt;"),
        '>' => html.push_str("&gt;"),
        '"' => html.push_str("&quot;"),
        '\'' => html.push_str("&#39;"),
        _ => html.push(character),
    }
}

fn escape_into(text: &str, html: &mut String) {
    for character in text.chars() {
        escape_char(character, html);
    }
}

fn effective_formats(active: &[Format]) -> Vec<Format> {
    let spoiler = active.contains(&Format::Spoiler);
    // Telegram forbids code entities overlapping other entities. A CW takes priority:
    // code remains readable plaintext rather than leaking outside its spoiler.
    if !spoiler
        && let Some(code) = active
            .iter()
            .rev()
            .find(|format| matches!(format, Format::Code | Format::Pre))
    {
        return vec![code.clone()];
    }
    let mut effective = Vec::new();
    let mut linked = false;
    for format in active {
        if matches!(format, Format::Code | Format::Pre) || effective.contains(format) {
            continue;
        }
        if matches!(format, Format::Link(_)) {
            if linked {
                continue;
            }
            linked = true;
        }
        effective.push(format.clone());
    }
    effective
}

fn sync_formats(html: &mut String, current: &mut Vec<Format>, wanted: &[Format]) {
    let common = current
        .iter()
        .zip(wanted)
        .take_while(|(left, right)| left == right)
        .count();
    for format in current[common..].iter().rev() {
        html.push_str(format.close());
    }
    current.truncate(common);
    for format in &wanted[common..] {
        format.open(html);
        current.push(format.clone());
    }
}

fn split(tokens: Vec<Token>, limit: usize) -> Vec<String> {
    let mut messages = Vec::new();
    let mut html = String::new();
    let mut length = 0;
    let mut active = Vec::new();
    let mut current = Vec::new();
    for token in tokens {
        match token {
            Token::Open(format) => active.push(format),
            Token::Close => {
                active.pop().expect("balanced renderer tokens");
            }
            Token::Text(text) => {
                let wanted = effective_formats(&active);
                let mut synced = false;
                for character in text.chars() {
                    if length + character.len_utf16() > limit {
                        sync_formats(&mut html, &mut current, &[]);
                        messages.push(std::mem::take(&mut html));
                        length = 0;
                        synced = false;
                    }
                    if !synced {
                        sync_formats(&mut html, &mut current, &wanted);
                        synced = true;
                    }
                    escape_char(character, &mut html);
                    length += character.len_utf16();
                }
            }
        }
    }
    if length > 0 {
        sync_formats(&mut html, &mut current, &[]);
        messages.push(html);
    }
    messages
}

fn entity_character(entity: &str) -> Option<char> {
    match entity {
        "amp" => Some('&'),
        "lt" => Some('<'),
        "gt" => Some('>'),
        "quot" => Some('"'),
        "apos" => Some('\''),
        _ => {
            let number = entity.strip_prefix('#')?;
            let code = if let Some(hex) = number
                .strip_prefix('x')
                .or_else(|| number.strip_prefix('X'))
            {
                u32::from_str_radix(hex, 16).ok()?
            } else {
                number.parse().ok()?
            };
            char::from_u32(code)
        }
    }
}

/// Telegram limits count UTF-16 code units after HTML entities have been decoded.
/// This accepts the balanced, escaped HTML emitted by this module.
pub fn visible_len(html: &str) -> usize {
    let mut rest = html;
    let mut length = 0;
    while !rest.is_empty() {
        if rest.starts_with('<')
            && let Some(end) = rest.find('>')
        {
            rest = &rest[end + 1..];
            continue;
        }
        if rest.starts_with('&')
            && let Some(end) = rest.find(';')
            && let Some(character) = entity_character(&rest[1..end])
        {
            length += character.len_utf16();
            rest = &rest[end + 1..];
            continue;
        }
        let character = rest.chars().next().expect("nonempty remainder");
        length += character.len_utf16();
        rest = &rest[character.len_utf8()..];
    }
    length
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::misskey::{Note, Renote};

    fn job(text: Option<&str>, renote: Option<&str>) -> Job {
        Job {
            server: Url::parse("https://misskey.example/").unwrap(),
            note: Note {
                id: "source".into(),
                text: text.map(str::to_owned),
                cw: None,
                renote: renote.map(|id| Renote { id: id.into() }),
                files: Vec::new(),
                visibility: "public".into(),
                local_only: false,
                reply_id: None,
            },
        }
    }

    fn plain(html: &str) -> String {
        let mut result = String::new();
        let mut rest = html;
        while !rest.is_empty() {
            if rest.starts_with('<') {
                let end = rest.find('>').expect("closed tag");
                rest = &rest[end + 1..];
            } else if rest.starts_with('&') {
                let end = rest.find(';').expect("closed entity");
                result.push(entity_character(&rest[1..end]).expect("known entity"));
                rest = &rest[end + 1..];
            } else {
                let character = rest.chars().next().unwrap();
                result.push(character);
                rest = &rest[character.len_utf8()..];
            }
        }
        result
    }

    fn assert_valid(messages: &[String]) {
        assert!(!messages.is_empty());
        for html in messages {
            assert!(!html.is_empty());
            let visible = plain(html);
            assert_eq!(visible_len(html), visible.encode_utf16().count());
            assert!((1..=MESSAGE_LIMIT).contains(&visible_len(html)));
            let mut stack = Vec::new();
            let mut rest = html.as_str();
            while let Some(start) = rest.find('<') {
                let end = rest[start..].find('>').unwrap() + start;
                let tag = &rest[start + 1..end];
                if let Some(name) = tag.strip_prefix('/') {
                    assert_eq!(stack.pop(), Some(name), "{html}");
                } else {
                    let name = tag.split_whitespace().next().unwrap();
                    assert!(matches!(
                        name,
                        "b" | "i" | "s" | "code" | "pre" | "span" | "a"
                    ));
                    if name == "span" {
                        assert_eq!(tag, "span class=\"tg-spoiler\"");
                    }
                    if name == "a" {
                        assert!(tag.starts_with("a href=\""));
                        assert!(!stack.contains(&"a"));
                    }
                    if matches!(name, "pre" | "code") {
                        assert!(stack.is_empty(), "overlapping code entity: {html}");
                    } else {
                        assert!(!stack.contains(&"pre") && !stack.contains(&"code"));
                    }
                    stack.push(name);
                }
                rest = &rest[end + 1..];
            }
            assert!(stack.is_empty());
        }
    }

    fn markdown_html(text: &str) -> String {
        let mut document = Document::default();
        markdown(&mut document, text);
        let messages = split(document.tokens, MESSAGE_LIMIT);
        assert_valid(&messages);
        messages.join("")
    }

    #[test]
    fn text_attributes_and_raw_html_cannot_inject_markup() {
        let html = markdown_html(
            "<script>alert(1)</script>\n\nA & B <br> C <BR /> D\n\n\
             [safe](https://example.org/?a=1&b=%22) \
             [bad](javascript:alert%281%29) [data](data:text/html,evil) \
             [tg](tg://user?id=1) <b>raw</b>",
        );
        assert!(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"));
        assert!(plain(&html).contains("A & B \n C \n D"));
        assert!(html.contains("href=\"https://example.org/?a=1&amp;b=%22\""));
        assert!(!html.contains("href=\"javascript:") && !html.contains("href=\"data:"));
        assert!(plain(&html).contains("javascript:alert%281%29"));
        assert!(html.contains("href=\"tg://user?id=1\""));
        assert!(plain(&html).contains("<b>raw</b>"));
        let mut escaped = String::new();
        escape_into("\"'&<>", &mut escaped);
        assert_eq!(escaped, "&quot;&#39;&amp;&lt;&gt;");
    }

    #[test]
    fn structures_and_images_are_readable_without_unsupported_tags() {
        let html = markdown_html(
            "# Heading\n\n1. first\n2. second\n   - nested\n\n\
             > quoted\n\n![cat & dog](https://example.org/image.png)\n\n\
             | left | right |\n| --- | --- |\n| one | two |\n\n~~gone~~ and `a < b`",
        );
        let text = plain(&html);
        assert!(html.contains("<b>Heading</b>"));
        assert!(text.contains("1. first") && text.contains("2. second"));
        assert!(text.contains("• nested") && text.contains("quoted"));
        assert!(text.contains("cat & dog") && text.contains("https://example.org/image.png"));
        assert!(text.contains("left | right") && text.contains("one | two"));
        assert!(html.contains("<s>gone</s>") && html.contains("<code>a &lt; b</code>"));
    }

    #[test]
    fn unicode_and_entities_split_without_content_loss() {
        let text = format!("{}😀&<é{}", "a".repeat(4095), "界🧑‍💻e\u{301}".repeat(900));
        let mut document = Document::default();
        document.text(&text);
        let messages = split(document.tokens, MESSAGE_LIMIT);
        assert_valid(&messages);
        assert_eq!(visible_len(&messages[0]), 4095);
        assert!(plain(&messages[1]).starts_with("😀&<é"));
        assert_eq!(
            messages
                .iter()
                .map(|message| plain(message))
                .collect::<String>(),
            text
        );
        assert_eq!(visible_len("&#x1F600;&amp;&#39;<b>界</b>"), 5);
    }

    #[test]
    fn nested_formatting_and_links_are_balanced_across_chunks() {
        let content = "<&😀".repeat(2500);
        let input = format!(
            "**bold *italic ~~[{}](https://example.org/?a=1&b=2)~~* end**",
            content.replace('&', "&amp;").replace('<', "&lt;")
        );
        let mut document = Document::default();
        markdown(&mut document, &input);
        let messages = split(document.tokens, MESSAGE_LIMIT);
        assert_valid(&messages);
        assert!(messages.len() > 2);
        assert!(messages[1].starts_with("<b><i><s><a href="));
        let joined = messages
            .iter()
            .map(|message| plain(message))
            .collect::<String>();
        assert_eq!(joined, format!("bold italic {content} end"));
        let mut unsplit = Document::default();
        markdown(&mut unsplit, &input);
        assert_eq!(joined, plain(&split(unsplit.tokens, usize::MAX).join("")));
    }

    #[test]
    fn code_never_overlaps_other_entities() {
        let html = markdown_html("**before `code < &` after**\n\n```rust\nlet x = 1 < 2;\n``` ");
        assert!(html.contains("</b><code>code &lt; &amp;</code><b>"));
        assert!(html.contains("<pre>let x = 1 &lt; 2;\n</pre>"));
    }

    #[test]
    fn code_and_empty_boundaries_do_not_drop_text_or_emit_empty_chunks() {
        for text in [
            "x".repeat(MESSAGE_LIMIT),
            "😀".repeat(MESSAGE_LIMIT),
            "<&".repeat(MESSAGE_LIMIT),
        ] {
            let mut document = Document::default();
            document.open(Format::Pre);
            document.text(&text);
            document.close();
            let messages = split(document.tokens, MESSAGE_LIMIT);
            assert_valid(&messages);
            assert!(
                messages
                    .iter()
                    .all(|message| message.starts_with("<pre>") && message.ends_with("</pre>"))
            );
            assert_eq!(
                messages
                    .iter()
                    .map(|message| plain(message))
                    .collect::<String>(),
                text
            );
        }
    }

    #[test]
    fn cw_spoiler_does_not_leak_at_exact_chunk_boundary() {
        let body = "secret".repeat(682);
        let mut event = job(Some(&body), None);
        event.note.cw = Some("CW".into());
        let rendered = render(&event, None);
        assert_valid(&rendered.messages);
        assert_eq!(visible_len(&rendered.messages[0]), MESSAGE_LIMIT);
        assert!(rendered.messages[0].ends_with("</span>"));
        assert!(!rendered.messages[1].contains("tg-spoiler"));
        assert_eq!(
            rendered
                .messages
                .iter()
                .map(|message| plain(message))
                .collect::<String>(),
            format!("CW\n\n{body}\n\n在联邦宇宙查看")
        );
    }

    #[test]
    fn cw_hides_all_body_chunks_but_not_warning_or_source() {
        let body = "secret😀&".repeat(1500);
        let mut event = job(Some(&body), None);
        event.note.cw = Some("**Warning**".into());
        let rendered = render(&event, None);
        assert_valid(&rendered.messages);
        assert!(rendered.messages.len() > 2);
        for message in &rendered.messages {
            if plain(message).contains("secret") {
                assert!(message.contains("<span class=\"tg-spoiler\">"));
            }
        }
        assert!(rendered.messages[1].starts_with("<span class=\"tg-spoiler\">"));
        let last = rendered.messages.last().unwrap();
        assert!(last.find("</span>").unwrap() < last.find("在联邦宇宙查看").unwrap());
        let text = rendered
            .messages
            .iter()
            .map(|message| plain(message))
            .collect::<String>();
        assert_eq!(text, format!("Warning\n\n{body}\n\n在联邦宇宙查看"));

        event.note.cw = Some(String::new());
        event.note.text = Some("`secret`\n\n```\nhidden\n```".into());
        let rendered = render(&event, None);
        assert_valid(&rendered.messages);
        assert!(rendered.messages[0].contains("tg-spoiler"));
        assert!(
            !rendered.messages[0].contains("<code>") && !rendered.messages[0].contains("<pre>")
        );
    }

    #[test]
    fn cw_disables_previews_of_hidden_body_and_renote_urls() {
        for text in [None, Some("[hidden](https://example.org/secret)")] {
            for renote in [None, Some("hidden-original")] {
                for reply_id in [None, Some(42)] {
                    for warning in ["", "Warning https://example.org/warning"] {
                        let mut event = job(text, renote);
                        event.note.cw = Some(warning.into());
                        let rendered = render(&event, reply_id);
                        assert_valid(&rendered.messages);
                        assert!(rendered.preview_url.is_none());
                        if text.is_some() || renote.is_some() {
                            assert!(rendered.messages.join("").contains("tg-spoiler"));
                        }
                    }
                }
            }
        }
    }

    #[test]
    fn forward_and_quote_use_mapping_and_preview_correctly() {
        let forward = job(None, Some("original"));
        let mapped = render(&forward, Some(42));
        let unmapped = render(&forward, None);
        assert_valid(&mapped.messages);
        assert_valid(&unmapped.messages);
        assert!(!mapped.messages.join("").contains("/notes/original"));
        assert!(mapped.preview_url.is_none());
        assert!(unmapped.messages.join("").contains("/notes/original"));
        assert_eq!(unmapped.preview_url, Some(forward.note_url("original")));
        assert!(mapped.messages.join("").contains("/notes/source"));

        let quote = job(
            Some("comment [link](https://example.org/first) https://example.org/second"),
            Some("original"),
        );
        let mapped = render(&quote, Some(42));
        let unmapped = render(&quote, None);
        assert_valid(&mapped.messages);
        assert_valid(&unmapped.messages);
        assert!(plain(&mapped.messages.join("")).contains("comment"));
        assert!(!mapped.messages.join("").contains("/notes/original"));
        assert!(unmapped.messages.join("").contains("/notes/original"));
        assert_eq!(
            mapped.preview_url.unwrap().as_str(),
            "https://example.org/first"
        );
        assert_eq!(unmapped.preview_url, Some(quote.note_url("original")));
    }

    #[test]
    fn preview_uses_first_http_url_and_empty_posts_have_a_source() {
        let event = job(
            Some("[user](tg://user?id=1) https://example.org/Foo_(bar). https://example.org/later"),
            None,
        );
        let rendered = render(&event, None);
        assert_valid(&rendered.messages);
        assert_eq!(
            rendered.preview_url.unwrap().as_str(),
            "https://example.org/Foo_(bar)"
        );
        for (text, expected) in [
            (
                "https://example.org/Foo_(bar) [later](https://example.org/later)",
                "https://example.org/Foo_(bar)",
            ),
            (
                "[first](https://example.org/first) https://example.org/Foo_(bar)",
                "https://example.org/first",
            ),
            (
                "[first][reference] https://example.org/Foo_(bar)\n\n[reference]: https://example.org/from-reference",
                "https://example.org/from-reference",
            ),
        ] {
            let rendered = render(&job(Some(text), None), None);
            assert_valid(&rendered.messages);
            assert_eq!(rendered.preview_url.unwrap().as_str(), expected);
        }
        for text in [None, Some(""), Some("   ")] {
            let rendered = render(&job(text, None), None);
            assert_valid(&rendered.messages);
            assert!(
                rendered
                    .messages
                    .join("")
                    .contains("href=\"https://misskey.example/notes/source\"")
            );
        }
    }
}
