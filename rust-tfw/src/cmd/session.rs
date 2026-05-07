use crate::config::Config;
use crate::i18n::Lang;
use crate::util::{need_command, need_root};
use rand::Rng;
use regex::Regex;
use std::fs;
use std::process::Command;

pub fn run(cfg: &Config, action: &str, lang: Lang) -> Result<(), String> {
    match action {
        "show" | "status" => {
            if cfg.auth_session_token.is_empty() {
                println!("AUTH_SESSION_TOKEN not set");
            } else {
                println!("AUTH_SESSION_TOKEN={}", cfg.auth_session_token);
            }
            Ok(())
        }
        "rotate" | "renew" => rotate(cfg, lang),
        _ => {
            eprintln!("Usage: tfw session [rotate|show]");
            Err("invalid session action".to_string())
        }
    }
}

fn rotate(cfg: &Config, lang: Lang) -> Result<(), String> {
    need_root(lang)?;
    need_command("openssl", lang)?;

    // Generate 48-char hex token
    let new_token: String = (0..48)
        .map(|_| {
            let b: u8 = rand::thread_rng().gen_range(0..16);
            format!("{:x}", b)
        })
        .collect();

    // 1. Update runtime config file (/etc/tfw/tfw.conf)
    if cfg.config_file.is_file() {
        replace_in_file(
            &cfg.config_file,
            r"AUTH_SESSION_TOKEN='[^']*'",
            &format!("AUTH_SESSION_TOKEN='{}'", new_token),
        )?;
    }

    // 2. Update auth map file
    let auth_map_path = "/etc/nginx/conf.d/temp-file-web-map.conf";
    if std::path::Path::new(auth_map_path).is_file() {
        replace_in_file(
            std::path::Path::new(auth_map_path),
            r#""[^"]*""#,
            &format!("\"{}\"", new_token),
        )?;
    }

    // 3. Update nginx site config
    let site_conf = &cfg.conf;
    if site_conf.is_file() {
        replace_in_file(
            site_conf,
            r"tfw_upload_auth=[^;]*",
            &format!("tfw_upload_auth={}", new_token),
        )?;
    }

    // Reload nginx
    let _ = Command::new("nginx").arg("-t").status();
    if Command::new("systemctl")
        .args(["reload", "nginx"])
        .status()
        .is_err()
    {
        let _ = Command::new("nginx").args(["-s", "reload"]).status();
    }

    println!("Session token rotated.");
    println!("New token: {}", new_token);

    Ok(())
}

fn replace_in_file(path: &std::path::Path, pattern: &str, replacement: &str) -> Result<(), String> {
    let content =
        fs::read_to_string(path).map_err(|e| format!("read {}: {}", path.display(), e))?;
    let re = Regex::new(pattern).map_err(|e| format!("regex: {}", e))?;
    let new_content = re.replace(&content, replacement);
    fs::write(path, new_content.as_bytes())
        .map_err(|e| format!("write {}: {}", path.display(), e))?;
    Ok(())
}
