use tracing::error;
use twitter_v2::authorization::Oauth1aToken;
use twitter_v2::TwitterApi;
use egg_mode_text::character_count;

fn get_weight(text: &str) -> usize {
    // URL 长度统一按 23 计算（Twitter 官方标准）
    character_count(text, 23, 23)
}

pub fn split_into_tweets(text: &str) -> Vec<String> {
    // Twitter 加权上限为 280。我们预留 12 个加权字符给后缀如 " (10/10)"
    let max_weight = 268;
    let mut chunks = Vec::new();
    let mut current_chunk = String::new();

    // 优先按段落/换行符切分
    let lines: Vec<&str> = text.split('\n').collect();

    for line in lines {
        let potential_text = if current_chunk.is_empty() {
            line.to_string()
        } else {
            format!("{}\n{}", current_chunk, line)
        };

        if get_weight(&potential_text) <= max_weight {
            // 装得下，继续累加到当前块
            current_chunk = potential_text;
        } else {
            // 装不下了
            if !current_chunk.is_empty() {
                chunks.push(current_chunk);
                current_chunk = String::new();
            }

            // 处理当前无法装下的这一行
            if get_weight(line) <= max_weight {
                current_chunk = line.to_string();
            } else {
                // 这一行本身就超长了，必须极限切分
                let mut remainder = line;
                while get_weight(remainder) > max_weight {
                    let mut cut_idx = 0;
                    for (i, c) in remainder.char_indices() {
                        let next_idx = i + c.len_utf8();
                        let w = get_weight(&remainder[..next_idx]);
                        if w > max_weight {
                            break;
                        }
                        cut_idx = next_idx;
                    }

                    if cut_idx == 0 && !remainder.is_empty() {
                        // 极端情况防死循环，强制至少切一个字符
                        cut_idx = remainder.chars().next().unwrap().len_utf8();
                    }

                    chunks.push(remainder[..cut_idx].to_string());
                    remainder = &remainder[cut_idx..];
                }
                if !remainder.is_empty() {
                    current_chunk = remainder.to_string();
                }
            }
        }
    }

    if !current_chunk.is_empty() {
        chunks.push(current_chunk);
    }

    let total = chunks.len();
    if total <= 1 {
        chunks
    } else {
        chunks
            .into_iter()
            .enumerate()
            .map(|(i, chunk)| format!("{} ({}/{})", chunk.trim_end(), i + 1, total))
            .collect()
    }
}

pub async fn send_thread(
    api: &TwitterApi<Oauth1aToken>,
    full_text: &str,
    mut reply_to_tweet_id: Option<String>,
) -> Result<Option<String>, anyhow::Error> {
    // 获取切分好的推文数组
    let chunks = split_into_tweets(full_text);
    let mut first_tweet_id = None;

    for chunk in chunks {
        let mut builder = api.post_tweet();
        builder.text(chunk);
        
        if let Some(ref reply_id) = reply_to_tweet_id {
            if let Ok(id_u64) = reply_id.parse::<u64>() {
                builder.in_reply_to_tweet_id(id_u64);
            }
        }

        match builder.send().await {
            Ok(res) => {
                if let Some(data) = &res.data {
                    let id = data.id.to_string();
                    if first_tweet_id.is_none() {
                        first_tweet_id = Some(id.clone());
                    }
                    reply_to_tweet_id = Some(id);
                }
            }
            Err(e) => {
                error!("Twitter API error: {:?}", e);
                // 串联发送中断，保留已成功发出的第一条帖子的 ID
                if first_tweet_id.is_none() {
                    return Err(e.into());
                }
                break;
            }
        }
    }

    Ok(first_tweet_id)
}