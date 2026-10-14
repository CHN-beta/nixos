use std::time::Duration;

use anyhow::{Result, anyhow, bail};
use teloxide::{
    Bot, RequestError,
    payloads::{SendDocumentSetters, SendMediaGroupSetters, SendMessageSetters, SendPhotoSetters},
    requests::{Request, Requester},
    types::{
        ChatId, InputFile, InputMedia, InputMediaDocument, InputMediaPhoto, LinkPreviewOptions,
        MessageId, ParseMode, ReplyParameters,
    },
};

use crate::{misskey::File, render::Rendered};

const PHOTO_LIMIT: usize = 10 * 1024 * 1024;
const DOCUMENT_LIMIT: usize = 50 * 1024 * 1024;
const TOTAL_DOWNLOAD_LIMIT: usize = 200 * 1024 * 1024;
const DOWNLOAD_TIMEOUT: Duration = Duration::from_secs(60);
const RETRY_ATTEMPTS: usize = 3;
const MAX_RETRY_WAIT: Duration = Duration::from_secs(30);

// Retry only the current request after an explicit rejection for flood control.
// send_ref shares InputFile's Bytes; it never re-downloads or copies media buffers.
macro_rules! send_request {
    ($request:expr, $operation:expr) => {{
        let request = $request;
        let mut attempt = 1;
        loop {
            match request.send_ref().await {
                Ok(value) => break Ok(value),
                Err(RequestError::RetryAfter(delay))
                    if attempt < RETRY_ATTEMPTS && delay.duration() <= MAX_RETRY_WAIT =>
                {
                    tokio::time::sleep(delay.duration()).await;
                    attempt += 1;
                }
                Err(error) => break Err(platform_error($operation, error)),
            }
        }
    }};
}

pub struct Telegram {
    bot: Bot,
    http: reqwest::Client,
    chat: ChatId,
}

impl Telegram {
    pub fn new(token: &str, chat_id: i64) -> Result<Self> {
        let http = reqwest::Client::builder()
            .connect_timeout(Duration::from_secs(10))
            .timeout(DOWNLOAD_TIMEOUT)
            .build()
            .map_err(|_| anyhow!("creating attachment HTTP client failed"))?;
        // Teloxide's reusable client has its own connection/request timeouts.
        Ok(Self {
            bot: Bot::new(token),
            http,
            chat: ChatId(chat_id),
        })
    }

    #[cfg(test)]
    pub fn with_api_url(token: &str, chat_id: i64, url: reqwest::Url) -> Result<Self> {
        let mut telegram = Self::new(token, chat_id)?;
        telegram.bot = telegram.bot.set_api_url(url);
        Ok(telegram)
    }

