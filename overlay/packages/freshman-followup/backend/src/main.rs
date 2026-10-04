pub mod audit;
pub mod auth;
pub mod config;
pub mod entity;
pub mod error;
pub mod routes;
pub mod migration;
pub mod state;

use std::net::SocketAddr;
use axum::{
    http::{header, Method},
    routing::{delete, get, post, put},
    Router,
};
use sea_orm::Database;
use sea_orm_migration::MigratorTrait;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use crate::{
    config::Config,
    routes::{auth as auth_routes, schedule as schedule_routes, student as student_routes},
    migration::Migrator,
    state::AppState,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "freshman_followup=debug,tower_http=debug,axum=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config_path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "config.yaml".to_string());
    tracing::info!("Loading config from: {}", config_path);
    let config = Config::from_file(&config_path)?;
    tracing::info!("Connecting to database: {}", config.database_url);

    let db = Database::connect(&config.database_url).await?;
    tracing::info!("Connected to database successfully");

    tracing::info!("Running database migrations...");
    Migrator::up(&db, None).await?;
    tracing::info!("Database migrations applied successfully");

    let state = AppState::new(db, config.clone());

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE, header::ACCEPT]);

    let api_router = Router::new()
        // 认证
        .route("/auth/login", post(auth_routes::login))
        .route("/auth/me", get(auth_routes::me))
        // 可选日期
        .route("/available-dates", get(schedule_routes::list_available_dates))
        // 老师排班
        .route("/schedules", get(schedule_routes::list_schedules).post(schedule_routes::create_schedule))
        .route("/schedules/{id}", delete(schedule_routes::delete_schedule))
        // 学生与回访
        .route("/colleges", get(student_routes::list_colleges))
        .route("/students", get(student_routes::list_students))
        .route("/students/{id}", get(student_routes::get_student))
        .route("/students/{id}/status", put(student_routes::update_status))
        .route("/students/{id}/remarks", put(student_routes::update_remarks));

    let app = Router::new()
        .nest("/api", api_router)
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = SocketAddr::new(
        config.host.parse().unwrap_or([0, 0, 0, 0].into()),
        config.port,
    );
    tracing::info!("Listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
