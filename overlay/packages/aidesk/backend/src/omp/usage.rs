//! Provider usage snapshots.
//!
//! `omp usage --json` is the primary source. Installed omp builds that predate
//! the CLIProxyAPI usage provider would silently drop that account, so a
//! report missing a `cliproxyapi` entry is supplemented by querying the
//! gateway's own `GET /v1/quota` endpoint with the same API key omp uses.

use crate::config::Config;
use serde_json::{json, Map, Value};
use std::path::Path;
use std::sync::Mutex;
use std::time::{Duration, Instant};

const USAGE_CACHE_TTL: Duration = Duration::from_secs(300);
const CLIPROXYAPI_QUOTA_TTL: Duration = Duration::from_secs(120);
const CLIPROXYAPI_TIMEOUT: Duration = Duration::from_secs(8);
const CLIPROXYAPI_PROVIDER: &str = "cliproxyapi";
/// Gateway used when `models.yml` defines no `cliproxyapi` base URL.
const CLIPROXYAPI_DEFAULT_BASE_URL: &str = "https://cliproxyapi.chn.moe/v1";
/// Environment variable (and `models.yml` `apiKey`) holding the gateway key.
const CLIPROXYAPI_KEY_NAME: &str = "CLIPROXYAPI_API_KEY";

static USAGE_CACHE: std::sync::LazyLock<Mutex<Option<(Instant, String)>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

static CLIPROXYAPI_CACHE: std::sync::LazyLock<Mutex<Option<(Instant, Value)>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

fn non_empty_string(value: Option<&Value>) -> Option<String> {
    value
        .and_then(Value::as_str)
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
}

fn as_number(value: Option<&Value>) -> Option<f64> {
    value.and_then(Value::as_f64).filter(|v| v.is_finite())
}

fn normalize_window_id(
    scope: &Map<String, Value>,
    window: &Map<String, Value>,
) -> Option<&'static str> {
    let declared = non_empty_string(scope.get("windowId"))
        .or_else(|| non_empty_string(window.get("id")));
    if let Some(declared) = declared.as_deref() {
        match declared {
            "5h" | "daily" => return Some("5h"),
            "7d" | "weekly" => return Some("7d"),
            "monthly" | "30d" => return Some("monthly"),
            _ => {}
        }
    }
    let duration = as_number(window.get("durationMs"))?;
    let five_hours = 5.0 * 60.0 * 60.0 * 1000.0;
    let day = 24.0 * 60.0 * 60.0 * 1000.0;
    let seven_days = 7.0 * day;
    let thirty_days = 30.0 * day;
    if (duration - five_hours).abs() <= 60_000.0 || (duration - day).abs() <= 60_000.0 {
        Some("5h")
    } else if (duration - seven_days).abs() <= 60_000.0 {
        Some("7d")
    } else if (duration - thirty_days).abs() <= 3_600_000.0 {
        Some("monthly")
    } else {
        None
    }
}

/// A limit is worth reporting when it carries a used fraction or any absolute
/// amount. Keys with an unlimited monthly quota report `used` only, so
/// requiring `usedFraction` would drop them as "no limits".
fn limit_has_amount(amount: &Map<String, Value>) -> bool {
    ["usedFraction", "used", "limit", "remaining"]
        .iter()
        .any(|key| as_number(amount.get(*key)).is_some())
}

/// Percentage used: the provider fraction when present, otherwise derived from
/// `used / limit` for providers that only report absolute amounts.
fn percent_from_amount(amount: &Map<String, Value>) -> Option<f64> {
    if let Some(fraction) = as_number(amount.get("usedFraction")) {
        return Some(fraction * 100.0);
    }
    let used = as_number(amount.get("used"))?;
    let limit = as_number(amount.get("limit"))?;
    if limit > 0.0 {
        Some(used / limit * 100.0)
    } else {
        None
    }
}