    pub async fn send(
        &self,
        rendered: &Rendered,
        files: &[File],
        reply_id: Option<i32>,
    ) -> Result<i32> {
        if rendered.messages.is_empty()
            || rendered.messages.iter().any(|text| {
                let length = crate::render::visible_len(text);
                length == 0 || length > 4096
            })
        {
            bail!("Telegram text must contain nonempty chunks of at most 4096 UTF-16 units");
        }

        let all_photo = files.iter().all(is_photo);
        // Validate and download everything before sending text or uploading any media.
        let mut inputs = Vec::with_capacity(files.len());
        let mut total = 0;
        for (index, file) in files.iter().enumerate() {
            let photo = is_photo(file) && (all_photo || file.is_sensitive);
            let limit = if photo { PHOTO_LIMIT } else { DOCUMENT_LIMIT };
            let remaining = TOTAL_DOWNLOAD_LIMIT - total;
            let bytes = self.download(file, limit.min(remaining), index + 1).await?;
            total += bytes.len();
            inputs.push(InputFile::memory(bytes).file_name(file.name.clone()));
        }

        let caption = if !files.is_empty()
            && rendered.messages.len() == 1
            && crate::render::visible_len(&rendered.messages[0]) <= 1024
        {
            Some(rendered.messages[0].as_str())
        } else {
            None
        };
        let mut first_id = None;
        if caption.is_none() {
            for (index, text) in rendered.messages.iter().enumerate() {
                let mut request = self
                    .bot
                    .send_message(self.chat, text)
                    .parse_mode(ParseMode::Html);
                request = request.link_preview_options(LinkPreviewOptions {
                    is_disabled: index != 0 || rendered.preview_url.is_none(),
                    url: if index == 0 {
                        rendered.preview_url.as_ref().map(ToString::to_string)
                    } else {
                        None
                    },
                    prefer_small_media: false,
                    prefer_large_media: false,
                    show_above_text: false,
                });
                if let Some(id) = first_id.or(reply_id) {
                    request = request.reply_parameters(ReplyParameters::new(MessageId(id)));
                }
                let message = send_request!(request, "sending text")?;
                first_id.get_or_insert(message.id.0);
            }
        }

        let mut attachments = files.iter().zip(inputs).peekable();
        while let Some((file, input)) = attachments.next() {
            let first_caption = if first_id.is_none() { caption } else { None };
            let reply = first_id.or(reply_id);
            // Telegram document albums cannot carry has_spoiler. Preserve order and
            // sensitivity by isolating sensitive images as spoiler photos in mixed sets.
            let photo = all_photo || (is_photo(file) && file.is_sensitive);
            let mut group = vec![(file, input)];
            if all_photo || !photo {
                while group.len() < 10 {
                    let Some((next_file, _)) = attachments.peek() else {
                        break;
                    };
                    if !all_photo && is_photo(next_file) && next_file.is_sensitive {
                        break;
                    }
                    group.push(attachments.next().expect("peeked attachment exists"));
                }
            }
            let id = if group.len() == 1 {
                let (file, input) = group.pop().expect("nonempty attachment group");
                self.send_single(file, input, photo, first_caption, reply)
                    .await?
            } else {
                let mut media = Vec::with_capacity(group.len());
                for (index, (file, input)) in group.into_iter().enumerate() {
                    let caption = if index == 0 {
                        first_caption.map(str::to_owned)
                    } else {
                        None
                    };
                    if all_photo {
                        let mut item = InputMediaPhoto::new(input);
                        item.has_spoiler = file.is_sensitive;
                        item.caption = caption;
                        item.parse_mode = Some(ParseMode::Html);
                        media.push(InputMedia::Photo(item));
                    } else {
                        let mut item = InputMediaDocument::new(input);
                        item.caption = caption;
                        item.parse_mode = Some(ParseMode::Html);
                        media.push(InputMedia::Document(item));
                    }
                }
                let mut request = self.bot.send_media_group(self.chat, media);
                if let Some(id) = reply {
                    request = request.reply_parameters(ReplyParameters::new(MessageId(id)));
                }
                let messages = send_request!(request, "sending media group")?;
                messages
                    .first()
                    .ok_or_else(|| anyhow!("Telegram returned an empty media group"))?
                    .id
                    .0
            };
            first_id.get_or_insert(id);
        }
        first_id.ok_or_else(|| anyhow!("Telegram operation did not send a message"))
    }

    async fn download(&self, file: &File, limit: usize, index: usize) -> Result<Vec<u8>> {
        if limit == 0 {
            bail!("attachment {index}: total download size limit exceeded");
        }
        let mut response = self
            .http
            .get(&file.url)
            .send()
            .await
            .map_err(|error| download_error(index, "request", &error))?;
        if !response.status().is_success() {
            bail!(
                "attachment {index}: download returned HTTP {}",
                response.status().as_u16()
            );
        }
        if response
            .content_length()
            .is_some_and(|size| size > limit as u64)
        {
            bail!("attachment {index}: download exceeds {limit} byte limit");
        }
        let capacity = response.content_length().unwrap_or(0).min(limit as u64) as usize;
        let mut bytes = Vec::with_capacity(capacity);
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|error| download_error(index, "body", &error))?
        {
            if chunk.len() > limit - bytes.len() {
                bail!("attachment {index}: download exceeds {limit} byte limit");
            }
            bytes.extend_from_slice(&chunk);
        }
        if bytes.is_empty() {
            bail!("attachment {index}: download returned an empty file");
        }
        // Vec ownership passes into InputFile/Bytes without another byte-buffer copy.
        Ok(bytes)
    }

    async fn send_single(
        &self,
        file: &File,
        input: InputFile,
        photo: bool,
        caption: Option<&str>,
        reply_id: Option<i32>,
    ) -> Result<i32> {
        if photo {
            let mut request = self
                .bot
                .send_photo(self.chat, input)
                .has_spoiler(file.is_sensitive);
            if let Some(caption) = caption {
                request = request.caption(caption).parse_mode(ParseMode::Html);
            }
            if let Some(id) = reply_id {
                request = request.reply_parameters(ReplyParameters::new(MessageId(id)));
            }
            Ok(send_request!(request, "sending photo")?.id.0)
        } else {
            let mut request = self.bot.send_document(self.chat, input);
            if let Some(caption) = caption {
                request = request.caption(caption).parse_mode(ParseMode::Html);
            }
            if let Some(id) = reply_id {
                request = request.reply_parameters(ReplyParameters::new(MessageId(id)));
            }
            Ok(send_request!(request, "sending document")?.id.0)
        }
    }
}

