use crate::i18n::{msg, Lang, MsgKey};

pub fn run(_lang: Lang) {
    let local = chrono::Local::now();
    let utc = chrono::Utc::now();
    let hostname = nix::sys::utsname::uname()
        .map(|u| u.nodename().to_string_lossy().to_string())
        .unwrap_or_else(|_| "unknown".to_string());

    println!(
        "{:<15}: {}",
        msg(MsgKey::HostTime, _lang),
        local.format("%Y-%m-%d %H:%M:%S %Z (%z)")
    );
    println!(
        "{:<15}: {}",
        msg(MsgKey::UtcTime, _lang),
        utc.format("%Y-%m-%d %H:%M:%S UTC")
    );
    println!("{:<15}: {}", msg(MsgKey::HostName, _lang), hostname);
}
