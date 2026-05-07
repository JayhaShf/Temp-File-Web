mod cmd;
mod config;
mod http;
mod i18n;
mod util;

use clap::{Parser, Subcommand};
use config::Config;
use i18n::{msg, Lang, MsgKey};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "tfw", version, disable_help_subcommand = true)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand)]
enum Command {
    /// Show host time
    Time,

    /// Show config paths and local files
    Info,

    /// Show public URLs
    Urls,

    /// Show or configure certificate paths
    Cert {
        #[command(subcommand)]
        action: Option<CertAction>,
    },

    /// Run nginx and HTTP checks
    Status,

    /// Check upload auth endpoints
    Auth {
        user: Option<String>,
        password: Option<String>,
    },

    /// Print current runtime config content
    Config,

    /// Check local config, permissions and key paths
    Doctor,

    /// Run nginx -t
    Test,

    /// List files in a directory
    Ls { target: Option<String> },

    /// Tail logs
    Logs {
        target: Option<String>,
        lines: Option<u32>,
    },

    /// Test and restart/reload nginx
    Restart,

    /// Rotate upload auth password
    Passwd {
        user: Option<String>,
        password: Option<String>,
    },

    /// View or rotate session token
    Session {
        #[arg(default_value = "show")]
        action: String,
    },

    /// Check or pull updates
    Update {
        #[arg(long)]
        check: bool,
        #[arg(long)]
        pull: bool,
    },

    /// Interactive uninstall
    Uninstall,

    /// Show help
    Help,
}

#[derive(Subcommand)]
enum CertAction {
    /// Show current certificate paths (default)
    Show,
    /// Set certificate and/or private key path
    Set {
        #[arg(long)]
        cert: Option<String>,
        #[arg(long)]
        key: Option<String>,
    },
    /// Validate certificate paths and nginx config
    Validate,
    /// Validate certificate paths and reload nginx
    Reload,
    /// Set certificate file path
    SetCert { path: String },
    /// Set private key file path
    SetKey { path: String },
}

fn config_path() -> PathBuf {
    std::env::var("TFW_CONFIG")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/etc/tfw/tfw.conf"))
}

fn print_usage(lang: Lang) {
    let lines = [
        format!(
            "tfw time                         {}",
            msg(MsgKey::HelpTime, lang)
        ),
        format!(
            "tfw info                         {}",
            msg(MsgKey::HelpInfo, lang)
        ),
        format!(
            "tfw urls                         {}",
            msg(MsgKey::HelpUrls, lang)
        ),
        format!(
            "tfw cert                         {}",
            msg(MsgKey::HelpCert, lang)
        ),
        format!(
            "tfw status                       {}",
            msg(MsgKey::HelpStatus, lang)
        ),
        format!(
            "tfw auth [user] [password]       {}",
            msg(MsgKey::HelpAuth, lang)
        ),
        format!(
            "tfw config                       {}",
            msg(MsgKey::HelpConfigCmd, lang)
        ),
        format!(
            "tfw doctor                       {}",
            msg(MsgKey::HelpDoctor, lang)
        ),
        format!(
            "tfw test                         {}",
            msg(MsgKey::HelpTest, lang)
        ),
        format!(
            "tfw ls [root|uploads|/path]      {}",
            msg(MsgKey::HelpLs, lang)
        ),
        format!(
            "tfw logs [access|error|all] [lines]  {}",
            msg(MsgKey::HelpLogs, lang)
        ),
        format!(
            "tfw restart                      {}",
            msg(MsgKey::HelpRestart, lang)
        ),
        format!(
            "tfw passwd [user] [password]     {}",
            msg(MsgKey::HelpPasswd, lang)
        ),
        format!(""),
        format!(
            "tfw session [rotate|show]        {}",
            msg(MsgKey::HelpSession, lang)
        ),
        format!(
            "tfw update [--check|--pull]      {}",
            msg(MsgKey::HelpUpdate, lang)
        ),
        format!(
            "tfw uninstall                    {}",
            msg(MsgKey::HelpUninstall, lang)
        ),
        format!("{}:", msg(MsgKey::HelpConfig, lang)),
        format!(
            "  {}: /etc/tfw/tfw.conf",
            msg(MsgKey::HelpDefaultConfig, lang)
        ),
        format!(
            "  {}: TFW_CONFIG=/path/to/tfw.conf tfw info",
            msg(MsgKey::HelpOverride, lang)
        ),
    ];
    for line in &lines {
        println!("{}", line);
    }
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let cfg = Config::from_file(&config_path());
    let lang = Lang::from_str(&cfg.language);

    let result = match cli.command {
        None | Some(Command::Help) => {
            print_usage(lang);
            Ok(())
        }
        Some(Command::Time) => {
            cmd::time::run(lang);
            Ok(())
        }
        Some(Command::Info) => {
            cmd::info::run(&cfg, lang);
            Ok(())
        }
        Some(Command::Urls) => {
            cmd::urls::run(&config::Urls::from_config(&cfg), &cfg.project_url, lang);
            Ok(())
        }
        Some(Command::Cert { action }) => match action.unwrap_or(CertAction::Show) {
            CertAction::Show => {
                cmd::cert::show(&cfg, lang);
                Ok(())
            }
            CertAction::Set { cert, key } => {
                cmd::cert::set(&cfg, cert.as_deref(), key.as_deref(), lang)
            }
            CertAction::Validate => cmd::cert::validate(&cfg, lang),
            CertAction::Reload => cmd::cert::reload(&cfg, lang),
            CertAction::SetCert { path } => cmd::cert::set(&cfg, Some(&path), None, lang),
            CertAction::SetKey { path } => cmd::cert::set(&cfg, None, Some(&path), lang),
        },
        Some(Command::Status) => cmd::status::run(&cfg, lang).await,
        Some(Command::Auth { user, password }) => {
            cmd::auth::run(&cfg, user.as_deref(), password.as_deref(), lang).await
        }
        Some(Command::Config) => {
            cmd::config_cmd::run(&cfg, lang);
            Ok(())
        }
        Some(Command::Doctor) => {
            cmd::doctor::run(&cfg, lang);
            Ok(())
        }
        Some(Command::Test) => cmd::test::run(lang),
        Some(Command::Ls { target }) => {
            let t = target.unwrap_or_else(|| "root".to_string());
            cmd::ls::run(&cfg, &t, lang)
        }
        Some(Command::Logs { target, lines }) => {
            let t = target.unwrap_or_else(|| "access".to_string());
            let n = lines.unwrap_or(50);
            cmd::logs::run(&cfg, &t, n, lang)
        }
        Some(Command::Restart) => cmd::restart::run(&cfg, lang).await,
        Some(Command::Passwd { user, password }) => {
            cmd::passwd::run(&cfg, user.as_deref(), password.as_deref(), lang).await
        }
        Some(Command::Session { action }) => cmd::session::run(&cfg, &action, lang),
        Some(Command::Update { check, pull }) => cmd::update::run(&cfg, check, pull, lang),
        Some(Command::Uninstall) => cmd::uninstall::run(&cfg, lang),
    };

    if let Err(e) = result {
        eprintln!("{}", e);
        std::process::exit(1);
    }
}
