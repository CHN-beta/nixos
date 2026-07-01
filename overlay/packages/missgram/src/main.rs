use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    routing::post,
    Json, Router,
};
use pulldown-cmark::{html, Options, Parser};
use regex::Regex;
use serde::Deserialize;
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::{net::SocketAddr, sync::Arc};
use teloxide::{
    payloads::SendMessageSetters,
    requests::{Requester, ResponseResult},
    types::{ChatId, InputFile, MessageId, ParseMode},
    Bot,
};
use tracing::{error, info};

/// Config 结构体，用于反序列化 config.yaml
/// 类型是 Deserialize，允许从 yaml 解析
#[derive(Deserialize, Clone)]
struct Config {
    // Secret 用于验证 misskey 的 webhook
    #[serde(rename = "Secret")]
    secret: String,
    // Telegram 机器人的 Token
    #[serde(rename = "TelegramBotToken")]
    telegram_bot_token: String,
    // 要发送到的 Telegram Chat ID
    #[serde(rename = "TelegramChatId")]
    telegram_chat_id: i64,
    // 服务器监听端口
    #[serde(rename = "ServerPort")]
    server_port: u16,
    // 数据库密码
    #[serde(rename = "dbPassword")]
    db_password: String,
}

/// 程序的共享状态，类型是 Arc，用于在多个请求之间共享
struct AppState {
    // 解析后的配置，类型是 Config
    config: Config,
    // Telegram Bot 客户端，类型是 teloxide::Bot
    bot: Bot,
    // 数据库连接池，类型是 sqlx::PgPool
    db_pool: PgPool,
}

/// Misskey 传来的文件信息
#[derive(Deserialize, Clone)]
struct File {
    name: String,
    url: String,
    #[serde(rename = "type")]
    file_type: String,
    #[serde(rename = "isSensitive")]
    is_sensitive: bool,
}

/// Misskey webhook 的顶层载荷
#[derive(Deserialize, Clone)]
struct MisskeyPayload {
    #[serde(rename = "type")]
    hook_type: String,
    server: String,
    body: MisskeyBody,
}

#[derive(Deserialize, Clone)]
struct MisskeyBody {
    note: Option<MisskeyNote>,
}

#[derive(Deserialize, Clone)]
struct MisskeyNote {
    id: String,
    visibility: String,
    text: Option<String>,
    #[serde(rename = "replyId")]
    reply_id: Option<String>,
    cw: Option<String>,
    renote: Option<Renote>,
    #[serde(rename = "localOnly")]
    local_only: bool,
    files: Vec<File>,
}

#[derive(Deserialize, Clone)]
struct Renote {
    id: String,
}

#[tokio::main]
async fn main() {
    // 初始化日志系统，无变量返回
    tracing_subscriber::fmt::init();

    // 读取 config.yaml 文件内容，类型是 String
    let config_str: String = std::fs::read_to_string("config.yaml")
        .expect("Failed to read config.yaml");
    
    // 将 yaml 字符串反序列化为 Config 结构体
    let config: Config = serde_yaml::from_str(&config_str)
        .expect("Failed to parse config.yaml");

    // 创建数据库连接字符串，类型是 String
    let db_url: String = format!(
        "postgres://missgram:{}@127.0.0.1/missgram",
        config.db_password
    );

    // 连接数据库，返回连接池，类型是 sqlx::PgPool
    let db_pool: PgPool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
        .expect("Failed to connect to db");

    // 如果表不存在，创建一个新表
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS missgram_record (
            misskey_note TEXT PRIMARY KEY,
            telegram_message_id INTEGER NOT NULL
        )",
    )
    .execute(&db_pool)
    .await
    .expect("Failed to create table");

    // 创建 Telegram Bot 客户端，类型是 teloxide::Bot
    let bot: Bot = Bot::new(config.telegram_bot_token.clone());

    // 创建共享状态，使用 Arc 包裹以跨线程共享
    let state: Arc<AppState> = Arc::new(AppState {
        config: config.clone(),
        bot,
        db_pool,
    });

    // 创建路由，绑定 / 路径到处理函数 handle_webhook
    let app: Router = Router::new()
        .route("/", post(handle_webhook))
        .with_state(state);

    // 绑定监听地址，类型是 SocketAddr
    let addr: SocketAddr = SocketAddr::from(([0, 0, 0, 0], config.server_port));
    info!("Listening on {}", addr);
    
    // 启动 HTTP 服务
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

