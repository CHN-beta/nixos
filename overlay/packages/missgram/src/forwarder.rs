use crate::{db, misskey::Job, render, telegram::Telegram};
use sqlx::PgPool;
use std::{sync::Arc, time::Duration};
use tokio::{
    sync::{Mutex, mpsc},
    task::JoinSet,
};
use tracing::{error, info};

pub struct Forwarder {
    pool: PgPool,
    telegram: Telegram,
}

impl Forwarder {
    pub fn new(pool: PgPool, telegram: Telegram) -> Self {
        Self { pool, telegram }
    }

    pub async fn forward(&self, job: &Job) -> anyhow::Result<()> {
        let reply_id = match &job.note.renote {
            Some(renote) => db::read(&self.pool, &renote.id).await?,
            None => None,
        };
        let rendered = render::render(job, reply_id);
        let message_id = self
            .telegram
            .send(&rendered, &job.note.files, reply_id)
            .await?;
        db::write(&self.pool, &job.note.id, message_id).await?;
        info!(note_id = %job.note.id, message_id, "Forwarded to Telegram");
        Ok(())
    }
}

pub struct Workers {
    tasks: JoinSet<()>,
}

impl Workers {
    pub fn start(
        forwarder: Forwarder,
        capacity: usize,
        workers: usize,
    ) -> (mpsc::Sender<Job>, Self) {
        let (sender, receiver) = mpsc::channel::<Job>(capacity);
        let receiver = Arc::new(Mutex::new(receiver));
        let forwarder = Arc::new(forwarder);
        let mut tasks = JoinSet::new();
        for _ in 0..workers {
            let receiver = receiver.clone();
            let forwarder = forwarder.clone();
            tasks.spawn(async move {
                loop {
                    let job = receiver.lock().await.recv().await;
                    let Some(job) = job else { break; };
                    if let Err(error) = forwarder.forward(&job).await {
                        error!(note_id = %job.note.id, error = %format!("{error:#}"), "Telegram forwarding failed");
                    }
                }
            });
        }
        (sender, Self { tasks })
    }

    pub async fn drain(mut self, timeout: Duration) -> anyhow::Result<()> {
        let result = tokio::time::timeout(timeout, async {
            while let Some(result) = self.tasks.join_next().await {
                result?;
            }
            Ok::<_, anyhow::Error>(())
        })
        .await;
        match result {
            Ok(result) => result,
            Err(_) => {
                self.tasks.abort_all();
                while self.tasks.join_next().await.is_some() {}
                anyhow::bail!("Shutdown deadline reached; remaining in-memory jobs discarded")
            }
        }
    }
}
