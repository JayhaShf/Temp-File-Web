use crate::i18n::{msg_fmt, Lang, MsgKey};
use std::process::Command;

pub fn run(lang: Lang) -> Result<(), String> {
    let status = Command::new("nginx")
        .arg("-t")
        .status()
        .map_err(|_| msg_fmt(MsgKey::MissingCommand, lang, "nginx"))?;

    if status.success() {
        Ok(())
    } else {
        Err("nginx -t failed".to_string())
    }
}
