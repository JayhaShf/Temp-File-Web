use crate::config::Config;
use crate::i18n::{msg, msg_fmt, Lang, MsgKey};
use crate::util::{print_kv, resolve_dir};
use std::path::Path;
use std::process::Command;

pub fn run(cfg: &Config, target: &str, lang: Lang) -> Result<(), String> {
    let dir = resolve_dir(target, &cfg.data_dir, &cfg.upload_dir)?;
    let dir_path = Path::new(&dir);

    if !dir_path.is_dir() {
        eprintln!("{}", msg_fmt(MsgKey::DirNotFound, lang, &dir));
        return Err("directory not found".to_string());
    }

    print_kv(msg(MsgKey::Directory, lang), &dir);

    let status = Command::new("ls")
        .arg("-lah")
        .arg(dir_path)
        .status()
        .map_err(|e| format!("ls: {}", e))?;

    if !status.success() {
        return Err("ls failed".to_string());
    }
    Ok(())
}
