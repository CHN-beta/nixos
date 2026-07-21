use crate::types::File;
use std::time::Duration;
use teloxide::{
    Bot,
    payloads::{SendDocumentSetters, SendMediaGroupSetters, SendMessageSetters, SendPhotoSetters},
    requests::Requester,
    types::{
        ChatId, InputFile, InputMedia, InputMediaDocument, InputMediaPhoto, LinkPreviewOptions,
        MessageId, ParseMode, ReplyParameters,
    },
};
use tracing::error;

pub async fn send(
    token: &str,
    chat_id: i64,
    text: String,
    reply_id: Option<i32>,
    files: Vec<File>,
    preview_url: Option<String>,
) -> Option<i32> {
    let mut retry_delay = Duration::from_secs(1);
    for _ in 0..5 {
        let result = send_impl(token, chat_id, &text, reply_id, &files, &preview_url).await;
        match result {
            Ok(Some(id)) => return Some(id),
            Ok(None) => return None,
            Err(e) => {
                error!("Error sending to TG: {:?}", e);
                tokio::time::sleep(retry_delay).await;
                retry_delay *= 2;
            }
        }
    }
    None
}

async fn download_file(url: &str) -> reqwest::Result<Vec<u8>> {
    let resp = reqwest::get(url).await?;
    let bytes = resp.bytes().await?;
    Ok(bytes.to_vec())
}

async fn send_impl(
    token: &str,
    chat_id: i64,
    text: &str,
    reply_id: Option<i32>,
    files: &[File],
    preview_url: &Option<String>,
) -> anyhow::Result<Option<i32>> {
    let bot = Bot::new(token);
    let chat = ChatId(chat_id);

    let mut file_contents = Vec::new();
    for file in files {
        let content = download_file(&file.url).await?;
        file_contents.push(content);
    }

    let mut reply_params = None;
    if let Some(rid) = reply_id {
        reply_params = Some(ReplyParameters::new(MessageId(rid)));
    }

    if files.is_empty() {
        let mut req = bot.send_message(chat, text).parse_mode(ParseMode::Html);

        let link_preview = match preview_url {
            Some(url) => LinkPreviewOptions {
                is_disabled: false,
                url: Some(url.to_string()),
                prefer_small_media: false,
                prefer_large_media: false,
                show_above_text: false,
            },
            None => LinkPreviewOptions {
                is_disabled: true,
                url: None,
                prefer_small_media: false,
                prefer_large_media: false,
                show_above_text: false,
            },
        };
        req = req.link_preview_options(link_preview);

        if let Some(rp) = reply_params {
            req = req.reply_parameters(rp);
        }

        let msg = req.await?;
        Ok(Some(msg.id.0))
    } else if files.len() == 1 {
        let is_photo = files[0].file_type.starts_with("image/");
        let input_file =
            InputFile::memory(file_contents[0].clone()).file_name(files[0].name.clone());

        if is_photo {
            let mut req = bot
                .send_photo(chat, input_file)
                .caption(text)
                .parse_mode(ParseMode::Html)
                .has_spoiler(files[0].is_sensitive);

            if let Some(rp) = reply_params {
                req = req.reply_parameters(rp);
            }
            let msg = req.await?;
            Ok(Some(msg.id.0))
        } else {
            let mut req = bot
                .send_document(chat, input_file)
                .caption(text)
                .parse_mode(ParseMode::Html);

            if let Some(rp) = reply_params {
                req = req.reply_parameters(rp);
            }
            let msg = req.await?;
            Ok(Some(msg.id.0))
        }
    } else {
        let all_photo = files.iter().all(|f| f.file_type.starts_with("image/"));

        let mut media_group = Vec::new();
        for (i, file) in files.iter().enumerate() {
            let input_file =
                InputFile::memory(file_contents[i].clone()).file_name(file.name.clone());

            if all_photo {
                let mut photo = InputMediaPhoto::new(input_file);
                if file.is_sensitive {
                    photo.has_spoiler = true;
                }
                if i == 0 {
                    photo.caption = Some(text.to_string());
                    photo.parse_mode = Some(ParseMode::Html);
                }
                media_group.push(InputMedia::Photo(photo));
            } else {
                let mut doc = InputMediaDocument::new(input_file);
                if i == 0 {
                    doc.caption = Some(text.to_string());
                    doc.parse_mode = Some(ParseMode::Html);
                }
                media_group.push(InputMedia::Document(doc));
            }
        }

        let mut req = bot.send_media_group(chat, media_group);
        if let Some(rp) = reply_params {
            req = req.reply_parameters(rp);
        }

        let msgs = req.await?;
        if let Some(first_msg) = msgs.first() {
            Ok(Some(first_msg.id.0))
        } else {
            Ok(None)
        }
    }
}
