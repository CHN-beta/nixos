use tracing::error;
use egg_mode_text::character_count;
use serde_json::json;

pub fn get_weight(text: &str) -> usize {
    character_count(text, 23, 23)
}

pub async fn send_to_make(
    webhook_url: &str,
    text: &str,
) -> Result<(), anyhow::Error> {
    let client = reqwest::Client::new();
    
    let payload = json!({
        "text": text,
    });

    let res = client.post(webhook_url)
        .json(&payload)
        .send()
        .await?;

    if res.status().is_success() {
        Ok(())
    } else {
        error!("Make.com Webhook error: {}", res.status());
        Err(anyhow::anyhow!("Webhook failed with status: {}", res.status()))
    }
}