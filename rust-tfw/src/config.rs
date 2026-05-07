use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct Config {
    pub config_file: PathBuf,
    pub domain: String,
    pub site_id: String,
    pub ip: String,
    pub access_host: String,
    pub site_title: String,
    pub project_url: String,
    pub language: String,
    pub install_acme: String,
    pub site_mode: String,
    pub http_port: String,
    pub https_port: String,
    pub conf: PathBuf,
    pub site_dir: PathBuf,
    pub auth_file: PathBuf,
    pub data_dir: PathBuf,
    pub upload_dir: PathBuf,
    pub browser_html: PathBuf,
    pub upload_html: PathBuf,
    pub access_log: PathBuf,
    pub error_log: PathBuf,
    pub acme_webroot: PathBuf,
    pub cert_file: PathBuf,
    pub key_file: PathBuf,
    pub auth_session_token: String,
    pub acme_home: PathBuf,
    pub acme_bin: PathBuf,
    pub tfw_project_dir: Option<String>,
    pub tfw_user: String,
}

pub struct Urls {
    pub url_scheme: String,
    pub url_authority: String,
    pub url_root: String,
    pub url_upload: String,
    pub url_listing: String,
    pub url_session_login: String,
    pub url_session_status: String,
}

fn parse_shell_vars(content: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some(eq_pos) = line.find('=') {
            let key = line[..eq_pos].trim().to_string();
            let raw_val = line[eq_pos + 1..].trim();
            let value =
                if raw_val.len() >= 2 && raw_val.starts_with('\'') && raw_val.ends_with('\'') {
                    raw_val[1..raw_val.len() - 1].to_string()
                } else {
                    raw_val.to_string()
                };
            map.insert(key, value);
        }
    }
    map
}

impl Config {
    pub fn from_file(path: &Path) -> Self {
        let map = fs::read_to_string(path)
            .map(|c| parse_shell_vars(&c))
            .unwrap_or_default();
        Self::from_map(map, path.to_path_buf())
    }

