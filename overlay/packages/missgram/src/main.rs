mod config;
mod db;
mod forwarder;
mod misskey;
mod render;
mod telegram;
mod webhook;

use anyhow::Context;
use clap::Parser;
use config::Config;
use forwarder::{Forwarder, Workers};
use std::{future::IntoFuture, net::SocketAddr, path::PathBuf, time::Duration};
use tracing::info;
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(version, about = "Misskey to Telegram forwarder bot")]
struct Args {
    #[arg(short, long, default_value = "config.yaml")]
    config: PathBuf,
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
    let config = Config::load(&Args::parse().config)?;
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .context("Installing SIGTERM handler")?;
    let pool = db::create_pool(&config.db_password).await?;
    let telegram = telegram::Telegram::new(&config.telegram_bot_token, config.telegram_chat_id)?;
    let addr = SocketAddr::from(([0, 0, 0, 0], config.server_port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .context("Binding Webhook listener")?;
    let (sender, workers) = Workers::start(
        Forwarder::new(pool.clone(), telegram),
        config.queue_capacity,
        config.workers,
    );
    let app = webhook::router(config.secret, sender);
    let timeout = Duration::from_secs(config.shutdown_timeout_secs);
    info!(%addr, workers = config.workers, queue_capacity = config.queue_capacity, "Listening for Misskey webhooks");
    let (stop, stopped) = tokio::sync::oneshot::channel::<()>();
    let deadline;
    let server_result = {
        let server = axum::serve(listener, app)
            .with_graceful_shutdown(async {
                let _ = stopped.await;
            })
            .into_future();
        tokio::pin!(server);
        tokio::select! {
            result = &mut server => { deadline = tokio::time::Instant::now() + timeout; result.context("Serving webhooks") }
            signal = async {
                tokio::select! {
                    result = tokio::signal::ctrl_c() => result.context("Receiving SIGINT"),
                    _ = terminate.recv() => Ok(()),
                }
            } => {
                deadline = tokio::time::Instant::now() + timeout;
                info!("Stopping HTTP intake and draining queued jobs");
                let _ = stop.send(());
                match tokio::time::timeout_at(deadline, &mut server).await {
                    Ok(result) => signal.and(result.context("Stopping Webhook server")),
                    Err(_) => Err(anyhow::anyhow!("HTTP shutdown deadline reached")),
                }
            }
        }
    };
    let drain_result = workers
        .drain(deadline.saturating_duration_since(tokio::time::Instant::now()))
        .await;
    pool.close().await;
    server_result?;
    drain_result?;
    info!("All forwarding jobs completed; exiting");
    Ok(())
}
