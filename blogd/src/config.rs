use std::env;
use std::net::{IpAddr, SocketAddr};

pub const ENV_BIND_PORT: &'static str = "BLOGD_PORT";
pub const ENV_LOG: &'static str = "BLOGD_LOG";

#[derive(thiserror::Error, Debug)]
pub enum ConfigError {
    #[error("invalid config value key: {key} found: {found}")]
    InvalidConfigValue {
        key: String,
        found: String,
        source: anyhow::Error,
    },
    #[error("unknown config error")]
    Unknown(#[from] anyhow::Error),
}

#[derive(Debug)]
pub struct Config {
    pub bind_port: u16,
    pub bind_ip: String,
}

impl Config {
    pub fn load_from_env() -> Result<Self, ConfigError> {
        let mut cfg = Config::default();

        if let Some(bind_port) = env::var(ENV_BIND_PORT).ok() {
            cfg.bind_port = bind_port
                .parse()
                .map_err(|e| ConfigError::InvalidConfigValue {
                    key: ENV_BIND_PORT.to_owned(),
                    found: bind_port,
                    source: anyhow::Error::from(e),
                })?;
        }

        Ok(cfg)
    }

    pub fn socket_addr(&self) -> Result<impl Into<SocketAddr>, ConfigError> {
        self.bind_ip
            .parse::<IpAddr>()
            .map_err(|err| ConfigError::InvalidConfigValue {
                key: ENV_BIND_PORT.to_owned(),
                found: self.bind_ip.clone(),
                source: err.into(),
            })
            .map(|ip| (ip, self.bind_port))
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            bind_port: 9200,
            bind_ip: String::from("0.0.0.0"),
        }
    }
}
