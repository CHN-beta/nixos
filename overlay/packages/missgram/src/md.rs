use pulldown_cmark::{Options, Parser, html};
use regex::Regex;

pub fn parse(text: &str) -> String {
    // Preprocess: add extra newlines except in code blocks
    let mut new_text = String::new();
    let mut in_code_block = false;

    for line in text.split('\n') {
        if line.starts_with("```") {
            in_code_block = !in_code_block;
        }

        if in_code_block {
            new_text.push_str(line);
            new_text.push('\n');
        } else {
            // Note: C++ version added \n\n
            new_text.push_str(line);
            new_text.push_str("\n\n");
        }
    }

    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);

    let parser = Parser::new_ext(&new_text, options);
    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);

    // Regex replace 1: <pre class="cpp"><code>...</code></pre> -> <pre><code class="language-cpp">...</code></pre>
    // Pulldown-cmark outputs <pre><code class="language-cpp">...</code></pre> directly for block codes with a language!
    // So we might not need the first regex for standard pulldown-cmark, but we'll include it just in case if it outputs differently, or we can just skip it since pulldown-cmark handles it properly.
    // Let's implement the second regex: convert <br> and <br/> to \n

    let re_br = Regex::new(r"<br/?> ?").unwrap();
    let text = re_br.replace_all(&html_output, "\n");
    
    // Telegram does not support <p> and </p> tags
    let text = text.replace("<p>", "");
    let text = text.replace("</p>\n", "\n\n").replace("</p>", "\n\n");

    text.trim().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bold_italic() {
        let input = "Hello **world** and *everyone*!";
        let output = parse(input);
        assert_eq!(output, "Hello <strong>world</strong> and <em>everyone</em>!");
    }

    #[test]
    fn test_strikethrough() {
        let input = "This is ~~deleted~~ text.";
        let output = parse(input);
        assert_eq!(output, "This is <del>deleted</del> text.");
    }

    #[test]
    fn test_code_block() {
        let input = "```rust\nfn main() {}\n```";
        let output = parse(input);
        assert_eq!(output, "<pre><code class=\"language-rust\">fn main() {}\n</code></pre>");
    }

    #[test]
    fn test_multiline_and_br() {
        let input = "Line 1\nLine 2";
        let output = parse(input);
        // "Line 1" and "Line 2" separated by \n\n before pulldown-cmark
        assert_eq!(output, "Line 1\n\nLine 2");
    }

    #[test]
    fn test_br_replacement() {
        let input = "Line 1<br>Line 2<br/>Line 3";
        let output = parse(input);
        assert_eq!(output, "Line 1\nLine 2\nLine 3");
    }
}