fn insert_reset(
    out: &mut Map<String, Value>,
    window_id: &str,
    window: &Map<String, Value>,
    now: f64,
) {
    let Some(resets_at) = as_number(window.get("resetsAt")) else {
        return;
    };
    let remaining = resets_at - now;
    if window_id == "5h" {
        out.insert(
            "resetMinutes".into(),
            Value::from((remaining / 60_000.0).round().max(0.0) as i64),
        );
    } else {
        out.insert(
            "resetHours".into(),
            Value::from((remaining / 3_600_000.0).round().max(0.0) as i64),
        );
    }
}

fn insert_amount(out: &mut Map<String, Value>, amount: &Map<String, Value>) {
    if let Some(percent) = percent_from_amount(amount) {
        out.insert("percent".into(), Value::from(percent));
    }
    for key in ["used", "limit", "remaining"] {
        if let Some(value) = as_number(amount.get(key)) {
            out.insert(key.into(), Value::from(value));
        }
    }
    if let Some(unit) = non_empty_string(amount.get("unit")) {
        out.insert("unit".into(), Value::String(unit));
    }
}

fn limit_label(limit: &Map<String, Value>, window: &Map<String, Value>) -> Option<String> {
    non_empty_string(window.get("label")).or_else(|| non_empty_string(limit.get("label")))
}

fn usage_window(
    window_id: &str,
    limit: &Map<String, Value>,
    window: &Map<String, Value>,
    amount: &Map<String, Value>,
    now: f64,
) -> Value {
    let mut out = Map::new();
    insert_amount(&mut out, amount);
    if let Some(label) = limit_label(limit, window) {
        out.insert("label".into(), Value::String(label));
    }
    insert_reset(&mut out, window_id, window, now);
    Value::Object(out)
}

/// One flat limit entry for the report-wide `limits` array.
fn usage_limit_item(
    window_id: &str,
    limit: &Map<String, Value>,
    window: &Map<String, Value>,
    amount: &Map<String, Value>,
    now: f64,
) -> Value {
    let mut item = Map::new();
    if let Some(id) = non_empty_string(limit.get("id")) {
        item.insert("id".into(), Value::String(id));
    }
    if let Some(label) = limit_label(limit, window) {
        item.insert("label".into(), Value::String(label));
    }
    item.insert("windowId".into(), Value::String(window_id.to_string()));
    insert_amount(&mut item, amount);
    insert_reset(&mut item, window_id, window, now);
    if let Some(status) = non_empty_string(limit.get("status")) {
        item.insert("status".into(), Value::String(status));
    }
    Value::Object(item)
}

#[derive(Default)]
struct UsageGroup {
    priority: u8,
    model_id: Option<String>,
    tier: Option<String>,
    five_hour: Option<Value>,
    seven_day: Option<Value>,
    monthly: Option<Value>,
    fractions: Map<String, Value>,
    limits: Vec<Value>,
}

