use std::{fs, path::Path};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Config {
    pub database_url: String,
    pub jwt_secret: String,
    pub host: String,
    pub port: u16,
}

impl Config {
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self, Box<dyn std::error::Error>> {
        let path = path.as_ref();
        let content = fs::read_to_string(path)
            .map_err(|e| format!("读取配置文件 {:?} 失败: {}", path, e))?;
        let config: Config = serde_yaml::from_str(&content)
            .map_err(|e| format!("解析配置文件 {:?} 失败: {}", path, e))?;
        Ok(config)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_valid_yaml() {
        let yaml = r#"
database_url: "postgres://user:pass@localhost:5432/db"
jwt_secret: "my_secret_key"
host: "127.0.0.1"
port: 8080
"#;
        let config: Config = serde_yaml::from_str(yaml).expect("should parse valid yaml");
        assert_eq!(config.database_url, "postgres://user:pass@localhost:5432/db");
        assert_eq!(config.jwt_secret, "my_secret_key");
        assert_eq!(config.host, "127.0.0.1");
        assert_eq!(config.port, 8080);
    }

    #[test]
    fn test_rejects_missing_field() {
        // 缺少 port 字段，必须解析报错（无默认值）
        let yaml_missing_port = r#"
database_url: "postgres://user:pass@localhost:5432/db"
jwt_secret: "my_secret_key"
host: "127.0.0.1"
"#;
        assert!(serde_yaml::from_str::<Config>(yaml_missing_port).is_err());

        // 缺少 database_url 字段，必须解析报错
        let yaml_missing_db = r#"
jwt_secret: "my_secret_key"
host: "127.0.0.1"
port: 8080
"#;
        assert!(serde_yaml::from_str::<Config>(yaml_missing_db).is_err());
    }
}
