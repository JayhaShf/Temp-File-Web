use crate::config::Config;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{need_root, path_state, print_kv, print_kv_state, read_state};
use regex::Regex;
use std::fs;
use std::path::Path;
use std::process::Command;

pub fn show(cfg: &Config, lang: Lang) {
    let acme_text = if cfg.install_acme == "1" {
        msg(MsgKey::EnabledYes, lang)
    } else {
        msg(MsgKey::EnabledNo, lang)
    };

    print_kv(msg(MsgKey::SiteMode, lang), &cfg.site_mode);
    print_kv(msg(MsgKey::AcmeEnabled, lang), acme_text);

    if cfg.install_acme == "1" {
        print_kv_state(
            msg(MsgKey::AcmeBin, lang),
            &cfg.acme_bin.to_string_lossy(),
            &path_state(&cfg.acme_bin, lang),
        );
        print_kv_state(
            msg(MsgKey::AcmeHome, lang),
            &cfg.acme_home.to_string_lossy(),
            &path_state(&cfg.acme_home, lang),
        );
    }
    print_kv_state(
        msg(MsgKey::CertSetCertLabel, lang),
        &cfg.cert_file.to_string_lossy(),
        &read_state(&cfg.cert_file, lang),
    );
    print_kv_state(
        msg(MsgKey::CertSetKeyLabel, lang),
        &cfg.key_file.to_string_lossy(),
        &read_state(&cfg.key_file, lang),
    );
    println!("{}", msg(MsgKey::CertSetUsage, lang));
}

pub fn set(
    cfg: &Config,
    cert_path: Option<&str>,
    key_path: Option<&str>,
    lang: Lang,
) -> Result<(), String> {
    need_root(lang)?;

    if cert_path.is_none() && key_path.is_none() {
        return Err(msg(MsgKey::CertSetUsage, lang).to_string());
    }

    let mut updates = Vec::new();
    if let Some(path) = cert_path {
        updates.push((
            "CERT_FILE",
            msg(MsgKey::CertSetCertLabel, lang),
            cfg.cert_file.to_string_lossy().to_string(),
            path.to_string(),
        ));
    }
    if let Some(path) = key_path {
        updates.push((
            "KEY_FILE",
            msg(MsgKey::CertSetKeyLabel, lang),
            cfg.key_file.to_string_lossy().to_string(),
            path.to_string(),
        ));
    }

    for (_, label, _, new_path) in &updates {
        if new_path.contains('\'') {
            return Err(format!(
                "{}: {} ({})",
                msg(MsgKey::CertSetInvalidPath, lang),
                label,
                new_path
            ));
        }
        if !Path::new(new_path).is_file() {
            return Err(format!(
                "{}: {} ({})",
                msg(MsgKey::CertSetMissingPath, lang),
                label,
                new_path
            ));
        }
    }

    let runtime_content =
        fs::read_to_string(&cfg.config_file).map_err(|e| format!("read config: {}", e))?;
    let nginx_content =
        fs::read_to_string(&cfg.conf).map_err(|e| format!("read nginx config: {}", e))?;
    let runtime_backup = backup_path(&cfg.config_file.to_string_lossy());
    let nginx_backup = backup_path(&cfg.conf.to_string_lossy());
    fs::write(&runtime_backup, &runtime_content).map_err(|e| format!("backup: {}", e))?;
    fs::write(&nginx_backup, &nginx_content).map_err(|e| format!("backup: {}", e))?;

    let mut new_runtime_content = runtime_content.clone();
    let mut new_nginx_content = nginx_content.clone();
    for (key, _, old_path, new_path) in &updates {
        new_runtime_content = replace_config_value(&new_runtime_content, key, new_path)?;
        new_nginx_content = replace_nginx_cert_value(&new_nginx_content, key, old_path, new_path)?;
    }

    fs::write(&cfg.config_file, &new_runtime_content)
        .map_err(|e| format!("write config: {}", e))?;
    fs::write(&cfg.conf, &new_nginx_content).map_err(|e| format!("write nginx config: {}", e))?;

    if let Err(e) = nginx_test(lang) {
        restore_file(&runtime_backup, &cfg.config_file)?;
        restore_file(&nginx_backup, &cfg.conf)?;
        return Err(msg_fmt_backup(lang, &runtime_backup, &e));
    }

    reload_nginx();

    println!("{}", msg(MsgKey::CertSetSuccess, lang));
    print_kv(msg(MsgKey::RuntimeConfig, lang), &runtime_backup);
    print_kv(msg(MsgKey::ConfigFile, lang), &nginx_backup);
    for (_, label, old_path, new_path) in &updates {
        print_kv(label, &format!("{} -> {}", old_path, new_path));
    }

    Ok(())
}