fn is_photo(file: &File) -> bool {
    file.file_type.starts_with("image/")
}

fn download_error(index: usize, stage: &str, error: &reqwest::Error) -> anyhow::Error {
    let reason = if error.is_timeout() {
        "timed out"
    } else {
        "failed"
    };
    // Never expose signed attachment URLs, response bodies, or client source errors.
    anyhow!("attachment {index}: download {stage} {reason}")
}

fn platform_error(operation: &str, error: RequestError) -> anyhow::Error {
    let reason = match error {
        RequestError::RetryAfter(_) => "flood-control retry limit exceeded",
        RequestError::Api(_) => "API rejected request",
        RequestError::MigrateToChatId(_) => "chat migration required",
        RequestError::Network(_) => "network send failed; delivery is unknown and was not retried",
        RequestError::InvalidJson { .. } => {
            "invalid response; delivery is unknown and was not retried"
        }
        RequestError::Io(_) => "upload I/O failed",
    };
    // Teloxide network errors include the Bot API URL (and token), so do not chain them.
    anyhow!("Telegram {operation}: {reason}")
}

#[cfg(test)]
mod tests {
    use std::{collections::VecDeque, sync::Arc};

    use axum::{
        Router,
        body::{Body, to_bytes},
        extract::{Request, State},
        http::StatusCode,
        response::{IntoResponse, Response},
    };
    use serde_json::{Value, json};
    use tokio::sync::Mutex;

    use super::*;

    #[derive(Clone, Debug)]
    struct Call {
        method: String,
        fields: Value,
    }

    #[derive(Default)]
    struct FakeState {
        calls: Vec<Call>,
        downloads: usize,
        next_id: i32,
        responses: VecDeque<Value>,
    }

    struct Fake {
        url: reqwest::Url,
        state: Arc<Mutex<FakeState>>,
        task: tokio::task::JoinHandle<()>,
    }

    impl Drop for Fake {
        fn drop(&mut self) {
            self.task.abort();
        }
    }

    impl Fake {
        async fn start() -> Self {
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let url = format!("http://{}/", listener.local_addr().unwrap())
                .parse()
                .unwrap();
            let state = Arc::new(Mutex::new(FakeState {
                next_id: 100,
                ..Default::default()
            }));
            let app = Router::new().fallback(endpoint).with_state(state.clone());
            let task = tokio::spawn(async move {
                axum::serve(listener, app).await.unwrap();
            });
            Self { url, state, task }
        }

        fn telegram(&self) -> Telegram {
            Telegram::with_api_url("local-test-token", -123, self.url.clone()).unwrap()
        }

        fn files(&self, count: usize, kind: &str) -> Vec<File> {
            (0..count)
                .map(|index| File {
                    name: format!("file-{index}"),
                    url: self.url.join("file").unwrap().to_string(),
                    file_type: kind.into(),
                    is_sensitive: index == 0,
                })
                .collect()
        }

        async fn calls(&self) -> Vec<Call> {
            self.state.lock().await.calls.clone()
        }
    }

    async fn endpoint(State(state): State<Arc<Mutex<FakeState>>>, request: Request) -> Response {
        let path = request.uri().path().to_owned();
        if !path.contains("botlocal-test-token/") {
            state.lock().await.downloads += 1;
            return match path.as_str() {
                "/file" => "test-file".into_response(),
                "/empty" => "".into_response(),
                "/oversized" => Body::from(vec![b'x'; PHOTO_LIMIT + 1]).into_response(),
                "/slow" => {
                    tokio::time::sleep(Duration::from_millis(200)).await;
                    "test-file".into_response()
                }
                _ => (StatusCode::NOT_FOUND, "private-download-error").into_response(),
            };
        }
        let method = path.rsplit('/').next().unwrap().to_owned();
        let content_type = request
            .headers()
            .get("content-type")
            .unwrap()
            .to_str()
            .unwrap()
            .to_owned();
        let bytes = to_bytes(request.into_body(), 2 * 1024 * 1024)
            .await
            .unwrap();
        let fields = if content_type.starts_with("application/json") {
            serde_json::from_slice(&bytes).unwrap()
        } else {
            multipart_fields(&content_type, &bytes)
        };
        let mut state = state.lock().await;
        state.calls.push(Call {
            method: method.clone(),
            fields: fields.clone(),
        });
        if let Some(response) = state.responses.pop_front() {
            return axum::Json(response).into_response();
        }
        let count = if method == "SendMediaGroup" || method == "sendMediaGroup" {
            fields["media"].as_array().unwrap().len()
        } else {
            1
        };
        let messages: Vec<_> = (0..count).map(|_| {
            let id = state.next_id;
            state.next_id += 1;
            json!({ "message_id": id, "date": 0, "chat": { "id": -123, "type": "supergroup", "title": "local" }, "text": "accepted" })
        }).collect();
        let result = if method.eq_ignore_ascii_case("sendMediaGroup") {
            json!(messages)
        } else {
            messages.into_iter().next().unwrap()
        };
        axum::Json(json!({ "ok": true, "result": result })).into_response()
    }

