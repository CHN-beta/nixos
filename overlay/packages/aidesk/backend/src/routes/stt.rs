//! `/api/stt` — server-side transcription jobs with claim semantics.

use crate::config::SttConfig;
use crate::routes::{body_json, json_ok, query};
use crate::state::SharedState;
use crate::util::{coded_error, now_ms};
use axum::extract::{Multipart, Path as AxumPath, State};
use axum::http::{StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Value};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{LazyLock, Mutex};

const MAX_STT_AUDIO_BYTES: usize = 25 * 1024 * 1024;
const MAX_STT_REQUEST_BYTES: usize = MAX_STT_AUDIO_BYTES + 1024 * 1024;
const MAX_PENDING_JOBS: usize = 4;
const MAX_LIVE_JOBS: usize = 20;
const OWNER_GRACE_MS: f64 = 15_000.0;
const MAX_SCOPE_LENGTH: usize = 1024;

struct SttJob {
    id: String,
    scope: Option<String>,
    audio: Option<Vec<u8>>,
    audio_type: String,
    file_name: String,
    status: &'static str,
    text: Option<String>,
    error: Option<String>,
    claimed_by: Option<String>,
    owner: Option<String>,
    after: Option<String>,
    done_at: Option<f64>,
    seq: u64,
}

static JOBS: LazyLock<Mutex<Vec<SttJob>>> = LazyLock::new(|| Mutex::new(Vec::new()));
static SEQ: AtomicU64 = AtomicU64::new(0);

fn view(job: &SttJob) -> Value {
    let mut object = serde_json::Map::new();
    object.insert("id".into(), Value::String(job.id.clone()));
    object.insert("status".into(), Value::String(job.status.into()));
    if let Some(error) = &job.error {
        object.insert("error".into(), Value::String(error.clone()));
    }
    Value::Object(object)
}

fn cleanup_expired() {
    if let Ok(mut jobs) = JOBS.lock() {
        let now = now_ms();
        jobs.retain(|job| {
            let expired = match job.status {
                "gone" => job.done_at.map(|at| now - at > 600_000.0).unwrap_or(false),
                "done" | "error" => job
                    .done_at
                    .map(|at| now - at > 3_600_000.0)
                    .unwrap_or(false),
                _ => false,
            };
            !expired
        });
    }
}

fn count_live() -> (usize, usize) {
    let Ok(jobs) = JOBS.lock() else { return (0, 0) };
    let pending = jobs.iter().filter(|job| job.status == "pending").count();
    let live = jobs.iter().filter(|job| job.status != "gone").count();
    (pending, live)
}

fn is_stt_after(value: &str) -> bool {
    matches!(value, "send" | "steer" | "followup")
}

async fn transcribe(
    config: SttConfig,
    job_id: String,
    audio: Vec<u8>,
    file_name: String,
    audio_type: String,
) {
    let client = match reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(290))
        .build()
    {
        Ok(client) => client,
        Err(error) => {
            finish_job(&job_id, Err(error.to_string()));
            return;
        }
    };
    let mut form = reqwest::multipart::Form::new();
    let mime = audio_type
        .split(';')
        .next()
        .unwrap_or("application/octet-stream")
        .trim()
        .to_string();
    let base = reqwest::multipart::Part::bytes(audio).file_name(file_name);
    let part = if mime.parse::<mime::Mime>().is_ok() {
        // Validated with the same parser reqwest uses; a failure here means the
        // transport rejected the upload, so fail the job instead of sending a
        // truncated body.
        match base.mime_str(&mime) {
            Ok(part) => part,
            Err(error) => {
                finish_job(&job_id, Err(error.to_string()));
                return;
            }
        }
    } else {
        base
    };
    form = form.part("file", part);
    if let Some(model) = &config.model {
        form = form.text("model", model.clone());
    }
    let mut request = client.post(&config.endpoint).multipart(form);
    if let Some(key) = &config.api_key {
        request = request.bearer_auth(key);
    }
    let result = match request.send().await {
        Ok(response) => {
            let status = response.status();
            let raw = response.text().await.unwrap_or_default();
            if !status.is_success() {
                let message = parse_upstream_error(&raw, status.as_u16());
                Err(message)
            } else {
                match serde_json::from_str::<Value>(&raw) {
                    Ok(value) => match value.get("text").and_then(Value::as_str) {
                        Some(text) if !text.trim().is_empty() => Ok(text.to_string()),
                        _ => Err("No speech detected".to_string()),
                    },
                    Err(_) => {
                        if raw.trim().is_empty() {
                            Err("No speech detected".to_string())
                        } else {
                            Ok(raw)
                        }
                    }
                }
            }
        }
        Err(error) => {
            let message = if error.is_timeout() {
                "Transcription timed out".to_string()
            } else {
                error.to_string()
            };
            Err(match &config.api_key {
                Some(key) if !key.is_empty() => message.replace(key.as_str(), "[REDACTED]"),
                _ => message,
            })
        }
    };
    finish_job(&job_id, result);
}