    fn from_map(map: HashMap<String, String>, config_file: PathBuf) -> Self {
        let domain = map.get("DOMAIN").cloned().unwrap_or_default();
        let site_id = map
            .get("SITE_ID")
            .cloned()
            .unwrap_or_else(|| "site".to_string());
        let ip = map
            .get("IP")
            .cloned()
            .unwrap_or_else(|| "127.0.0.1".to_string());
        let access_host = map.get("ACCESS_HOST").cloned().unwrap_or_else(|| {
            if domain.is_empty() {
                ip.clone()
            } else {
                domain.clone()
            }
        });
        let site_title = map
            .get("SITE_TITLE")
            .cloned()
            .unwrap_or_else(|| "Temp File Web".to_string());
        let project_url = map
            .get("PROJECT_URL")
            .cloned()
            .unwrap_or_else(|| "https://github.com/JayhaShf/Temp-File-Web".to_string());
        let language = map
            .get("LANGUAGE")
            .cloned()
            .unwrap_or_else(|| "en".to_string());
        let install_acme = map
            .get("INSTALL_ACME")
            .cloned()
            .unwrap_or_else(|| "1".to_string());
        let site_mode = map
            .get("SITE_MODE")
            .cloned()
            .unwrap_or_else(|| "https".to_string());
        let http_port = map
            .get("HTTP_PORT")
            .cloned()
            .unwrap_or_else(|| "80".to_string());
        let https_port = map
            .get("HTTPS_PORT")
            .cloned()
            .unwrap_or_else(|| "443".to_string());

        let conf = map
            .get("CONF")
            .cloned()
            .unwrap_or_else(|| "/etc/nginx/conf.d/temp-file-web.conf".to_string());
        let site_dir = map
            .get("SITE_DIR")
            .cloned()
            .unwrap_or_else(|| format!("/etc/tfw/sites/{}", site_id));
        let auth_file = map
            .get("AUTH_FILE")
            .cloned()
            .unwrap_or_else(|| format!("/etc/tfw/sites/{}/file-upload.htpasswd", site_id));
        let data_dir = map
            .get("DATA_DIR")
            .cloned()
            .unwrap_or_else(|| "/srv/tfw/data".to_string());
        let upload_dir = map
            .get("UPLOAD_DIR")
            .cloned()
            .unwrap_or_else(|| data_dir.clone());
        let browser_html = map
            .get("BROWSER_HTML")
            .cloned()
            .unwrap_or_else(|| format!("/etc/tfw/sites/{}/file-browser.html", site_id));
        let upload_html = map
            .get("UPLOAD_HTML")
            .cloned()
            .unwrap_or_else(|| format!("/etc/tfw/sites/{}/file-upload.html", site_id));
        let access_log = map
            .get("ACCESS_LOG")
            .cloned()
            .unwrap_or_else(|| format!("/var/log/nginx/{}.access.log", site_id));
        let error_log = map
            .get("ERROR_LOG")
            .cloned()
            .unwrap_or_else(|| format!("/var/log/nginx/{}.error.log", site_id));
        let acme_webroot = map
            .get("ACME_WEBROOT")
            .cloned()
            .unwrap_or_else(|| "/var/www/_acme-challenge".to_string());
        let cert_file = map
            .get("CERT_FILE")
            .cloned()
            .unwrap_or_else(|| format!("/etc/tfw/sites/{}/certs/fullchain.cer", site_id));
        let key_file = map
            .get("KEY_FILE")
            .cloned()
            .unwrap_or_else(|| format!("/etc/tfw/sites/{}/certs/{}.key", site_id, site_id));
        let acme_home = map
            .get("ACME_HOME")
            .cloned()
            .unwrap_or_else(|| "/root/.acme.sh".to_string());
        let acme_bin = map
            .get("ACME_BIN")
            .cloned()
            .unwrap_or_else(|| "/root/.acme.sh/acme.sh".to_string());
        let tfw_project_dir = map
            .get("TFW_PROJECT_DIR")
            .cloned()
            .filter(|v| !v.is_empty());
        let tfw_user = map
            .get("TFW_USER")
            .cloned()
            .unwrap_or_else(|| "www-data".to_string());
        let auth_session_token = map.get("AUTH_SESSION_TOKEN").cloned().unwrap_or_default();

        Config {
            config_file,
            domain,
            site_id,
            ip,
            access_host,
            site_title,
            project_url,
            language,
            install_acme,
            site_mode,
            http_port,
            https_port,
            conf: PathBuf::from(conf),
            site_dir: PathBuf::from(site_dir),
            auth_file: PathBuf::from(auth_file),
            data_dir: PathBuf::from(data_dir),
            upload_dir: PathBuf::from(upload_dir),
            browser_html: PathBuf::from(browser_html),
            upload_html: PathBuf::from(upload_html),
            access_log: PathBuf::from(access_log),
            error_log: PathBuf::from(error_log),
            acme_webroot: PathBuf::from(acme_webroot),
            cert_file: PathBuf::from(cert_file),
            key_file: PathBuf::from(key_file),
            auth_session_token,
            acme_home: PathBuf::from(acme_home),
            acme_bin: PathBuf::from(acme_bin),
            tfw_project_dir,
            tfw_user,
        }
    }

    pub fn resolve_host(&self) -> String {
        let mut h = self.access_host.clone();
        if h.starts_with('[') {
            h = h[1..].to_string();
        }
        if h.ends_with(']') {
            h = h[..h.len() - 1].to_string();
        }
        h
    }

    pub fn display_host(&self) -> String {
        let h = &self.access_host;
        if h.contains(':') && !h.starts_with('[') {
            format!("[{}]", h)
        } else {
            h.clone()
        }
    }
}

impl Urls {
    pub fn from_config(cfg: &Config) -> Self {
        let url_scheme = if cfg.site_mode == "https" {
            "https"
        } else {
            "http"
        };
        let (url_port, default_port) = if cfg.site_mode == "https" {
            (cfg.https_port.clone(), "443")
        } else {
            (cfg.http_port.clone(), "80")
        };
        let display_host = cfg.display_host();
        let url_authority = if url_port != default_port {
            format!("{}:{}", display_host, url_port)
        } else {
            display_host
        };
        let url_root = format!("{}://{}/", url_scheme, url_authority);
        let url_upload = format!("{}://{}/upload", url_scheme, url_authority);
        let url_listing = format!("{}://{}/_listing/", url_scheme, url_authority);
        let url_session_login = format!("{}://{}/_session_login", url_scheme, url_authority);
        let url_session_status = format!("{}://{}/_session_status", url_scheme, url_authority);

        Urls {
            url_scheme: url_scheme.to_string(),
            url_authority,
            url_root,
            url_upload,
            url_listing,
            url_session_login,
            url_session_status,
        }
    }
}
