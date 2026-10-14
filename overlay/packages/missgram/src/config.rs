use anyhow::{Context, ensure};
use serde::Deserialize;
use std::{fs, path::Path};

#[derive(Deserialize)]
pub struct Config {
    pub secret: String,
    pub telegram_bot_token: String,
    pub telegram_chat_id: i64,
    pub server_port: u16,
    pub db_password: String,
    #[serde(default = "default_queue_capacity")]
    pub queue_capacity: usize,
    #[serde(default = "default_workers")]
    pub workers: usize,
    #[serde(default = "default_shutdown_timeout")]
    pub shutdown_timeout_secs: u64,
}

fn default_queue_capacity() -> usize {
    128
}
fn default_workers() -> usize {
    4
}
fn default_shutdown_timeout() -> u64 {
    30
}

impl Config {
    pub fn load(path: &Path) -> anyhow::Result<Self> {
        let text = fs::read_to_string(path).context("Reading configuration")?;
        let config: Self = serde_yaml::from_str(&text)
            .map_err(|_| anyhow::anyhow!("Invalid YAML/JSON configuration"))?;
        config.validate()?;
        Ok(config)
    }

    fn validate(&self) -> anyhow::Result<()> {
        ensure!(
            !self.secret.trim().is_empty(),
            "Webhook secret must not be empty"
        );
        ensure!(
            !self.telegram_bot_token.trim().is_empty(),
            "Telegram bot token must not be empty"
        );
        ensure!(
            self.telegram_chat_id != 0,
            "Telegram chat ID must not be zero"
        );
        ensure!(self.server_port != 0, "Server port must not be zero");
        ensure!(self.queue_capacity > 0, "Queue capacity must be positive");
        ensure!(self.workers > 0, "Worker count must be positive");
        ensure!(
            self.shutdown_timeout_secs > 0,
            "Shutdown timeout must be positive"
        );
        Ok(())
    }
}