fn parse_upstream_error(raw: &str, status: u16) -> String {
    if let Ok(value) = serde_json::from_str::<Value>(raw) {
        if let Some(error) = value.get("error") {
            if let Some(text) = error.as_str() {
                if !text.trim().is_empty() {
                    return text.to_string();
                }
            }
            if let Some(message) = error.get("message").and_then(Value::as_str) {
                if !message.trim().is_empty() {
                    return message.to_string();
                }
            }
        }
    }
    if !raw.trim().is_empty() {
        return raw.trim().chars().take(500).collect();
    }
    format!("Transcription failed (upstream {})", status)
}

fn finish_job(job_id: &str, result: Result<String, String>) {
    if let Ok(mut jobs) = JOBS.lock() {
        if let Some(job) = jobs.iter_mut().find(|job| job.id == job_id) {
            if job.status != "pending" {
                return;
            }
            match result {
                Ok(text) => {
                    job.status = "done";
                    job.text = Some(text);
                    job.error = None;
                    job.done_at = Some(now_ms());
                }
                Err(error) => {
                    job.status = "error";
                    job.error = Some(error);
                    job.done_at = Some(now_ms());
                }
            }
        }
    }
}

fn launch(
    config: SttConfig,
    job_id: String,
    audio: Vec<u8>,
    file_name: String,
    audio_type: String,
) {
    tokio::spawn(async move {
        transcribe(config, job_id, audio, file_name, audio_type).await;
    });
}

pub async fn stt_list(State(_state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let Some(scope) = query
        .get("scope")
        .filter(|scope| !scope.is_empty() && scope.len() <= MAX_SCOPE_LENGTH)
    else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "scope is required",
            "missing_scope",
        );
    };
    cleanup_expired();
    let Ok(jobs) = JOBS.lock() else {
        return json_ok(json!({ "jobs": [] }));
    };
    let mut listed: Vec<(u64, Value)> = jobs
        .iter()
        .filter(|job| job.scope.as_deref() == Some(scope) && job.status != "gone")
        .map(|job| (job.seq, view(job)))
        .collect();
    listed.sort_by(|a, b| b.0.cmp(&a.0));
    let listed: Vec<Value> = listed.into_iter().map(|(_, job)| job).collect();
    json_ok(json!({ "jobs": listed }))
}