    fn multipart_fields(content_type: &str, bytes: &[u8]) -> Value {
        let boundary = content_type
            .split("boundary=")
            .nth(1)
            .unwrap()
            .trim_matches('"');
        let body = std::str::from_utf8(bytes).unwrap();
        let mut fields = serde_json::Map::new();
        for part in body.split(&format!("--{boundary}")) {
            let Some((headers, body)) = part.split_once("\r\n\r\n") else {
                continue;
            };
            let Some(name) = headers
                .split("name=\"")
                .nth(1)
                .and_then(|rest| rest.split('"').next())
            else {
                continue;
            };
            let body = body.strip_suffix("\r\n").unwrap_or(body);
            fields.insert(
                name.to_owned(),
                serde_json::from_str(body).unwrap_or_else(|_| json!(body)),
            );
        }
        Value::Object(fields)
    }

    fn rendered(messages: Vec<String>) -> Rendered {
        Rendered {
            messages,
            preview_url: None,
        }
    }

    fn reply(call: &Call) -> Option<i64> {
        call.fields["reply_parameters"]["message_id"].as_i64()
    }

    #[tokio::test]
    async fn text_chunks_return_first_id_and_reply_to_it() {
        let fake = Fake::start().await;
        let rendered = Rendered {
            messages: vec!["<b>first</b>".into(), "second".into()],
            preview_url: Some("https://example.org/notes/abc".parse().unwrap()),
        };
        let id = fake
            .telegram()
            .send(&rendered, &[], Some(42))
            .await
            .unwrap();
        assert_eq!(id, 100);
        let calls = fake.calls().await;
        assert_eq!(calls.len(), 2);
        assert!(calls[0].method.eq_ignore_ascii_case("sendMessage"));
        assert_eq!(calls[0].fields["parse_mode"], "HTML");
        assert_eq!(reply(&calls[0]), Some(42));
        assert_eq!(reply(&calls[1]), Some(100));
        assert_eq!(
            calls[0].fields["link_preview_options"]["url"],
            "https://example.org/notes/abc"
        );
        assert_eq!(calls[1].fields["link_preview_options"]["is_disabled"], true);
    }

    #[tokio::test]
    async fn photo_albums_are_bounded_with_singleton_remainder_and_one_caption() {
        let fake = Fake::start().await;
        let files = fake.files(21, "image/png");
        assert_eq!(
            fake.telegram()
                .send(&rendered(vec!["caption".into()]), &files, Some(42))
                .await
                .unwrap(),
            100
        );
        let calls = fake.calls().await;
        assert_eq!(calls.len(), 3);
        for call in &calls[..2] {
            assert!(call.method.eq_ignore_ascii_case("sendMediaGroup"));
            let media = call.fields["media"].as_array().unwrap();
            assert_eq!(media.len(), 10);
            assert!(media.iter().all(|item| item["type"] == "photo"));
        }
        assert_eq!(calls[0].fields["media"][0]["caption"], "caption");
        assert_eq!(calls[0].fields["media"][0]["has_spoiler"], true);
        assert!(calls[0].fields["media"][1].get("caption").is_none());
        assert!(calls[1].fields["media"][0].get("caption").is_none());
        assert!(calls[2].method.eq_ignore_ascii_case("sendPhoto"));
        assert!(calls[2].fields.get("caption").is_none());
        assert_eq!(reply(&calls[0]), Some(42));
        assert_eq!(reply(&calls[1]), Some(100));
        assert_eq!(reply(&calls[2]), Some(100));
        assert_eq!(fake.state.lock().await.downloads, 21);
    }

