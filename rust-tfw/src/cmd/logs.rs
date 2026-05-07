use crate::config::Config;
use crate::i18n::{msg, msg_fmt, Lang, MsgKey};
use crate::util::{print_kv, tail_file};

pub fn run(cfg: &Config, target: &str, lines: u32, lang: Lang) -> Result<(), String> {
    match target {
        "access" => show_single_log(&cfg.access_log, "access", lines, lang)?,
        "error" => show_single_log(&cfg.error_log, "error", lines, lang)?,
        "all" => {
            show_single_log(&cfg.access_log, "access", lines, lang).ok();
            println!();
            show_single_log(&cfg.error_log, "error", lines, lang).ok();
        }
        _ => {
            eprintln!("{}", msg_fmt(MsgKey::UnknownLogTarget, lang, target));
            eprintln!("{}", msg(MsgKey::LogsUsage, lang));
            return Err("unknown log target".to_string());
        }
    }
    Ok(())
}

fn show_single_log(
    path: &std::path::Path,
    _name: &str,
    lines: u32,
    _lang: Lang,
) -> Result<(), String> {
    if !path.is_file() {
        eprintln!(
            "{}",
            msg_fmt(MsgKey::LogNotFound, _lang, &path.to_string_lossy())
        );
        return Err("log not found".to_string());
    }

    print_kv(msg(MsgKey::LogFile, _lang), &path.to_string_lossy());
    print_kv(msg(MsgKey::Lines, _lang), &lines.to_string());

    let tail_lines = tail_file(path, lines as usize)?;
    for line in tail_lines {
        println!("{}", line);
    }
    Ok(())
}
