use anyhow::Context;
use sqlx::{
    PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};
use std::time::Duration;

pub async fn create_pool(password: &str) -> anyhow::Result<PgPool> {
    let options = PgConnectOptions::new()
        .host("127.0.0.1")
        .username("missgram")
        .database("missgram")
        .password(password);
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(10))
        .connect_with(options)
        .await
        .context("Connecting to PostgreSQL")?;
    migrate(&pool).await?;
    Ok(pool)
}

pub async fn migrate(pool: &PgPool) -> anyhow::Result<()> {
    sqlx::migrate!("./migrations")
        .run(pool)
        .await
        .context("Migrating PostgreSQL")?;
    Ok(())
}

pub async fn write(pool: &PgPool, note_id: &str, message_id: i32) -> anyhow::Result<()> {
    sqlx::query("INSERT INTO \"Record\" (misskey_note, telegram_message_id) VALUES ($1, $2) ON CONFLICT (misskey_note) DO UPDATE SET telegram_message_id = EXCLUDED.telegram_message_id")
        .bind(note_id).bind(message_id).execute(pool).await.context("Saving Telegram message mapping")?;
    Ok(())
}

pub async fn read(pool: &PgPool, note_id: &str) -> anyhow::Result<Option<i32>> {
    let record: Option<(Option<i32>,)> =
        sqlx::query_as("SELECT telegram_message_id FROM \"Record\" WHERE misskey_note = $1")
            .bind(note_id)
            .fetch_optional(pool)
            .await
            .context("Reading Telegram message mapping")?;
    Ok(record.and_then(|row| row.0))
}
