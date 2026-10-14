use anyhow::{Context, ensure};
use reqwest::Url;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Content {
    #[serde(rename = "type")]
    pub content_type: String,
    pub server: Option<String>,
    #[serde(default)]
    pub body: Body,
}

#[derive(Debug, Default, Deserialize)]
pub struct Body {
    pub note: Option<Note>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub id: String,
    pub visibility: String,
    pub text: Option<String>,
    pub reply_id: Option<String>,
    pub cw: Option<String>,
    pub renote: Option<Renote>,
    #[serde(default)]
    pub local_only: bool,
    #[serde(default)]
    pub files: Vec<File>,
}

#[derive(Debug, Deserialize)]
pub struct Renote {
    pub id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct File {
    pub name: String,
    pub url: String,
    #[serde(rename = "type")]
    pub file_type: String,
    #[serde(default)]
    pub is_sensitive: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub enum NoteKind {
    Post,
    Forward,
    Quote,
}

impl Note {
    pub fn kind(&self) -> NoteKind {
        match &self.renote {
            None => NoteKind::Post,
            Some(_) if self.text.is_none() && self.files.is_empty() => NoteKind::Forward,
            Some(_) => NoteKind::Quote,
        }
    }

    fn should_forward(&self) -> bool {
        self.visibility == "public" && !self.local_only && self.reply_id.is_none()
    }
}

#[derive(Debug)]
pub struct Job {
    pub server: Url,
    pub note: Note,
}

impl Content {
    pub fn into_job(self) -> anyhow::Result<Option<Job>> {
        if self.content_type != "note" {
            return Ok(None);
        }
        let Some(note) = self.body.note else {
            return Ok(None);
        };
        if !note.should_forward() {
            return Ok(None);
        }
        ensure!(!note.id.is_empty(), "Empty note ID");
        if let Some(renote) = &note.renote {
            ensure!(!renote.id.is_empty(), "Empty renote ID");
        }
        let server = Url::parse(self.server.as_deref().context("Missing Misskey server")?)
            .context("Invalid Misskey server URL")?;
        ensure!(
            matches!(server.scheme(), "http" | "https") && server.host_str().is_some(),
            "Misskey server must be an HTTP(S) URL"
        );
        ensure!(
            server.username().is_empty() && server.password().is_none(),
            "Misskey server URL must not contain credentials"
        );
        Ok(Some(Job { server, note }))
    }
}

impl Job {
    pub fn note_url(&self, id: &str) -> Url {
        let mut url = self.server.clone();
        url.set_query(None);
        url.set_fragment(None);
        url.path_segments_mut()
            .expect("Validated HTTP server URL")
            .clear()
            .push("notes")
            .push(id);
        url
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn payload() -> serde_json::Value {
        json!({"type":"note", "server":"https://example.org", "body":{"note":{
            "id":"n1", "visibility":"public", "text":"hello", "files":[]
        }}})
    }

    #[test]
    fn only_public_nonlocal_nonreply_notes_are_forwarded() {
        for (key, value) in [
            ("visibility", json!("home")),
            ("localOnly", json!(true)),
            ("replyId", json!("parent")),
        ] {
            let mut event = payload();
            event["body"]["note"][key] = value;
            assert!(
                serde_json::from_value::<Content>(event)
                    .unwrap()
                    .into_job()
                    .unwrap()
                    .is_none()
            );
        }
        let job = serde_json::from_value::<Content>(payload())
            .unwrap()
            .into_job()
            .unwrap()
            .unwrap();
        assert_eq!(job.note.kind(), NoteKind::Post);
        assert_eq!(
            job.note_url("a/b?c").as_str(),
            "https://example.org/notes/a%2Fb%3Fc"
        );
    }

    #[test]
    fn forward_and_quote_are_distinct() {
        let mut event = payload();
        event["body"]["note"]["renote"] = json!({"id":"original"});
        event["body"]["note"]["text"] = serde_json::Value::Null;
        let note: Content = serde_json::from_value(event.clone()).unwrap();
        assert_eq!(note.body.note.unwrap().kind(), NoteKind::Forward);
        event["body"]["note"]["files"] =
            json!([{"name":"photo", "url":"https://example.org/p.png", "type":"image/png"}]);
        let note: Content = serde_json::from_value(event).unwrap();
        assert_eq!(note.body.note.unwrap().kind(), NoteKind::Quote);
    }

    #[test]
    fn ignored_events_need_no_server_and_invalid_origins_fail() {
        let content: Content = serde_json::from_value(json!({"type":"follow"})).unwrap();
        assert!(content.into_job().unwrap().is_none());
        for server in [
            "file:///tmp/x",
            "https://user:password@example.org",
            "not-a-url",
        ] {
            let mut event = payload();
            event["server"] = json!(server);
            assert!(
                serde_json::from_value::<Content>(event)
                    .unwrap()
                    .into_job()
                    .is_err()
            );
        }
    }
}
