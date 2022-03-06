use std::net::{IpAddr, SocketAddr};
use std::str::FromStr;

pub mod env;

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

        if let Some(bind_ip) = Config::read_env(env::BIND_IP)? {
            cfg.bind_ip = bind_ip
        }
        if let Some(bind_port) = Config::read_env(env::BIND_PORT)? {
            cfg.bind_port = bind_port
        }

        Ok(cfg)
    }

    fn read_env<T>(key: &str) -> Result<Option<T>, ConfigError>
    where
        T: FromStr,
        <T as FromStr>::Err: std::error::Error + Send + Sync + 'static,
    {
        match std::env::var(key).ok() {
            Some(env_value) => env_value
                .parse::<T>()
                .map_err(|e| ConfigError::InvalidConfigValue {
                    key: key.to_owned(),
                    found: env_value,
                    source: anyhow::Error::from(e),
                })
                .map(Some),
            None => Ok(None),
        }
    }

    pub fn socket_addr(&self) -> Result<impl Into<SocketAddr>, ConfigError> {
        self.bind_ip
            .parse::<IpAddr>()
            .map_err(|err| ConfigError::InvalidConfigValue {
                key: env::BIND_PORT.to_owned(),
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
