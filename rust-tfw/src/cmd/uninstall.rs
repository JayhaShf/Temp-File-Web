use crate::config::Config;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{need_root, print_kv};
use std::io::IsTerminal;
use std::path::Path;
use std::process::Command;

pub fn run(cfg: &Config, lang: Lang) -> Result<(), String> {
    let project_dir = cfg.tfw_project_dir.as_deref().unwrap_or("");

    if project_dir.is_empty() || !Path::new(project_dir).is_dir() {
        eprintln!("{}", msg(MsgKey::UninstallNoProject, lang));
        return Err("project not found".to_string());
    }

    let install_script = Path::new(project_dir).join("scripts").join("install.sh");
    if !install_script.is_file() {
        eprintln!("{}", msg(MsgKey::UninstallNoProject, lang));
        return Err("install.sh not found".to_string());
    }

    println!("{}", msg(MsgKey::UninstallTitle, lang));
    print_kv(
        msg(MsgKey::UninstallDataDir, lang),
        &cfg.data_dir.to_string_lossy(),
    );
    let certs_dir = cfg.site_dir.join("certs");
    print_kv(
        msg(MsgKey::UninstallCertsDir, lang),
        &certs_dir.to_string_lossy(),
    );
    println!();

    // Confirm
    let is_tty = std::io::stdin().is_terminal();
    if is_tty {
        if !confirm(msg(MsgKey::UninstallConfirm, lang), false) {
            println!("{}", msg(MsgKey::UninstallAborted, lang));
            return Ok(());
        }
    }

    let keep_data = confirm(msg(MsgKey::UninstallKeepData, lang), true);
    let keep_certs = confirm(msg(MsgKey::UninstallKeepCerts, lang), true);

    need_root(lang)?;

    let status = Command::new("bash")
        .arg(&install_script)
        .arg("uninstall")
        .env("UNINSTALL_KEEP_DATA", if keep_data { "1" } else { "0" })
        .env("UNINSTALL_KEEP_CERTS", if keep_certs { "1" } else { "0" })
        .env("LANGUAGE", &cfg.language)
        .status()
        .map_err(|e| format!("bash: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err("uninstall failed".to_string())
    }
}

fn confirm(prompt: &str, default: bool) -> bool {
    if !std::io::stdin().is_terminal() {
        return default;
    }
    use dialoguer::Confirm;
    Confirm::new()
        .with_prompt(prompt)
        .default(default)
        .interact()
        .unwrap_or(default)
}