    #[tokio::test]
    async fn mixed_albums_use_documents_and_keep_sensitive_images_as_spoiler_photos() {
        let fake = Fake::start().await;
        let mut files = fake.files(12, "application/pdf");
        files[1].file_type = "image/png".into();
        files[1].is_sensitive = true;
        files[2].file_type = "image/png".into();
        assert_eq!(
            fake.telegram()
                .send(&rendered(vec!["caption".into()]), &files, None)
                .await
                .unwrap(),
            100
        );
        let calls = fake.calls().await;
        assert_eq!(calls.len(), 3);
        assert!(calls[0].method.eq_ignore_ascii_case("sendDocument"));
        assert_eq!(calls[0].fields["caption"], "caption");
        assert!(calls[1].method.eq_ignore_ascii_case("sendPhoto"));
        assert_eq!(calls[1].fields["has_spoiler"], true);
        assert_eq!(reply(&calls[1]), Some(100));
        assert_eq!(calls[2].fields["media"].as_array().unwrap().len(), 10);
        assert!(
            calls[2].fields["media"]
                .as_array()
                .unwrap()
                .iter()
                .all(|item| item["type"] == "document")
        );
        assert_eq!(reply(&calls[2]), Some(100));
    }

    #[tokio::test]
    async fn caption_limit_counts_utf16_and_long_text_precedes_attachments() {
        let fake = Fake::start().await;
        let files = fake.files(1, "image/png");
        let caption = format!("<b>{}</b>", "😀".repeat(512));
        fake.telegram()
            .send(&rendered(vec![caption.clone()]), &files, None)
            .await
            .unwrap();
        assert_eq!(fake.calls().await[0].fields["caption"], caption);
        let long = format!("<b>{}x</b>", "😀".repeat(512));
        fake.telegram()
            .send(&rendered(vec![long.clone()]), &files, None)
            .await
            .unwrap();
        let calls = fake.calls().await;
        assert_eq!(calls.len(), 3);
        assert_eq!(calls[1].fields["text"], long);
        assert!(calls[2].fields.get("caption").is_none());
        assert_eq!(reply(&calls[2]), Some(101));
    }

    #[tokio::test]
    async fn retries_only_rejected_request_without_redownloading_or_replaying_text() {
        let fake = Fake::start().await;
        fake.state.lock().await.responses.extend([
            json!({"ok": true, "result": {"message_id": 90, "date": 0, "chat": {"id": -123, "type": "supergroup", "title": "local"}, "text": "accepted"}}),
            json!({"ok": false, "error_code": 429, "description": "Too Many Requests", "parameters": {"retry_after": 0}}),
        ]);
        let files = fake.files(1, "image/png");
        let text = rendered(vec!["x".repeat(1025)]);
        assert_eq!(fake.telegram().send(&text, &files, None).await.unwrap(), 90);
        let calls = fake.calls().await;
        assert_eq!(calls.len(), 3);
        assert!(calls[0].method.eq_ignore_ascii_case("sendMessage"));
        assert!(
            calls[1..]
                .iter()
                .all(|call| call.method.eq_ignore_ascii_case("sendPhoto"))
        );
        assert_eq!(calls[1].fields, calls[2].fields);
        assert_eq!(fake.state.lock().await.downloads, 1);
    }

    #[tokio::test]
    async fn explicit_flood_control_attempts_and_wait_are_bounded() {
        let fake = Fake::start().await;
        let rejection = json!({"ok": false, "error_code": 429, "description": "Too Many Requests", "parameters": {"retry_after": 0}});
        fake.state
            .lock()
            .await
            .responses
            .extend([rejection.clone(), rejection.clone(), rejection]);
        assert!(
            fake.telegram()
                .send(&rendered(vec!["hello".into()]), &[], None)
                .await
                .is_err()
        );
        assert_eq!(fake.calls().await.len(), RETRY_ATTEMPTS);
        fake.state.lock().await.responses.push_back(json!({"ok": false, "error_code": 429, "description": "Too Many Requests", "parameters": {"retry_after": 31}}));
        assert!(
            fake.telegram()
                .send(&rendered(vec!["hello".into()]), &[], None)
                .await
                .is_err()
        );
        assert_eq!(fake.calls().await.len(), RETRY_ATTEMPTS + 1);
    }

