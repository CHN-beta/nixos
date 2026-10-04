use chrono::Utc;
use sea_orm::{ActiveModelTrait, ConnectionTrait, Set};
use serde_json::Value;

use crate::entity::operation_log;

pub async fn record_log<C>(
    db: &C,
    user_name: &str,
    event: Value,
) -> Result<operation_log::Model, sea_orm::DbErr>
where
    C: ConnectionTrait,
{
    let now = Utc::now().fixed_offset();
    let new_log = operation_log::ActiveModel {
        id: sea_orm::ActiveValue::NotSet,
        user_name: Set(Some(user_name.to_string())),
        created_at: Set(now),
        event: Set(event),
    };

    new_log.insert(db).await
}
