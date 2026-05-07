use crate::i18n::{msg, msg_fmt, Lang, MsgKey};
use std::fs;
use std::io::{BufRead, BufReader};
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

pub fn path_state(path: &Path, lang: Lang) -> String {
    if path.is_dir() {
        msg(MsgKey::OkDir, lang).to_string()
    } else if path.is_file() {
        msg(MsgKey::OkFile, lang).to_string()
    } else {
        msg(MsgKey::Missing, lang).to_string()
    }
}

pub fn write_state(path: &Path, lang: Lang) -> String {
    if path.is_dir()
        && !fs::metadata(path)
            .map(|m| m.permissions().readonly())
            .unwrap_or(true)
    {
        msg(MsgKey::OkWritable, lang).to_string()
    } else if path.exists() {
        msg(MsgKey::Readonly, lang).to_string()
    } else {
        msg(MsgKey::Missing, lang).to_string()
    }
}

pub fn read_state(path: &Path, lang: Lang) -> String {
    if path.exists()
        && fs::metadata(path)
            .map(|m| m.permissions().mode() & 0o444 != 0)
            .unwrap_or(false)
    {
        msg(MsgKey::OkReadable, lang).to_string()
    } else if path.exists() {
        msg(MsgKey::Unreadable, lang).to_string()
    } else {
        msg(MsgKey::Missing, lang).to_string()
    }
}

pub fn print_kv(key: &str, value: &str) {
    println!("{:<15}: {}", key, value);
}

pub fn print_kv_state(key: &str, value: &str, state: &str) {
    println!("{:<15}: {} ({})", key, value, state);
}

pub fn count_entries(dir: &Path, kind: &str) -> u64 {
    if !dir.is_dir() {
        return 0;
    }
    match fs::read_dir(dir) {
        Ok(entries) => {
            if kind == "files" {
                entries
                    .filter_map(|e| e.ok())
                    .filter(|e| e.file_type().map(|t| t.is_file()).unwrap_or(false))
                    .count() as u64
            } else {
                entries.filter_map(|e| e.ok()).count() as u64
            }
        }
        Err(_) => 0,
    }
}

pub fn dir_size(dir: &Path) -> String {
    if !dir.is_dir() {
        return "0".to_string();
    }
    match walkdir::WalkDir::new(dir)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        entries => {
            let total: u64 = entries
                .filter_map(|e| e.metadata().ok())
                .map(|m| m.len())
                .sum();
            human_size(total)
        }
    }
}

fn human_size(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "K", "M", "G", "T"];
    let mut size = bytes as f64;
    let mut unit = 0;
    while size >= 1024.0 && unit < UNITS.len() - 1 {
        size /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{}", bytes)
    } else if size < 10.0 {
        format!("{:.1}{}", size, UNITS[unit])
    } else {
        format!("{:.0}{}", size, UNITS[unit])
    }
}

pub fn free_space(path: &Path) -> String {
    let target = if path.exists() {
        path
    } else {
        path.parent().unwrap_or(Path::new("/"))
    };
    nix::sys::statvfs::statvfs(target)
        .map(|s| {
            let avail = s.block_size() * s.blocks_available();
            human_size(avail)
        })
        .unwrap_or_else(|_| "-".to_string())
}

pub fn resolve_dir(target: &str, data_dir: &Path, upload_dir: &Path) -> Result<String, String> {
    match target {
        "" | "root" => Ok(data_dir.to_string_lossy().to_string()),
        "upload" | "uploads" => Ok(upload_dir.to_string_lossy().to_string()),
        p if p.starts_with('/') => Ok(p.to_string()),
        p => Ok(p.to_string()),
    }
}

pub fn auth_user(auth_file: &Path) -> Option<String> {
    if !auth_file.is_file() {
        return None;
    }
    let file = fs::File::open(auth_file).ok()?;
    let reader = BufReader::new(file);
    for line in reader.lines().flatten() {
        if let Some(colon) = line.find(':') {
            if colon > 0 {
                return Some(line[..colon].to_string());
            }
        }
    }
    None
}

pub fn set_auth_file_permissions(auth_file: &Path, tfw_user: &str) -> Result<(), String> {
    let mut perms = fs::metadata(auth_file)
        .map_err(|e| format!("stat auth file: {}", e))?
        .permissions();
    perms.set_mode(0o640);
    fs::set_permissions(auth_file, perms).map_err(|e| format!("chmod: {}", e))?;

    nix::unistd::chown(
        auth_file,
        Some(nix::unistd::Uid::from_raw(0)),
        nix::unistd::Group::from_name(tfw_user)
            .map_err(|e| format!("group lookup: {}", e))?
            .map(|g| g.gid)
            .or_else(|| {
                nix::unistd::Group::from_name("root")
                    .unwrap()
                    .map(|g| g.gid)
            }),
    )
    .map_err(|e| format!("chown: {}", e))?;

    Ok(())
}

pub fn need_root(lang: Lang) -> Result<(), String> {
    if nix::unistd::getuid().is_root() {
        Ok(())
    } else {
        Err(msg(MsgKey::NeedRoot, lang).to_string())
    }
}

pub fn need_command(cmd: &str, lang: Lang) -> Result<(), String> {
    which::which(cmd)
        .map(|_| ())
        .map_err(|_| msg_fmt(MsgKey::MissingCommand, lang, cmd))
}

pub fn tail_file(path: &Path, n: usize) -> Result<Vec<String>, String> {
    let file = fs::File::open(path)
        .map_err(|_| msg_fmt(MsgKey::LogNotFound, Lang::En, &path.to_string_lossy()))?;
    let reader = BufReader::new(file);
    let lines: Vec<String> = reader.lines().filter_map(|l| l.ok()).collect();
    let start = if lines.len() > n { lines.len() - n } else { 0 };
    Ok(lines[start..].to_vec())
}