    #[tokio::test]
    async fn permanent_and_ambiguous_failures_are_not_retried_and_do_not_leak_secrets() {
        for response in [
            json!({"ok": false, "error_code": 400, "description": "Bad Request: private-response"}),
            json!({"private-response": "malformed"}),
            json!({"ok": true, "result": []}),
        ] {
            let fake = Fake::start().await;
            fake.state.lock().await.responses.push_back(response);
            let error = fake
                .telegram()
                .send(&rendered(vec!["hello".into()]), &[], None)
                .await
                .unwrap_err();
            assert_eq!(fake.calls().await.len(), 1);
            let error = format!("{error:#}");
            assert!(!error.contains("local-test-token"));
            assert!(!error.contains("private-response"));
        }
    }

    #[tokio::test]
    async fn failed_or_oversized_downloads_prevent_all_platform_sends() {
        for path in ["missing", "oversized", "empty"] {
            let fake = Fake::start().await;
            let mut files = fake.files(2, "image/png");
            files[1].url = fake.url.join(path).unwrap().to_string();
            let error = fake
                .telegram()
                .send(&rendered(vec!["x".repeat(1025)]), &files, None)
                .await
                .unwrap_err();
            assert!(fake.calls().await.is_empty());
            assert_eq!(fake.state.lock().await.downloads, 2);
            let error = format!("{error:#}");
            assert!(error.contains("attachment 2"));
            assert!(!error.contains("http://"));
            assert!(!error.contains("private-download-error"));
        }
    }

    #[tokio::test]
    async fn download_timeout_fails_before_platform_send() {
        let fake = Fake::start().await;
        let mut telegram = fake.telegram();
        telegram.http = reqwest::Client::builder()
            .timeout(Duration::from_millis(20))
            .build()
            .unwrap();
        let mut files = fake.files(1, "image/png");
        files[0].url = fake.url.join("slow").unwrap().to_string();
        let error = telegram
            .send(&rendered(vec!["caption".into()]), &files, None)
            .await
            .unwrap_err();
        assert!(error.to_string().contains("timed out"));
        assert!(fake.calls().await.is_empty());
    }

    #[tokio::test]
    async fn empty_media_group_response_is_an_error() {
        let fake = Fake::start().await;
        fake.state
            .lock()
            .await
            .responses
            .push_back(json!({"ok": true, "result": []}));
        let error = fake
            .telegram()
            .send(
                &rendered(vec!["caption".into()]),
                &fake.files(2, "image/png"),
                None,
            )
            .await
            .unwrap_err();
        assert!(error.to_string().contains("empty media group"));
        assert_eq!(fake.calls().await.len(), 1);
    }

    #[tokio::test]
    async fn unadvertised_download_size_is_bounded_while_streaming() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};

        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/file", listener.local_addr().unwrap());
        let task = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = [0; 2048];
            assert!(socket.read(&mut request).await.unwrap() > 0);
            socket.write_all(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n4\r\nabcd\r\n6\r\nefghij\r\n0\r\n\r\n").await.unwrap();
        });
        let file = File {
            name: "chunked".into(),
            url,
            file_type: "image/png".into(),
            is_sensitive: false,
        };
        let error = Telegram::new("unused-token", -123)
            .unwrap()
            .download(&file, 8, 1)
            .await
            .unwrap_err();
        assert!(error.to_string().contains("exceeds 8 byte limit"));
        task.await.unwrap();
    }

    #[tokio::test]
    async fn disconnected_platform_send_is_not_retried() {
        use tokio::io::AsyncReadExt;

        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/", listener.local_addr().unwrap())
            .parse()
            .unwrap();
        let task = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = [0; 4096];
            assert!(socket.read(&mut request).await.unwrap() > 0);
            drop(socket);
            // Any second connection would be a replay of an ambiguous send.
            tokio::time::timeout(Duration::from_millis(100), listener.accept())
                .await
                .is_err()
        });
        let telegram = Telegram::with_api_url("local-test-token", -123, url).unwrap();
        let error = telegram
            .send(&rendered(vec!["hello".into()]), &[], None)
            .await
            .unwrap_err();
        assert!(error.to_string().contains("network send failed"));
        assert!(!error.to_string().contains("local-test-token"));
        assert!(task.await.unwrap());
    }

    #[tokio::test]
    async fn invalid_text_is_rejected_before_download_or_send() {
        let fake = Fake::start().await;
        for messages in [vec![], vec![String::new()], vec!["x".repeat(4097)]] {
            assert!(
                fake.telegram()
                    .send(&rendered(messages), &fake.files(1, "image/png"), None)
                    .await
                    .is_err()
            );
        }
        assert!(fake.calls().await.is_empty());
        assert_eq!(fake.state.lock().await.downloads, 0);
    }
}
