use crate::cmd::status;
use crate::config::Config;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::need_root;
use std::process::Command;
use std::thread;
use std::time::Duration;

pub async fn run(cfg: &Config, lang: Lang) -> Result<(), String> {
    need_root(lang)?;

    let nginx_output = Command::new("nginx")
        .arg("-t")
        .output()
        .map_err(|_| "nginx not found".to_string())?;

    // nginx -t prints to stderr
    if !nginx_output.status.success() {
        eprint!("{}", String::from_utf8_lossy(&nginx_output.stderr));
        return Err("nginx -t failed".to_string());
    }

    if Command::new("systemctl").arg("--version").output().is_ok() {
        if Command::new("systemctl")
            .args(["restart", "nginx"])
            .status()
            .is_ok()
        {
            println!(
                "{:<15}: {}",
                msg(MsgKey::RestartSystemctl, lang),
                msg(MsgKey::RestartOk, lang)
            );
        } else {
            Command::new("nginx").arg("-s").arg("reload").status().ok();
            println!(
                "{:<15}: {}",
                msg(MsgKey::RestartReload, lang),
                msg(MsgKey::ReloadOk, lang)
            );
        }
    } else {
        Command::new("nginx").arg("-s").arg("reload").status().ok();
        println!(
            "{:<15}: {}",
            msg(MsgKey::RestartReload, lang),
            msg(MsgKey::ReloadOk, lang)
        );
    }

    thread::sleep(Duration::from_secs(1));
    status::run(cfg, lang).await
}
