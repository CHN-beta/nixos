use sqlx::{Pool, Postgres, postgres::PgPoolOptions};

pub struct RecordIds {
    pub tg_id: Option<i32>,
    pub tw_id: Option<String>,
}

// 异步的创建连接池函数，接受数据库密码作为参数
// 返回值为 Result，成功时直接返回建立好的 Pool<Postgres>，而不是存在全局变量里
pub async fn create_pool(password: &str) -> Result<Pool<Postgres>, sqlx::Error> {
    // 构造 PostgreSQL 的连接字符串
    let database_url = format!("postgres://missgram:{}@127.0.0.1/missgram", password);

    // 使用选项构建器创建一个最大连接数为 5 的连接池，并立刻尝试与数据库建立初始连接
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    // 运行正规的 SQLx Migration 流程
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to run database migrations");

    // 返回初始化好的连接池对象
    Ok(pool)
}

// 异步写入函数，增加了一个参数 `pool: &Pool<Postgres>`，要求调用方把连接池传进来
pub async fn write(
    pool: &Pool<Postgres>,
    misskey_note: &str,
    telegram_message_id: Option<i32>,
    twitter_tweet_id: Option<String>,
) -> Result<(), sqlx::Error> {
    sqlx::query("INSERT INTO \"Record\" (misskey_note, telegram_message_id, twitter_tweet_id) VALUES ($1, $2, $3) ON CONFLICT (misskey_note) DO UPDATE SET telegram_message_id = COALESCE(EXCLUDED.telegram_message_id, \"Record\".telegram_message_id), twitter_tweet_id = COALESCE(EXCLUDED.twitter_tweet_id, \"Record\".twitter_tweet_id)")
        .bind(misskey_note)
        .bind(telegram_message_id)
        .bind(twitter_tweet_id)
        .execute(pool) // 直接使用传入的 pool 执行 SQL
        .await?;

    Ok(())
}

// 异步读取函数，同样要求调用方传入连接池引用
pub async fn read(pool: &Pool<Postgres>, misskey_note: &str) -> Result<Option<RecordIds>, sqlx::Error> {
    use sqlx::Row;

    let result =
        sqlx::query("SELECT telegram_message_id, twitter_tweet_id FROM \"Record\" WHERE misskey_note = $1 LIMIT 1")
            .bind(misskey_note)
            .fetch_optional(pool) // 直接使用传入的 pool 查询
            .await?;

    Ok(result.map(|r| RecordIds {
        tg_id: r.try_get("telegram_message_id").unwrap_or(None),
        tw_id: r.try_get("twitter_tweet_id").unwrap_or(None),
    }))
}