pub async fn stt_create(State(state): State<SharedState>, mut multipart: Multipart) -> Response {
    let Some(config) = state.cfg.stt.clone() else {
        return coded_error(
            StatusCode::NOT_IMPLEMENTED,
            "STT not configured. Set OMP_WEB_STT_ENDPOINT.",
            "stt_not_configured",
        );
    };
    let mut audio: Option<(Vec<u8>, String, String)> = None;
    let mut scope: Option<String> = None;
    let mut owner: Option<String> = None;
    let mut after: Option<String> = None;
    let mut total = 0usize;
    loop {
        match multipart.next_field().await {
            Ok(Some(field)) => {
                let name = field.name().unwrap_or("").to_string();
                match name.as_str() {
                    "file" => {
                        let file_name = field.file_name().unwrap_or("audio.webm").to_string();
                        let content_type = field
                            .content_type()
                            .unwrap_or("application/octet-stream")
                            .to_string();
                        let bytes = match field.bytes().await {
                            Ok(bytes) => bytes.to_vec(),
                            Err(_) => {
                                return coded_error(
                                    StatusCode::PAYLOAD_TOO_LARGE,
                                    "Audio file too large (max 25MB)",
                                    "audio_too_large",
                                )
                            }
                        };
                        total += bytes.len();
                        if bytes.len() > MAX_STT_AUDIO_BYTES || total > MAX_STT_REQUEST_BYTES {
                            return coded_error(
                                StatusCode::PAYLOAD_TOO_LARGE,
                                "Audio file too large (max 25MB)",
                                "audio_too_large",
                            );
                        }
                        audio = Some((bytes, file_name, content_type));
                    }
                    "scope" => {
                        if let Ok(text) = field.text().await {
                            if text.len() > MAX_SCOPE_LENGTH {
                                return coded_error(
                                    StatusCode::BAD_REQUEST,
                                    "Invalid scope",
                                    "invalid_scope",
                                );
                            }
                            if !text.is_empty() {
                                scope = Some(text);
                            }
                        }
                    }
                    "owner" => {
                        if let Ok(text) = field.text().await {
                            if !text.is_empty() {
                                owner = Some(text.chars().take(128).collect());
                            }
                        }
                    }
                    "after" => {
                        if let Ok(text) = field.text().await {
                            if !is_stt_after(&text) {
                                return coded_error(
                                    StatusCode::BAD_REQUEST,
                                    "Invalid after",
                                    "invalid_after",
                                );
                            }
                            after = Some(text);
                        }
                    }
                    _ => {}
                }
            }
            Ok(None) => break,
            Err(_) => {
                return coded_error(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    "Audio file too large (max 25MB)",
                    "audio_too_large",
                )
            }
        }
    }
    let Some((bytes, file_name, content_type)) = audio.filter(|(bytes, _, _)| !bytes.is_empty())
    else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Audio file is required",
            "missing_audio_file",
        );
    };
    cleanup_expired();
    let (pending, live) = count_live();
    if pending >= MAX_PENDING_JOBS || live >= MAX_LIVE_JOBS {
        return coded_error(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many transcriptions in progress",
            "stt_busy",
        );
    }
    let job_id = uuid::Uuid::new_v4().to_string();
    let seq = SEQ.fetch_add(1, Ordering::SeqCst);
    {
        let Ok(mut jobs) = JOBS.lock() else {
            return crate::util::api_error(
                "STT store unavailable",
                StatusCode::INTERNAL_SERVER_ERROR,
            );
        };
        jobs.push(SttJob {
            id: job_id.clone(),
            scope,
            audio: Some(bytes.clone()),
            audio_type: content_type.clone(),
            file_name: file_name.clone(),
            status: "pending",
            text: None,
            error: None,
            claimed_by: None,
            owner,
            after,
            done_at: None,
            seq,
        });
    }
    launch(config, job_id.clone(), bytes, file_name, content_type);
    crate::util::json_status(StatusCode::ACCEPTED, json!({ "jobId": job_id }))
}

pub async fn stt_get(AxumPath(job_id): AxumPath<String>) -> Response {
    cleanup_expired();
    let Ok(jobs) = JOBS.lock() else {
        return not_found();
    };
    match jobs.iter().find(|job| job.id == job_id) {
        Some(job) => json_ok(view(job)),
        None => not_found(),
    }
}

pub async fn stt_retry(
    State(state): State<SharedState>,
    AxumPath(job_id): AxumPath<String>,
    uri: Uri,
) -> Response {
    let Some(config) = state.cfg.stt.clone() else {
        return coded_error(
            StatusCode::NOT_IMPLEMENTED,
            "STT not configured. Set OMP_WEB_STT_ENDPOINT.",
            "stt_not_configured",
        );
    };
    let query = query(&uri);
    let owner = query
        .get("owner")
        .map(|owner| owner.chars().take(128).collect::<String>());
    let (pending, _) = count_live();
    let mut to_launch: Option<(Vec<u8>, String, String)> = None;
    let response = {
        let Ok(mut jobs) = JOBS.lock() else {
            return not_found();
        };
        let Some(job) = jobs.iter_mut().find(|job| job.id == job_id) else {
            return not_found();
        };
        if job.status != "error" || job.audio.is_none() {
            Some(view(job))
        } else if pending >= MAX_PENDING_JOBS {
            return coded_error(
                StatusCode::TOO_MANY_REQUESTS,
                "Too many transcriptions in progress",
                "stt_busy",
            );
        } else {
            job.owner = owner;
            job.status = "pending";
            job.error = None;
            job.done_at = None;
            to_launch = job
                .audio
                .clone()
                .map(|audio| (audio, job.file_name.clone(), job.audio_type.clone()));
            Some(view(job))
        }
    };
    if let Some((audio, file_name, audio_type)) = to_launch {
        launch(config, job_id, audio, file_name, audio_type);
    }
    match response {
        Some(view) => json_ok(view),
        None => not_found(),
    }
}

