use crate::config::Config;
use crate::http::{build_client, http_code};
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{auth_user, need_command, need_root, print_kv, set_auth_file_permissions};
use dialoguer::{Input, Password};
use rand::Rng;
use std::fs;
use std::io::IsTerminal;
use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::process::Command;

pub async fn run(
    cfg: &Config,
    user_arg: Option<&str>,
    password_arg: Option<&str>,
    lang: Lang,
) -> Result<(), String> {
    need_root(lang)?;
    need_command("openssl", lang)?;

    let current_user = auth_user(&cfg.auth_file);
    let mut user = user_arg
        .map(|s| s.to_string())
        .or_else(|| current_user.clone())
        .unwrap_or_else(|| "uploader".to_string());
    let mut password = password_arg.map(|s| s.to_string()).unwrap_or_default();

    // Interactive prompts if TTY
    let is_tty = std::io::stdin().is_terminal();

    if is_tty {
        if user_arg.is_none() {
            let prompt = format!("{} [{}]: ", msg(MsgKey::PasswdUserPrompt, lang), user);
            if let Ok(input) = Input::<String>::new()
                .with_prompt(&prompt)
                .default(user.clone())
                .interact_text()
            {
                if !input.is_empty() {
                    user = input;
                }
            }
        }

        if password_arg.is_none() {
            let prompt = format!("{}: ", msg(MsgKey::PasswdNewPrompt, lang));
            if let Ok(p) = Password::new().with_prompt(&prompt).interact() {
                if !p.is_empty() {
                    let confirm_prompt = format!("{}: ", msg(MsgKey::PasswdConfirm, lang));
                    if let Ok(p2) = Password::new().with_prompt(&confirm_prompt).interact() {
                        if p != p2 {
                            eprintln!("{}", msg(MsgKey::PasswdMismatch, lang));
                            return Err("password mismatch".to_string());
                        }
                    }
                    password = p;
                }
            }
        }
    }

    if password.is_empty() {
        password = rand::thread_rng()
            .sample_iter(&rand::distributions::Alphanumeric)
            .take(20)
            .map(|c| c as char)
            .filter(|c| c.is_ascii_alphanumeric())
            .take(20)
            .collect::<String>();
        if password.len() < 20 {
            password = (0..20)
                .map(|_| rand::thread_rng().sample(rand::distributions::Alphanumeric) as char)
                .filter(|c| c.is_ascii_alphanumeric())
                .take(20)
                .collect();
        }
    }

    // Backup existing auth file
    let backup = if cfg.auth_file.is_file() {
        let ts = chrono::Local::now().format("%Y%m%d%H%M%S");
        let backup_path = format!("{}.bak-{}", cfg.auth_file.to_string_lossy(), ts);
        fs::copy(&cfg.auth_file, &backup_path).map_err(|e| format!("backup: {}", e))?;
        Some(backup_path)
    } else {
        if let Some(parent) = cfg.auth_file.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("mkdir: {}", e))?;
        }
        None
    };

    // Generate APR1 hash
    let hash = openssl_passwd_apr1(&password)?;

    // Write auth file
    {
        let mut file =
            fs::File::create(&cfg.auth_file).map_err(|e| format!("create auth file: {}", e))?;
        writeln!(file, "{}:{}", user, hash).map_err(|e| format!("write auth file: {}", e))?;
    }

    // Set permissions
    set_auth_file_permissions(&cfg.auth_file, &cfg.tfw_user)?;

    // Verify format
    if !verify_auth_format(&cfg.auth_file) {
        // Rollback
        if let Some(ref backup_path) = backup {
            fs::copy(backup_path, &cfg.auth_file).map_err(|_| ()).ok();
        } else {
            fs::remove_file(&cfg.auth_file).ok();
        }
        eprintln!("{}", msg(MsgKey::PasswdVerifyFail, lang));
        return Err("auth file format invalid".to_string());
    }

    // Remote verify
    let client = build_client(cfg).map_err(|_| "http client error".to_string())?;
    let urls = crate::config::Urls::from_config(cfg);
    let code = http_code(
        &client,
        &urls.url_session_login,
        Some(&format!("{}:{}", user, password)),
        "POST",
    )
    .await;

    print_kv(msg(MsgKey::AuthUserLabel, lang), &user);
    println!("password        : {}", password);
    print_kv(
        msg(MsgKey::Backup, lang),
        &backup.unwrap_or_else(|| msg(MsgKey::None_, lang).to_string()),
    );
    print_kv(msg(MsgKey::LocalVerify, lang), msg(MsgKey::OkFile, lang));
    print_kv(msg(MsgKey::RemoteVerify, lang), &code);

    Ok(())
}

fn openssl_passwd_apr1(password: &str) -> Result<String, String> {
    let output = Command::new("openssl")
        .args(["passwd", "-apr1"])
        .arg(password)
        .output()
        .map_err(|e| format!("openssl: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(format!(
            "openssl passwd failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

fn verify_auth_format(path: &Path) -> bool {
    if let Ok(file) = fs::File::open(path) {
        let reader = BufReader::new(file);
        for line in reader.lines().flatten() {
            let parts: Vec<&str> = line.splitn(2, ':').collect();
            if parts.len() >= 2 && !parts[0].is_empty() {
                return true;
            }
        }
    }
    false
}