/// 处理 Misskey webhook 的函数
async fn handle_webhook(
    State(state): State<Arc<AppState>>, // 提取共享状态，类型是 Arc<AppState>
    headers: HeaderMap,                 // 提取 HTTP 头，类型是 HeaderMap
    Json(payload): Json<MisskeyPayload>,// 提取并解析 JSON 请求体，类型是 MisskeyPayload
) -> Result<StatusCode, (StatusCode, String)> {
    
    // 获取 webhook 签名头部，类型是 Option<&HeaderValue>
    let secret_header = headers.get("x-misskey-hook-secret");
    
    // 验证签名是否匹配，类型是 bool
    let is_valid_secret: bool = match secret_header {
        Some(val) => val.to_str().unwrap_or("") == state.config.secret,
        None => false,
    };

    if !is_valid_secret {
        return Err((StatusCode::UNAUTHORIZED, "Invalid secret".into()));
    }

    // 过滤掉不符合要求的请求
    if payload.hook_type != "note" {
        return Ok(StatusCode::OK);
    }
    
    // 提取 note 结构，类型是 &MisskeyNote
    let note: &MisskeyNote = match &payload.body.note {
        Some(n) => n,
        None => return Ok(StatusCode::OK),
    };

    if note.visibility != "public" || note.local_only || note.reply_id.is_some() {
        return Ok(StatusCode::OK);
    }

    // 启动后台任务处理发送逻辑，避免阻塞 HTTP 响应
    // 这里的 tokio::spawn 会创建一个新的异步任务
    tokio::spawn(async move {
        process_note(state, payload.server, note.clone()).await;
    });

    // 返回 200 OK，类型是 StatusCode
    Ok(StatusCode::OK)
}

/// 实际处理 Note 并发送到 Telegram 的函数
async fn process_note(state: Arc<AppState>, server: String, note: MisskeyNote) {
    // 检查是否是纯转发，类型是 bool
    let is_forward: bool = note.text.is_none() && note.files.is_empty() && note.renote.is_some();
    // 检查是否是引用，类型是 bool
    let is_renote: bool = (note.text.is_some() || !note.files.is_empty()) && note.renote.is_some();

    // 尝试在数据库中查找被引用的帖子对应的 TG 消息 ID，类型是 Option<i32>
    let mut tg_renote_id: Option<i32> = None;
    if is_forward || is_renote {
        if let Some(ref renote) = note.renote {
            let row: Result<(i32,), _> = sqlx::query_as(
                "SELECT telegram_message_id FROM missgram_record WHERE misskey_note = $1",
            )
            .bind(&renote.id)
            .fetch_one(&state.db_pool)
            .await;
            
            if let Ok((id,)) = row {
                tg_renote_id = Some(id);
            }
        }
    }

    // 准备要发送的 HTML 文本，类型是 String
    let mut text_html: String = String::new();
    
    if is_forward {
        if tg_renote_id.is_some() {
            text_html = "转发了自己的帖子。".to_string();
        } else {
            text_html = parse_md(&format!("转发了[帖子]({}/notes/{})", server, note.id));
        }
    } else {
        let mut raw_text: String = note.text.clone().unwrap_or_default();
        if is_renote && tg_renote_id.is_none() {
            raw_text = format!("引用了[帖子]({}/notes/{})\n{}", server, note.renote.unwrap().id, raw_text);
        }
        
        text_html = parse_md(&raw_text);
        
        if let Some(cw) = &note.cw {
            if !cw.is_empty() {
                let cw_html: String = parse_md(cw);
                text_html = format!("{}<span class=\"tg-spoiler\">{}</span>", cw_html, text_html);
            }
        }
        text_html.push_str(&parse_md(&format!("\n[在联邦宇宙查看]({}/notes/{})", server, note.id)));
    }

    // 发送消息到 Telegram
    // 这里使用 teloxide 这个成熟的包替代了原本手写 HTTP 请求的方式
    // teloxide 的 send_message 支持链式调用设置 parse_mode 和 reply_to_message_id
    let mut send_request = state.bot.send_message(ChatId(state.config.telegram_chat_id), &text_html)
        .parse_mode(ParseMode::Html);
        
    if let Some(reply_id) = tg_renote_id {
        send_request = send_request.reply_to_message_id(MessageId(reply_id));
    }

    // 执行请求，类型是 Result<teloxide::types::Message, _>
    match send_request.await {
        Ok(tg_msg) => {
            // 获取发送成功后的 Message ID，类型是 i32
            let msg_id: i32 = tg_msg.id.0;
            
            // 写入数据库保存映射，避免错误处理阻塞
            let _ = sqlx::query(
                "INSERT INTO missgram_record (misskey_note, telegram_message_id) VALUES ($1, $2)",
            )
            .bind(&note.id)
            .bind(msg_id)
            .execute(&state.db_pool)
            .await;
            
            info!("Successfully sent message {}", msg_id);
        }
        Err(e) => {
            error!("Failed to send telegram message: {}", e);
        }
    }
}

/// 解析 Markdown 到 HTML 的函数
fn parse_md(text: &str) -> String {
    // 设置 Markdown 解析选项，类型是 Options
    let mut options: Options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_TASKLISTS);
    
    // 创建解析器，类型是 Parser
    let parser = Parser::new_ext(text, options);
    
    // 创建用于保存 HTML 结果的字符串，类型是 String
    let mut html_output: String = String::new();
    
    // 使用 pulldown-cmark 成熟的 HTML 生成器
    html::push_html(&mut html_output, parser);
    
    html_output
}