pub async fn stt_close(AxumPath(job_id): AxumPath<String>, uri: Uri) -> Response {
    let query = query(&uri);
    let claim = query
        .get("claim")
        .map(|claim| claim.chars().take(128).collect::<String>());
    let owner = query
        .get("owner")
        .map(|owner| owner.chars().take(128).collect::<String>());
    let Ok(mut jobs) = JOBS.lock() else {
        return not_found();
    };
    let Some(job) = jobs.iter_mut().find(|job| job.id == job_id) else {
        return not_found();
    };
    if job.status == "gone" {
        if let Some(claim) = &claim {
            if job.claimed_by.as_deref() == Some(claim.as_str()) {
                let mut value = view(job);
                if let Some(object) = value.as_object_mut() {
                    object.insert("status".into(), Value::String("done".into()));
                    if let Some(text) = &job.text {
                        object.insert("text".into(), Value::String(text.clone()));
                    }
                    if let Some(after) = &job.after {
                        object.insert("after".into(), Value::String(after.clone()));
                    }
                }
                return json_ok(value);
            }
        }
        return json_ok(view(job));
    }
    if let Some(_claim) = &claim {
        if job.status != "done" {
            return json_ok(view(job));
        }
    }
    let is_owner = job.owner.is_some() && owner.as_deref() == job.owner.as_deref();
    if claim.is_some()
        && job.owner.is_some()
        && !is_owner
        && now_ms() - job.done_at.unwrap_or(0.0) < OWNER_GRACE_MS
    {
        return json_ok(view(job));
    }
    if !is_owner {
        job.after = None;
    }
    let mut before = view(job);
    if let Some(object) = before.as_object_mut() {
        if claim.is_some() {
            if let Some(text) = &job.text {
                object.insert("text".into(), Value::String(text.clone()));
            }
            if let Some(after) = &job.after {
                object.insert("after".into(), Value::String(after.clone()));
            }
        }
    }
    if let Some(claim) = claim {
        job.claimed_by = Some(claim);
    } else {
        job.text = None;
    }
    job.status = "gone";
    job.error = None;
    job.audio = None;
    job.done_at = Some(now_ms());
    json_ok(before)
}

pub async fn stt_audio(AxumPath(job_id): AxumPath<String>) -> Response {
    let Ok(jobs) = JOBS.lock() else {
        return not_found();
    };
    let Some(job) = jobs.iter().find(|job| job.id == job_id) else {
        return not_found();
    };
    let Some(audio) = &job.audio else {
        return not_found();
    };
    let content_type = if job.audio_type.starts_with("audio/") {
        job.audio_type.clone()
    } else {
        "application/octet-stream".to_string()
    };
    Response::builder()
        .status(StatusCode::OK)
        .header("Content-Type", content_type)
        .header("Content-Length", audio.len().to_string())
        .header("Cache-Control", "private, no-store")
        .header("X-Content-Type-Options", "nosniff")
        .body(axum::body::Body::from(audio.clone()))
        .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
}

fn not_found() -> Response {
    coded_error(
        StatusCode::NOT_FOUND,
        "Transcription job not found",
        "stt_job_not_found",
    )
}

#[allow(dead_code)]
fn _unused(_: &Value) -> String {
    String::new()
}

#[allow(dead_code)]
async fn _body_unused(request: axum::extract::Request) -> Response {
    match body_json(request, 1024).await {
        Ok(_) => json_ok(json!({})),
        Err(response) => response,
    }
}
