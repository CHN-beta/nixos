mod db;
mod md;
mod tg;
mod tw;
mod types;

use axum::{
    Router,
    extract::State,
    http::{HeaderMap, StatusCode},
    routing::post,
};
use clap::Parser;
use regex::Regex;
use std::{fs, net::SocketAddr, sync::Arc};
use tokio_util::task::TaskTracker;
use tracing::{debug, error, info};
use tracing_subscriber::EnvFilter;
use types::{Config, Content};

#[derive(Parser, Debug)]
#[command(version, about = "Misskey to Telegram forwarder bot")]
struct Args {
    #[arg(short, long, default_value = "config.yaml")]
    config: String,
}

struct AppState {
    config: Config,
    db_pool: sqlx::Pool<sqlx::Postgres>,
    tracker: TaskTracker,
    tw_api: twitter_v2::TwitterApi<twitter_v2::authorization::Oauth1aToken>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .with_ansi(false)
        .without_time()
        .init();

    let state = Arc::new({
        let args = Args::parse();
        let config: Config = serde_yaml::from_str(&fs::read_to_string(&args.config)?)?;
        let db_pool = db::create_pool(&config.db_password).await?;
        
        let tw_auth = twitter_v2::authorization::Oauth1aToken::new(
            config.twitter_api_key.clone(),
            config.twitter_api_secret.clone(),
            config.twitter_access_token.clone(),
            config.twitter_access_token_secret.clone(),
        );
        let tw_api = twitter_v2::TwitterApi::new(tw_auth);

        AppState {
            config,
            db_pool,
            tracker: TaskTracker::new(),
            tw_api,
        }
    });
    let tracker = state.tracker.clone();

    let addr = SocketAddr::from(([0, 0, 0, 0], state.config.server_port));
    let listener = tokio::net::TcpListener::bind(addr).await?;
    let app = Router::new()
        .route("/", post(handle_webhook))
        .with_state(state);
    info!("Listening on {}", addr);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    info!("Axum server has stopped. Waiting for background tasks to finish...");

    tracker.close();
    tracker.wait().await;
    info!("All background tasks have completed gracefully. Exiting.");
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("Failed to install SIGTERM handler")
            .recv()
            .await;
    };

    // 同时等待两个信号。只要其中任何一个被触发，就立刻返回以执行外层的优雅停机。
    tokio::select! {
        _ = ctrl_c => {
            info!("Received Ctrl+C (SIGINT), starting graceful shutdown...");
        },
        _ = terminate => {
            info!("Received SIGTERM from systemd, starting graceful shutdown...");
        },
    }
}

