use axum::{
    extract::{FromRef, FromRequestParts},
    http::{header, request::Parts},
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

use crate::{error::AppError, state::AppState};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String, // username
    pub exp: usize,
    pub iat: usize,
}

pub fn create_token(username: &str, secret: &str) -> Result<String, AppError> {
    let now = chrono::Utc::now().timestamp() as usize;
    let exp = now + 30 * 24 * 3600; // 30 days (1 month)

    let claims = Claims {
        sub: username.to_string(),
        exp,
        iat: now,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(format!("生成令牌失败: {}", e)))
}

pub fn verify_token(token: &str, secret: &str) -> Result<Claims, AppError> {
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| AppError::AuthError("无效或已过期的令牌".to_string()))?;

    Ok(token_data.claims)
}

pub fn verify_password(password: &str, hash: &str) -> bool {
    bcrypt::verify(password, hash).unwrap_or(false)
}

pub fn hash_password(password: &str) -> Result<String, AppError> {
    bcrypt::hash(password, 10).map_err(|e| AppError::Internal(format!("密码哈希失败: {}", e)))
}

#[derive(Debug, Clone)]
pub struct CurrentUser(pub String);

impl<S> FromRequestParts<S> for CurrentUser
where
    S: Send + Sync,
    AppState: FromRef<S>,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AppError::AuthError("未提供认证请求头 (Authorization)".to_string()))?;

        let token = if let Some(stripped) = auth_header.strip_prefix("Bearer ") {
            stripped.trim()
        } else {
            return Err(AppError::AuthError("认证凭据格式错误，应为 Bearer <token>".to_string()));
        };

        let app_state = AppState::from_ref(state);
        let claims = verify_token(token, &app_state.config.jwt_secret)?;

        Ok(CurrentUser(claims.sub))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_password_hash_and_verify() {
        let password = "test_password_123";
        let hash = hash_password(password).expect("hash should succeed");
        assert!(verify_password(password, &hash));
        assert!(!verify_password("wrong_password", &hash));
    }

    #[test]
    fn test_jwt_create_and_verify() {
        let secret = "secret_key_for_testing";
        let username = "assistant_test";
        let token = create_token(username, secret).expect("token creation should succeed");
        let claims = verify_token(&token, secret).expect("token verification should succeed");
        assert_eq!(claims.sub, username);
        assert_eq!(claims.exp - claims.iat, 30 * 24 * 3600);

        let wrong_secret = "wrong_secret_key";
        assert!(verify_token(&token, wrong_secret).is_err());
    }
}