/// Normalize one raw provider report; mirrors the Next.js implementation.
fn normalize_report(
    raw_report: &Map<String, Value>,
    provider_filter: Option<&str>,
    model_filter: Option<&str>,
    now: f64,
    report_index: usize,
) -> Vec<Value> {
    let Some(provider) = non_empty_string(raw_report.get("provider")) else {
        return Vec::new();
    };
    if provider_filter
        .map(|filter| filter != provider)
        .unwrap_or(false)
    {
        return Vec::new();
    }
    let limits = raw_report
        .get("limits")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let active_model = model_filter.map(|value| value.to_lowercase());
    let mut groups: Vec<(String, UsageGroup)> = Vec::new();

    for raw in limits {
        let Some(limit) = raw.as_object() else {
            continue;
        };
        let (Some(scope), Some(amount)) = (
            limit.get("scope").and_then(Value::as_object),
            limit.get("amount").and_then(Value::as_object),
        ) else {
            continue;
        };
        if !limit_has_amount(amount) {
            continue;
        }
        let window = limit
            .get("window")
            .and_then(Value::as_object)
            .cloned()
            .unwrap_or_default();
        let Some(window_id) = normalize_window_id(scope, &window) else {
            continue;
        };
        let model_id = non_empty_string(scope.get("modelId"));
        if let Some(active) = &active_model {
            if let Some(model_id) = &model_id {
                if &model_id.to_lowercase() != active {
                    continue;
                }
            }
        }
        let tier = non_empty_string(scope.get("tier"));
        let key = format!(
            "{}\u{0}{}",
            model_id.as_deref().unwrap_or("").to_lowercase(),
            tier.as_deref().unwrap_or("").to_lowercase()
        );
        let priority = if model_id.is_some() {
            if tier.is_some() {
                0
            } else {
                1
            }
        } else if tier.is_some() {
            2
        } else {
            3
        };
        let index = match groups.iter().position(|(existing, _)| *existing == key) {
            Some(index) => index,
            None => {
                groups.push((
                    key.clone(),
                    UsageGroup {
                        priority,
                        model_id: model_id.clone(),
                        tier: tier.clone(),
                        ..Default::default()
                    },
                ));
                groups.len() - 1
            }
        };
        let group = &mut groups[index].1;
        let rendered = usage_window(window_id, limit, &window, amount, now);
        // Keep the highest fraction per window (later limits only replace when
        // they report a larger share).
        let candidate_fraction = as_number(amount.get("usedFraction"))
            .or_else(|| percent_from_amount(amount).map(|percent| percent / 100.0))
            .unwrap_or(0.0);
        let current_fraction = group
            .fractions
            .get(window_id)
            .and_then(Value::as_f64)
            .unwrap_or(-1.0);
        if candidate_fraction >= current_fraction {
            let slot = match window_id {
                "5h" => &mut group.five_hour,
                "7d" => &mut group.seven_day,
                _ => &mut group.monthly,
            };
            *slot = Some(rendered);
            group
                .fractions
                .insert(window_id.to_string(), Value::from(candidate_fraction));
        }
        group.limits.push(usage_limit_item(
            window_id, limit, &window, amount, now,
        ));
    }

    if active_model.is_some() && !groups.is_empty() {
        let best = groups
            .iter()
            .enumerate()
            .min_by_key(|(_, (_, group))| group.priority)
            .map(|(index, _)| index)
            .unwrap_or(0);
        let selected = groups.swap_remove(best);
        groups = vec![selected];
    }

    let metadata = raw_report.get("metadata").and_then(Value::as_object);
    let label = ["email", "accountId", "account", "user", "username"]
        .iter()
        .find_map(|key| metadata.and_then(|m| non_empty_string(m.get(*key))))
        .or_else(|| {
            raw_report
                .get("limits")
                .and_then(Value::as_array)?
                .iter()
                .find_map(|limit| {
                    limit
                        .get("scope")
                        .and_then(Value::as_object)
                        .and_then(|scope| non_empty_string(scope.get("accountId")))
                })
        });
    let plan = metadata.and_then(|m| non_empty_string(m.get("planType")));
    if groups.is_empty() {
        let mut report = Map::new();
        report.insert("provider".into(), Value::String(provider));
        if let Some(label) = &label {
            report.insert("accountLabel".into(), Value::String(label.clone()));
        } else {
            report.insert("accountIndex".into(), Value::from(report_index + 1));
        }
        if let Some(plan) = &plan {
            report.insert("plan".into(), Value::String(plan.clone()));
        }
        report.insert("noLimits".into(), Value::Bool(true));
        report.insert("limits".into(), Value::Array(Vec::new()));
        return vec![Value::Object(report)];
    }

    let mut reports = Vec::new();
    for (_, group) in groups {
        if group.five_hour.is_none() && group.seven_day.is_none() && group.monthly.is_none() {
            continue;
        }
        let mut report = Map::new();
        report.insert("provider".into(), Value::String(provider.clone()));
        if let Some(label) = &label {
            report.insert("accountLabel".into(), Value::String(label.clone()));
        } else {
            report.insert("accountIndex".into(), Value::from(report_index + 1));
        }
        if let Some(plan) = &plan {
            report.insert("plan".into(), Value::String(plan.clone()));
        }
        if let Some(model_id) = group.model_id {
            report.insert("modelId".into(), Value::String(model_id));
        }
        if let Some(tier) = group.tier {
            report.insert("tier".into(), Value::String(tier));
        }
        if let Some(value) = group.five_hour {
            report.insert("fiveHour".into(), value);
        }
        if let Some(value) = group.seven_day {
            report.insert("sevenDay".into(), value);
        }
        if let Some(value) = group.monthly {
            report.insert("monthly".into(), value);
        }
        report.insert("limits".into(), Value::Array(group.limits));
        reports.push(Value::Object(report));
    }
    reports
}

