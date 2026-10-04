use axum::{extract::State, Json};
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::{
    auth::{create_token, verify_password, CurrentUser},
    entity::user,
    error::AppError,
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub username: String,
}

pub async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, AppError> {
    let user_model = user::Entity::find()
        .filter(user::Column::Username.eq(&payload.username))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::AuthError("用户名或密码错误".to_string()))?;

    if !verify_password(&payload.password, &user_model.password_hash) {
        return Err(AppError::AuthError("用户名或密码错误".to_string()));
    }

    let token = create_token(&user_model.username, &state.config.jwt_secret)?;

    Ok(Json(LoginResponse {
        token,
        username: user_model.username,
    }))
}

pub async fn me(
    CurrentUser(username): CurrentUser,
) -> Result<Json<serde_json::Value>, AppError> {
    Ok(Json(json!({
        "username": username,
    })))
}