pub fn validate(cfg: &Config, lang: Lang) -> Result<(), String> {
    print_kv_state(
        msg(MsgKey::CertSetCertLabel, lang),
        &cfg.cert_file.to_string_lossy(),
        &read_state(&cfg.cert_file, lang),
    );
    print_kv_state(
        msg(MsgKey::CertSetKeyLabel, lang),
        &cfg.key_file.to_string_lossy(),
        &read_state(&cfg.key_file, lang),
    );
    nginx_test(lang)
}

pub fn reload(cfg: &Config, lang: Lang) -> Result<(), String> {
    need_root(lang)?;
    validate(cfg, lang)?;
    reload_nginx();
    println!("{}", msg(MsgKey::ReloadOk, lang));
    Ok(())
}

fn backup_path(path: &str) -> String {
    let ts = chrono::Local::now().format("%Y%m%d%H%M%S");
    format!("{}.bak-{}", path, ts)
}

fn replace_config_value(content: &str, key: &str, value: &str) -> Result<String, String> {
    let pattern = format!(r"(?m)^{}='.*'$", regex::escape(key));
    let re = Regex::new(&pattern).map_err(|e| format!("regex: {}", e))?;
    let new_line = format!("{}='{}'", key, value);
    if re.is_match(content) {
        Ok(re.replace(content, new_line.as_str()).to_string())
    } else {
        Ok(format!("{}\n{}", content.trim_end(), new_line))
    }
}

fn replace_nginx_cert_value(
    content: &str,
    key: &str,
    old_path: &str,
    new_path: &str,
) -> Result<String, String> {
    let directive = match key {
        "CERT_FILE" => "ssl_certificate",
        "KEY_FILE" => "ssl_certificate_key",
        _ => return Ok(content.to_string()),
    };
    let pattern = format!(r"(?m)^(\s*{}\s+).+;$", directive);
    let re = Regex::new(&pattern).map_err(|e| format!("regex: {}", e))?;
    if re.is_match(content) {
        Ok(re
            .replace(content, format!("${{1}}{};", new_path).as_str())
            .to_string())
    } else {
        Ok(content.replace(old_path, new_path))
    }
}

fn msg_fmt_backup(lang: Lang, backup_path: &str, err: &str) -> String {
    format!(
        "{} ({})",
        crate::i18n::msg_fmt(MsgKey::CertSetRollback, lang, backup_path),
        err
    )
}

fn nginx_test(lang: Lang) -> Result<(), String> {
    let output = Command::new("nginx")
        .arg("-t")
        .output()
        .map_err(|e| format!("nginx: {}", e))?;

    if output.status.success() {
        print_kv(msg(MsgKey::NginxTest, lang), msg(MsgKey::OkFile, lang));
        Ok(())
    } else {
        eprintln!("{}", String::from_utf8_lossy(&output.stderr));
        Err(msg(MsgKey::NginxTestFailed, lang).to_string())
    }
}

fn restore_file(backup_path: &str, path: &Path) -> Result<(), String> {
    fs::copy(backup_path, path).map_err(|_| "rollback failed".to_string())?;
    Ok(())
}

fn reload_nginx() {
    if Command::new("systemctl")
        .args(["reload", "nginx"])
        .status()
        .is_err()
    {
        let _ = Command::new("nginx").args(["-s", "reload"]).status();
    }
}
