use crate::config::Config;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{path_state, print_kv, read_state};
use std::fs;

pub fn run(cfg: &Config, lang: Lang) {
    print_kv(
        msg(MsgKey::RuntimeConfig, lang),
        &format!(
            "{} ({}, {})",
            cfg.config_file.to_string_lossy(),
            path_state(&cfg.config_file, lang),
            read_state(&cfg.config_file, lang)
        ),
    );
    if cfg.config_file.is_file() {
        println!();
        println!("{}:", msg(MsgKey::ConfigDump, lang));
        if let Ok(content) = fs::read_to_string(&cfg.config_file) {
            for line in content.lines().take(240) {
                println!("{}", line);
            }
        }
    }
}