async fn handle_webhook(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    body: String,
) -> Result<&'static str, StatusCode> {
    let state = state.clone();
    debug!("Received body: {}", body);

    if headers
        .get("x-misskey-hook-secret")
        .and_then(|v| v.to_str().ok())
        != Some(&state.config.secret)
    {
        error!("Invalid secret key");
        return Err(StatusCode::UNAUTHORIZED); // 不一致则返回 401 拒绝访问
    }

    let content: Content = match serde_yaml::from_str(&body) {
        Ok(c) => c,
        Err(e) => {
            error!("Error parsing content: {:?}", e);
            return Err(StatusCode::BAD_REQUEST); // 格式不对返回 400
        }
    };

    if content.content_type != "note" {
        return Ok("OK");
    }
    let note = match content.body.note {
        Some(n) => n,
        None => return Ok("OK"),
    };
    if note.visibility != "public" || note.local_only || note.reply_id.is_some() {
        return Ok("OK");
    }
    // 转发
    let is_forward = note.text.is_none() && note.files.is_empty() && note.renote.is_some();
    // 引用（带文字或者图片）
    let is_renote = (note.text.is_some() || !note.files.is_empty()) && note.renote.is_some();
    
    let db_record = match &note.renote {
        Some(renote) if is_forward || is_renote => db::read(&state.db_pool, &renote.id).await.unwrap_or(None),
        _ => None,
    };
    let tg_renote_id = db_record.as_ref().and_then(|r| r.tg_id);
    let tw_renote_id = db_record.as_ref().and_then(|r| r.tw_id.clone());

    let preview_url = if (is_forward || is_renote) && tg_renote_id.is_none() {
        note.renote
            .as_ref()
            .map(|renote| format!("{}/notes/{}", content.server, renote.id))
    } else if let Some(text) = &note.text {
        let re = Regex::new(r"(https?://[^\s\(\)\[\]\{\}]+)").unwrap();
        re.captures(text).map(|cap| cap[1].to_string())
    } else {
        None
    };

    let mut text_html;
    let mut tw_text; // 为 Twitter 组装的纯文本

    if is_forward {
        text_html = match tg_renote_id {
            Some(_) => "转发了自己的帖子。".to_string(),
            None => md::parse(&format!(
                "转发了[帖子]({}/notes/{}).",
                content.server,
                note.renote.as_ref().unwrap().id
            )),
        };
        tw_text = match tw_renote_id {
            Some(_) => "转发了自己的帖子。".to_string(),
            None => format!(
                "转发了帖子：{}/notes/{}",
                content.server,
                note.renote.as_ref().unwrap().id
            ),
        };
    } else {
        let mut text = note.text.clone().unwrap_or_default();
        let mut tw_base_text = text.clone();

        if is_renote
            && tg_renote_id.is_none()
            && let Some(renote) = &note.renote
        {
            text = format!(
                "引用了[帖子]({}/notes/{})\n\n{}",
                content.server, renote.id, text
            );
        }
        if is_renote
            && tw_renote_id.is_none()
            && let Some(renote) = &note.renote
        {
            tw_base_text = format!(
                "引用了帖子：{}/notes/{}\n{}",
                content.server, renote.id, tw_base_text
            );
        }
        
        text_html = md::parse(&text);

        // 处理 Misskey 的内容折叠/警告 (Content Warning) 特性
        if let Some(cw) = &note.cw
            && !cw.is_empty()
        {
            let cw_html = md::parse(cw);
            text_html = format!("{}<span class=\"tg-spoiler\">{}</span>", cw_html, text_html);
            tw_text = format!("剧透警告：{}\n{}", cw, tw_base_text);
        } else {
            tw_text = tw_base_text;
        }

        text_html += &md::parse(&format!(
            "\n\n[在联邦宇宙查看]({}/notes/{})",
            content.server, note.id
        ));
        
        tw_text.push_str(&format!(
            "\n在联邦宇宙查看：{}/notes/{}",
            content.server, note.id
        ));

        // 对于 Twitter，如果带有文件，将文件的 URL 附在文本末尾
        for file in &note.files {
            tw_text.push_str(&format!("\n{}", file.url));
        }
    }

    let tracker = state.tracker.clone();
    tracker.spawn(async move {
        // 调用我们自己写的 tg 模块发往电报
        let tg_task = tg::send(
            &state.config.telegram_bot_token,
            state.config.telegram_chat_id,
            text_html,
            tg_renote_id,
            note.files,
            preview_url,
        );

        // 发送往 Twitter
        let tw_task = async {
            tw::send_thread(&state.tw_api, &tw_text, tw_renote_id).await.unwrap_or_else(|e| {
                error!("Error sending to Twitter: {:?}", e);
                None
            })
        };

        let (tg_result, tw_result) = tokio::join!(tg_task, tw_task);

        if tg_result.is_none() {
            error!("Failed to send message to Telegram for note ID: {}", note.id);
        }
        if tw_result.is_none() {
            error!("Failed to send message to Twitter for note ID: {}", note.id);
        }

        if tg_result.is_some() || tw_result.is_some() {
            if let Err(e) = db::write(&state.db_pool, &note.id, tg_result, tw_result).await {
                error!("Error writing to DB: {:?}", e);
            }
        } else {
            error!("Both platforms failed for note ID: {}", note.id);
        }
    });

    Ok("OK")
}
