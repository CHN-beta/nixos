use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub secret: String,
    pub telegram_bot_token: String,
    pub telegram_chat_id: i64,
    pub server_port: u16,
    pub db_password: String,
    pub make_webhook_url: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct File {
    pub name: String,
    pub url: String,
    #[serde(rename = "type")]
    pub file_type: String,
    pub is_sensitive: bool,
}

#[derive(Debug, Deserialize)]
pub struct Content {
    #[serde(rename = "type")]
    pub content_type: String,
    pub server: String,
    pub body: Body,
}

#[derive(Debug, Deserialize)]
pub struct Body {
    pub note: Option<Note>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub id: String,
    pub visibility: String,
    pub text: Option<String>,
    pub reply_id: Option<String>,
    pub cw: Option<String>,
    pub renote: Option<Renote>,
    pub local_only: bool,
    #[serde(default)]
    pub files: Vec<File>,
}

#[derive(Debug, Deserialize)]
pub struct Renote {
    pub id: String,
}
