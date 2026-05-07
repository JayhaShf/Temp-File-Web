use crate::config::Config;
use hickory_resolver::TokioAsyncResolver;
use reqwest::dns::{Addrs, Name, Resolve, Resolving};
use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::sync::Arc;

struct OverrideResolver {
    inner: TokioAsyncResolver,
    overrides: HashMap<String, IpAddr>,
}

impl Resolve for OverrideResolver {
    fn resolve(&self, name: Name) -> Resolving {
        let host = name.as_str().to_string();
        let overrides = self.overrides.clone();
        let inner = self.inner.clone();
        Box::pin(async move {
            if let Some(ip) = overrides.get(&host) {
                let addrs: Vec<SocketAddr> = vec![SocketAddr::new(*ip, 0)];
                return Ok(Box::new(addrs.into_iter()) as Addrs);
            }
            let lookup = inner.lookup_ip(host).await?;
            let addrs: Vec<SocketAddr> = lookup.iter().map(|ip| SocketAddr::new(ip, 0)).collect();
            Ok(Box::new(addrs.into_iter()) as Addrs)
        })
    }
}

pub fn build_client(config: &Config) -> anyhow::Result<reqwest::Client> {
    let resolve_ip: IpAddr = config
        .ip
        .parse()
        .unwrap_or_else(|_| "127.0.0.1".parse().unwrap());
    let resolve_host = config.resolve_host();

    let mut overrides = HashMap::new();
    overrides.insert(resolve_host, resolve_ip);

    let resolver = OverrideResolver {
        inner: TokioAsyncResolver::tokio_from_system_conf()?,
        overrides,
    };

    Ok(reqwest::Client::builder()
        .dns_resolver(Arc::new(resolver))
        .danger_accept_invalid_certs(true)
        .cookie_store(true)
        .build()?)
}

pub async fn http_code(
    client: &reqwest::Client,
    url: &str,
    auth: Option<&str>,
    method: &str,
) -> String {
    let method_parsed = match method {
        "GET" => reqwest::Method::GET,
        "POST" => reqwest::Method::POST,
        "PUT" => reqwest::Method::PUT,
        "DELETE" => reqwest::Method::DELETE,
        "OPTIONS" => reqwest::Method::OPTIONS,
        _ => reqwest::Method::GET,
    };

    let mut req = client.request(method_parsed, url);
    if let Some(credentials) = auth {
        let encoded = base64_encode(credentials);
        req = req.header("Authorization", format!("Basic {}", encoded));
    }

    match req.send().await {
        Ok(resp) => resp.status().as_u16().to_string(),
        Err(_) => "ERR".to_string(),
    }
}

pub async fn http_body(client: &reqwest::Client, url: &str) -> Result<String, String> {
    match client.get(url).send().await {
        Ok(resp) => resp.text().await.map_err(|e| e.to_string()),
        Err(e) => Err(e.to_string()),
    }
}

fn base64_encode(input: &str) -> String {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD.encode(input.as_bytes())
}
