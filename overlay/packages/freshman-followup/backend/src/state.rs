use std::sync::Arc;
use sea_orm::DatabaseConnection;
use crate::config::Config;

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
    pub config: Arc<Config>,
}

impl AppState {
    pub fn new(db: DatabaseConnection, config: Config) -> Self {
        Self {
            db,
            config: Arc::new(config),
        }
    }
}
