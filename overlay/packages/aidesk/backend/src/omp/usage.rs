//! Provider usage snapshots (`omp usage --json`).

use crate::config::Config;
use serde_json::{json, Map, Value};
use std::sync::Mutex;
use std::time::{Duration, Instant};

const USAGE_CACHE_TTL: Duration = Duration::from_secs(300);

static USAGE_CACHE: std::sync::LazyLock<Mutex<Option<(Instant, String)>>> =
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
    match scope.get("windowId").and_then(Value::as_str) {
        Some("5h") | Some("daily") => return Some("5h"),
        Some("7d") => return Some("7d"),
        Some("monthly") | Some("30d") => return Some("monthly"),
        _ => {}
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

#[derive(Default)]
struct UsageGroup {
    priority: u8,
    model_id: Option<String>,
    tier: Option<String>,
    five_hour: Option<Value>,
    seven_day: Option<Value>,
    monthly: Option<Value>,
    fractions: Map<String, Value>,
}

fn usage_window(window_id: &str, fraction: f64, window: &Map<String, Value>, now: f64) -> Value {
    let resets_at = as_number(window.get("resetsAt"));
    let percent = fraction * 100.0;
    if window_id == "5h" {
        let mut out = Map::new();
        out.insert("percent".into(), Value::from(percent));
        if let Some(resets_at) = resets_at {
            out.insert(
                "resetMinutes".into(),
                Value::from(((resets_at - now) / 60_000.0).round().max(0.0) as i64),
            );
        }
        return Value::Object(out);
    }
    let mut out = Map::new();
    out.insert("percent".into(), Value::from(percent));
    if let Some(resets_at) = resets_at {
        out.insert(
            "resetHours".into(),
            Value::from(((resets_at - now) / 3_600_000.0).round().max(0.0) as i64),
        );
    }
    Value::Object(out)
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
        let Some(fraction) = as_number(amount.get("usedFraction")) else {
            continue;
        };
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
        let rendered = usage_window(window_id, fraction, &window, now);
        // Keep the highest fraction per window (later limits only replace when
        // they report a larger share).
        let slot = match window_id {
            "5h" => &mut group.five_hour,
            "7d" => &mut group.seven_day,
            _ => &mut group.monthly,
        };
        let candidate_fraction = fraction;
        let current_fraction = group
            .fractions
            .get(window_id)
            .and_then(Value::as_f64)
            .unwrap_or(-1.0);
        if candidate_fraction >= current_fraction {
            *slot = Some(rendered);
            group
                .fractions
                .insert(window_id.to_string(), Value::from(candidate_fraction));
        }
    }

    if let (Some(_), false) = (&active_model, groups.is_empty()) {
        // no-op — kept for symmetry with the reference implementation
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
    let label = metadata.and_then(|m| non_empty_string(m.get("email")));
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

pub fn get_provider_usage(
    cfg: &Config,
    provider: Option<&str>,
    model: Option<&str>,
    refresh: bool,
) -> Result<Value, String> {
    let output = if !refresh {
        if let Ok(cache) = USAGE_CACHE.lock() {
            if let Some((expires, output)) = cache.as_ref() {
                if *expires > Instant::now() {
                    return parse_provider_usage_output(
                        output,
                        provider,
                        model,
                        crate::util::now_ms(),
                    );
                }
            }
        }
        run_omp(cfg, &["usage", "--json"])?
    } else {
        let _ = run_omp(cfg, &["usage", "invalidate"]);
        run_omp(cfg, &["usage", "--json"])?
    };
    if let Ok(mut cache) = USAGE_CACHE.lock() {
        *cache = Some((Instant::now() + USAGE_CACHE_TTL, output.clone()));
    }
    parse_provider_usage_output(&output, provider, model, crate::util::now_ms())
}

#[cfg(test)]
mod tests {
    use super::*;

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
    }

    #[test]
    fn report_without_limits_marks_no_limits() {
        let output = json!({ "reports": [{ "provider": "openai", "metadata": {}, "limits": [] }] })
            .to_string();
        let parsed = parse_provider_usage_output(&output, None, None, 0.0).unwrap();
        assert_eq!(parsed["reports"][0]["noLimits"], json!(true));
        assert_eq!(parsed["reports"][0]["accountIndex"], json!(1));
    }
}
