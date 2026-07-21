use sqlx::{Pool, Postgres, postgres::PgPoolOptions};

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
) -> Result<(), sqlx::Error> {
    sqlx::query("INSERT INTO \"Record\" (misskey_note, telegram_message_id) VALUES ($1, $2) ON CONFLICT (misskey_note) DO UPDATE SET telegram_message_id = COALESCE(EXCLUDED.telegram_message_id, \"Record\".telegram_message_id)")
        .bind(misskey_note)
        .bind(telegram_message_id)
        .execute(pool) // 直接使用传入的 pool 执行 SQL
        .await?;

    Ok(())
}

// 异步读取函数，同样要求调用方传入连接池引用
pub async fn read(pool: &Pool<Postgres>, misskey_note: &str) -> Result<Option<Option<i32>>, sqlx::Error> {
    use sqlx::Row;

    let result =
        sqlx::query("SELECT telegram_message_id FROM \"Record\" WHERE misskey_note = $1 LIMIT 1")
            .bind(misskey_note)
            .fetch_optional(pool) // 直接使用传入的 pool 查询
            .await?;

    // result: Option<PgRow>
    // 如果找到了记录，返回 Some(Option<i32>)，如果没找到记录，返回 None
    Ok(result.map(|r| r.try_get("telegram_message_id").unwrap_or(None)))
}
