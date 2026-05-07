use crate::config::Config;
use crate::i18n::Lang;
use crate::util::need_root;
use std::path::Path;
use std::process::Command;

pub fn run(cfg: &Config, check: bool, pull: bool, lang: Lang) -> Result<(), String> {
    let project_dir = cfg
        .tfw_project_dir
        .as_deref()
        .ok_or("TFW_PROJECT_DIR not set.\nRun tfw update from within the project directory, or set TFW_PROJECT_DIR in /etc/tfw/tfw.conf.")?;

    let project_path = Path::new(project_dir);
    if !project_path.is_dir() {
        return Err(format!("Project directory not found: {}", project_dir));
    }

    let install_script = project_path.join("scripts").join("install.sh");
    if !install_script.is_file() {
        return Err(format!(
            "install.sh not found in project directory: {}",
            install_script.display()
        ));
    }

    if check {
        update_check(project_path)
    } else if pull {
        update_pull(project_path, &install_script, lang)
    } else {
        // No flag: run upgrade
        need_root(lang)?;
        println!("Running upgrade from {}...", project_dir);
        let status = Command::new("bash")
            .arg(&install_script)
            .arg("upgrade")
            .env("LANGUAGE", &cfg.language)
            .status()
            .map_err(|e| format!("bash: {}", e))?;
        if status.success() {
            Ok(())
        } else {
            Err("upgrade failed".to_string())
        }
    }
}

fn update_check(project_path: &Path) -> Result<(), String> {
    let git_dir = project_path.join(".git");
    if !git_dir.is_dir() {
        return Err(format!(
            "{} is not a git repository.",
            project_path.display()
        ));
    }

    println!("Fetching from origin...");
    let status = Command::new("git")
        .current_dir(project_path)
        .args(["fetch", "origin"])
        .status()
        .map_err(|_| "git not found; cannot check for updates.".to_string())?;

    if !status.success() {
        return Err("Fetch failed.".to_string());
    }

    let output = Command::new("git")
        .current_dir(project_path)
        .args(["rev-list", "HEAD..origin/main", "--count"])
        .output()
        .map_err(|_| "git not found".to_string())?;

    let behind = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if behind == "0" {
        println!("Already up to date.");
    } else {
        println!("{} commit(s) behind origin/main.", behind);
        println!("Run 'tfw update --pull' to apply updates.");
    }
    Ok(())
}

fn update_pull(project_path: &Path, install_script: &Path, lang: Lang) -> Result<(), String> {
    let git_dir = project_path.join(".git");
    if !git_dir.is_dir() {
        return Err(format!(
            "{} is not a git repository.",
            project_path.display()
        ));
    }

    // Check for local modifications
    let status_output = Command::new("git")
        .current_dir(project_path)
        .args(["status", "--porcelain"])
        .output()
        .map_err(|_| "git not found; cannot pull updates.".to_string())?;

    if !String::from_utf8_lossy(&status_output.stdout)
        .trim()
        .is_empty()
    {
        println!(
            "WARNING: Local modifications detected. Pull may cause conflicts.\nContinue? [y/N]"
        );
        let mut answer = String::new();
        std::io::stdin().read_line(&mut answer).ok();
        let answer = answer.trim();
        if answer != "y" && answer != "Y" {
            println!("Aborted.");
            return Ok(());
        }
    }

    println!("Pulling from origin/main...");
    let status = Command::new("git")
        .current_dir(project_path)
        .args(["pull", "origin", "main"])
        .status()
        .map_err(|_| "git not found".to_string())?;

    if !status.success() {
        return Err("Pull failed.".to_string());
    }

    println!("Pull complete. Running upgrade...");
    need_root(lang)?;

    let status = Command::new("bash")
        .arg(install_script)
        .arg("upgrade")
        .env("LANGUAGE", if lang == Lang::Zh { "zh" } else { "en" })
        .status()
        .map_err(|e| format!("bash: {}", e))?;

    if status.success() {
        println!("Update complete.");
        Ok(())
    } else {
        Err("upgrade failed".to_string())
    }
}