pub fn parse_provider_usage_output(
    output: &str,
    provider: Option<&str>,
    model: Option<&str>,
    now: f64,
) -> Result<Value, String> {
    let payload: Value =
        serde_json::from_str(output).map_err(|_| "omp usage returned invalid JSON".to_string())?;
    let object = payload
        .as_object()
        .ok_or_else(|| "omp usage returned an invalid response".to_string())?;
    let raw_reports = object
        .get("reports")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let mut reports = Vec::new();
    for (index, raw) in raw_reports.iter().enumerate() {
        if let Some(raw) = raw.as_object() {
            reports.extend(normalize_report(raw, provider, model, now, index));
        }
    }
    Ok(json!({
        "generatedAt": object.get("generatedAt").and_then(Value::as_f64),
        "reports": reports,
    }))
}

fn run_omp(cfg: &Config, args: &[&str]) -> Result<String, String> {
    let Some(bin) = &cfg.omp_bin else {
        return Err("omp binary not found. Install oh-my-pi or set OMP_WEB_OMP_BIN.".into());
    };
    let output = std::process::Command::new(bin)
        .args(args)
        .env("LC_ALL", "C")
        .output()
        .map_err(|error| error.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_string());
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn load_omp_usage(cfg: &Config, refresh: bool) -> Result<String, String> {
    if !refresh {
        if let Ok(cache) = USAGE_CACHE.lock() {
            if let Some((expires, output)) = cache.as_ref() {
                if *expires > Instant::now() {
                    return Ok(output.clone());
                }
            }
        }
    } else {
        let _ = run_omp(cfg, &["usage", "invalidate"]);
    }
    let output = run_omp(cfg, &["usage", "--json"])?;
    if let Ok(mut cache) = USAGE_CACHE.lock() {
        *cache = Some((Instant::now() + USAGE_CACHE_TTL, output.clone()));
    }
    Ok(output)
}

// ============================================================================
// CLIProxyAPI quota supplement
// ============================================================================

fn env_non_empty(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

/// `providers.cliproxyapi` from `models.yml`, if any.
fn cliproxyapi_provider_config(cfg: &Config) -> Option<Map<String, Value>> {
    let file = crate::omp::models_config::read_models_config_file(cfg);
    file.config
        .get("providers")
        .and_then(Value::as_object)
        .and_then(|providers| providers.get(CLIPROXYAPI_PROVIDER))
        .and_then(Value::as_object)
        .cloned()
}

/// `NAME=VALUE` out of a shell script, with the value left quoted-trimmed.
/// The nix omp wrapper exports secrets with `$(cat /run/secrets/...)`.
fn shell_export_value(script: &str, name: &str) -> Option<String> {
    let mut found = None;
    for line in script.lines() {
        let Some(rest) = line.trim().strip_prefix("export ") else {
            continue;
        };
        let Some((variable, value)) = rest.split_once('=') else {
            continue;
        };
        if variable.trim() != name {
            continue;
        }
        let value = value.trim().trim_matches(|c| c == '"' || c == '\'');
        if !value.is_empty() {
            // Later assignments win, as they would in a shell.
            found = Some(value.to_string());
        }
    }
    found
}

/// Resolve an exported shell value: `$(cat <path>)`, `$NAME`/`${NAME}`, or a
/// literal.
fn resolve_shell_value(value: &str) -> Option<String> {
    let value = value.trim();
    if let Some(command) = value.strip_prefix("$(").and_then(|v| v.strip_suffix(')')) {
        let argument = command.trim().strip_prefix("cat ")?.trim();
        let path = argument.trim_matches(|c| c == '"' || c == '\'');
        if path.is_empty() {
            return None;
        }
        let contents = std::fs::read_to_string(Path::new(path)).ok()?;
        let contents = contents.trim().to_string();
        return (!contents.is_empty()).then_some(contents);
    }
    if let Some(name) = value.strip_prefix("${").and_then(|v| v.strip_suffix('}')) {
        return env_non_empty(name);
    }
    if let Some(name) = value.strip_prefix('$') {
        return env_non_empty(name);
    }
    (!value.is_empty()).then(|| value.to_string())
}

fn key_from_omp_wrapper(cfg: &Config, name: &str) -> Option<String> {
    let bin = cfg.omp_bin.as_ref()?;
    let script = std::fs::read_to_string(bin).ok()?;
    resolve_shell_value(&shell_export_value(&script, name)?)
}

/// Env-var-shaped names are lookups, never literal secrets.
fn looks_like_env_name(value: &str) -> bool {
    let mut has_upper = false;
    for byte in value.bytes() {
        if byte.is_ascii_uppercase() {
            has_upper = true;
        } else if !(byte.is_ascii_digit() || byte == b'_') {
            return false;
        }
    }
    has_upper
}

/// Resolve a `models.yml` `apiKey` the way omp does, plus the nix wrapper.
fn resolve_api_key(cfg: &Config, spec: &str) -> Option<String> {
    let spec = spec.trim();
    if spec.is_empty() || spec.starts_with('!') {
        // Command-backed keys are never executed by the backend.
        return None;
    }
    if let Some(value) = env_non_empty(spec) {
        return Some(value);
    }
    if let Some(value) = key_from_omp_wrapper(cfg, spec) {
        return Some(value);
    }
    (!looks_like_env_name(spec)).then(|| spec.to_string())
}

fn cliproxyapi_target(cfg: &Config) -> Option<(String, String)> {
    let provider = cliproxyapi_provider_config(cfg);
    let base_url = provider
        .as_ref()
        .and_then(|provider| non_empty_string(provider.get("baseUrl")))
        .unwrap_or_else(|| CLIPROXYAPI_DEFAULT_BASE_URL.to_string());
    let key_spec = provider
        .as_ref()
        .and_then(|provider| non_empty_string(provider.get("apiKey")))
        .unwrap_or_else(|| CLIPROXYAPI_KEY_NAME.to_string());
    let key = resolve_api_key(cfg, &key_spec)?;
    Some((base_url, key))
}

/// `YYYY-MM` → `(year, month)`.
fn parse_year_month(value: &str) -> Option<(i64, i64)> {
    let (year, month) = value.trim().split_once('-')?;
    let year: i64 = year.parse().ok()?;
    let month: i64 = month.parse().ok()?;
    (1..=12).contains(&month).then_some((year, month))
}

/// Days since 1970-01-01 for a proleptic Gregorian date.
fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let year_of_era = year - era * 400;
    let day_of_year = (153 * (if month > 2 { month - 3 } else { month + 9 }) + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;
    era * 146_097 + day_of_era - 719_468
}

/// First millisecond of the month after `current_month` (`YYYY-MM`, UTC).
fn next_month_start_ms(current_month: &str) -> Option<f64> {
    let (year, month) = parse_year_month(current_month)?;
    let (year, month) = if month == 12 {
        (year + 1, 1)
    } else {
        (year, month + 1)
    };
    Some(days_from_civil(year, month, 1) as f64 * 86_400_000.0)
}

/// Query the gateway's self-service quota endpoint (cached briefly).
fn cliproxyapi_quota(cfg: &Config, refresh: bool) -> Option<Value> {
    if !refresh {
        if let Ok(cache) = CLIPROXYAPI_CACHE.lock() {
            if let Some((expires, payload)) = cache.as_ref() {
                if *expires > Instant::now() {
                    return Some(payload.clone());
                }
            }
        }
    }
    let (base_url, api_key) = cliproxyapi_target(cfg)?;
    let url = format!("{}/quota", base_url.trim_end_matches('/'));
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .ok()?;
    let payload = runtime.block_on(async move {
        let client = reqwest::Client::builder()
            .timeout(CLIPROXYAPI_TIMEOUT)
            .build()
            .ok()?;
        let response = client.get(url).bearer_auth(api_key).send().await.ok()?;
        if !response.status().is_success() {
            return None;
        }
        response.json::<Value>().await.ok()
    })?;
    if let Ok(mut cache) = CLIPROXYAPI_CACHE.lock() {
        *cache = Some((Instant::now() + CLIPROXYAPI_QUOTA_TTL, payload.clone()));
    }
    Some(payload)
}

/// Translate `GET /v1/quota` into an omp-shaped raw report so both sources are
/// normalized by the same code.
fn cliproxyapi_report(payload: &Value, now: f64) -> Option<Value> {
    let used = as_number(payload.get("used"))?;
    let quota = as_number(payload.get("quota"));
    let remaining = as_number(payload.get("remaining"))
        .or_else(|| quota.map(|quota| (quota - used).max(0.0)));
    let account = non_empty_string(payload.get("name"));
    let month = non_empty_string(payload.get("current_month"));
    let exceeded = payload
        .get("exceeded")
        .and_then(Value::as_bool)
        .unwrap_or(false);

    let mut amount = Map::new();
    amount.insert("used".into(), Value::from(used));
    if let Some(quota) = quota {
        amount.insert("limit".into(), Value::from(quota));
        if quota > 0.0 {
            amount.insert("usedFraction".into(), Value::from(used / quota));
        }
    }
    if let Some(remaining) = remaining {
        amount.insert("remaining".into(), Value::from(remaining));
    }
    amount.insert("unit".into(), Value::from("usd"));

    let mut window = Map::new();
    window.insert("id".into(), Value::from("monthly"));
    window.insert("label".into(), Value::from("Monthly quota"));
    if let Some(resets_at) = month.as_deref().and_then(next_month_start_ms) {
        if resets_at > now {
            window.insert("resetsAt".into(), Value::from(resets_at));
        }
    }

    let mut scope = Map::new();
    scope.insert("provider".into(), Value::from(CLIPROXYAPI_PROVIDER));
    scope.insert("windowId".into(), Value::from("monthly"));
    if let Some(account) = &account {
        scope.insert("accountId".into(), Value::from(account.clone()));
    }

    let mut limit = Map::new();
    limit.insert("id".into(), Value::from("cliproxyapi-monthly"));
    limit.insert("label".into(), Value::from("Monthly quota"));
    limit.insert("scope".into(), Value::Object(scope));
    limit.insert("window".into(), Value::Object(window));
    limit.insert("amount".into(), Value::Object(amount));
    limit.insert(
        "status".into(),
        Value::from(if exceeded { "exhausted" } else { "ok" }),
    );

    let mut metadata = Map::new();
    if let Some(account) = account {
        metadata.insert("account".into(), Value::from(account));
    }
    if let Some(month) = month {
        metadata.insert("month".into(), Value::from(month));
    }

    Some(json!({
        "provider": CLIPROXYAPI_PROVIDER,
        "metadata": Value::Object(metadata),
        "limits": [Value::Object(limit)],
    }))
}

fn cliproxyapi_usage_report(cfg: &Config, model: Option<&str>, refresh: bool, now: f64) -> Option<Value> {
    let payload = cliproxyapi_quota(cfg, refresh)?;
    let raw = cliproxyapi_report(&payload, now)?;
    let raw = raw.as_object()?;
    normalize_report(raw, None, model, now, 0).into_iter().next()
}

pub fn get_provider_usage(
    cfg: &Config,
    provider: Option<&str>,
    model: Option<&str>,
    refresh: bool,
) -> Result<Value, String> {
    let now = crate::util::now_ms();
    let mut failure: Option<String> = None;
    let (mut generated_at, mut reports) = match load_omp_usage(cfg, refresh) {
        Ok(output) => match parse_provider_usage_output(&output, provider, model, now) {
            Ok(snapshot) => (
                snapshot
                    .get("generatedAt")
                    .and_then(Value::as_f64)
                    .unwrap_or(now),
                snapshot
                    .get("reports")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default(),
            ),
            Err(message) => {
                failure = Some(message);
                (now, Vec::new())
            }
        },
        Err(message) => {
            failure = Some(message);
            (now, Vec::new())
        }
    };

    let wants_cliproxyapi = provider
        .map(|filter| filter == CLIPROXYAPI_PROVIDER)
        .unwrap_or(true);
    let reported_cliproxyapi = reports.iter().any(|report| {
        report.get("provider").and_then(Value::as_str) == Some(CLIPROXYAPI_PROVIDER)
    });
    if wants_cliproxyapi && !reported_cliproxyapi {
        if let Some(report) = cliproxyapi_usage_report(cfg, model, refresh, now) {
            reports.push(report);
            if generated_at < now {
                generated_at = now;
            }
        }
    }

    if reports.is_empty() {
        if let Some(message) = failure {
            return Err(message);
        }
    }
    Ok(json!({
        "generatedAt": generated_at,
        "reports": reports,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cliproxyapi_limit(quota: Option<f64>, used: f64) -> Value {
        cliproxyapi_report(
            &json!({
                "name": "self",
                "current_month": "2026-10",
                "quota": quota,
                "used": used,
                "remaining": quota.map(|quota| (quota - used).max(0.0)),
                "exceeded": quota.map(|quota| used >= quota).unwrap_or(false),
            }),
            1_790_000_000_000.0,
        )
        .unwrap()
    }

    #[test]
    fn parses_windows_into_five_hour_and_week() {
        let output = json!({
            "generatedAt": 1_700_000_000_000i64,
            "reports": [{
                "provider": "anthropic",
                "metadata": { "email": "user@example.com", "planType": "max" },
                "limits": [
                    { "scope": { "windowId": "5h" }, "amount": { "usedFraction": 0.25 }, "window": {} },
                    { "scope": { "windowId": "7d" }, "amount": { "usedFraction": 0.5 }, "window": {} }
                ]
            }]
        })
        .to_string();
        let parsed = parse_provider_usage_output(&output, None, None, 1_700_000_000_000.0).unwrap();
        let report = &parsed["reports"][0];
        assert_eq!(report["accountLabel"], json!("user@example.com"));
        assert_eq!(report["fiveHour"]["percent"], json!(25.0));
        assert_eq!(report["sevenDay"]["percent"], json!(50.0));
        assert_eq!(report["limits"].as_array().unwrap().len(), 2);
        assert_eq!(report["limits"][0]["windowId"], json!("5h"));
    }

    #[test]
    fn report_without_limits_marks_no_limits() {
        let output = json!({ "reports": [{ "provider": "openai", "metadata": {}, "limits": [] }] })
            .to_string();
        let parsed = parse_provider_usage_output(&output, None, None, 0.0).unwrap();
        assert_eq!(parsed["reports"][0]["noLimits"], json!(true));
        assert_eq!(parsed["reports"][0]["accountIndex"], json!(1));
        assert_eq!(parsed["reports"][0]["limits"], json!([]));
    }

    #[test]
    fn keeps_used_only_limits_without_a_fraction() {
        let raw = cliproxyapi_limit(None, 3.4542);
        let normalized =
            normalize_report(raw.as_object().unwrap(), None, None, 1_790_000_000_000.0, 0);
        assert_eq!(normalized.len(), 1);
        let report = &normalized[0];
        assert_eq!(report["provider"], json!("cliproxyapi"));
        assert_eq!(report["accountLabel"], json!("self"));
        assert_eq!(report["monthly"]["used"], json!(3.4542));
        assert_eq!(report["monthly"]["unit"], json!("usd"));
        assert!(report["monthly"].get("limit").is_none());
        assert!(report["monthly"].get("percent").is_none());
        let limit = &report["limits"][0];
        assert_eq!(limit["windowId"], json!("monthly"));
        assert_eq!(limit["used"], json!(3.4542));
        assert_eq!(limit["status"], json!("ok"));
    }

    #[test]
    fn derives_percent_and_remaining_from_amounts() {
        let raw = cliproxyapi_limit(Some(20.0), 3.45);
        let normalized =
            normalize_report(raw.as_object().unwrap(), None, None, 1_790_000_000_000.0, 0);
        let monthly = &normalized[0]["monthly"];
        assert_eq!(monthly["percent"], json!(17.25));
        assert_eq!(monthly["limit"], json!(20.0));
        assert_eq!(monthly["remaining"], json!(16.55));
        assert!(monthly["resetHours"].as_f64().is_some());
    }

    #[test]
    fn account_label_falls_back_to_metadata_account() {
        let raw = json!({
            "provider": "cliproxyapi",
            "metadata": { "account": "self" },
            "limits": [{
                "id": "monthly",
                "scope": { "windowId": "monthly" },
                "window": { "id": "monthly", "label": "Monthly" },
                "amount": { "used": 1.0, "unit": "usd" }
            }]
        });
        let normalized = normalize_report(raw.as_object().unwrap(), None, None, 0.0, 0);
        assert_eq!(normalized[0]["accountLabel"], json!("self"));
        assert_eq!(normalized[0]["limits"][0]["label"], json!("Monthly"));
    }

    #[test]
    fn computes_next_month_start_across_year_boundary() {
        assert_eq!(
            next_month_start_ms("2026-10"),
            Some(days_from_civil(2026, 11, 1) as f64 * 86_400_000.0)
        );
        assert_eq!(
            next_month_start_ms("2026-12"),
            Some(days_from_civil(2027, 1, 1) as f64 * 86_400_000.0)
        );
        assert_eq!(next_month_start_ms("not-a-month"), None);
    }

    #[test]
    fn reads_exports_from_the_omp_wrapper_script() {
        let script = "\
#!/bin/sh
export HINDSIGHT_API_TOKEN=\"$(cat \"/run/secrets/hindsight\")\"
export CLIPROXYAPI_API_KEY=\"$(cat '/run/secrets/cliproxyapi')\"
exec /nix/store/omp/bin/omp \"$@\"
";
        assert_eq!(
            shell_export_value(script, "CLIPROXYAPI_API_KEY"),
            Some("$(cat '/run/secrets/cliproxyapi')".to_string())
        );
        assert_eq!(shell_export_value(script, "MISSING"), None);
    }

    #[test]
    fn resolves_literal_and_env_api_keys() {
        assert_eq!(resolve_shell_value("plain-key"), Some("plain-key".to_string()));
        assert_eq!(
            resolve_shell_value("$(cat /nonexistent/aidesk-key)"),
            None
        );
        assert!(looks_like_env_name("CLIPROXYAPI_API_KEY"));
        assert!(!looks_like_env_name("ollama"));
        assert!(!looks_like_env_name("sk-literal-key"));
    }
}
