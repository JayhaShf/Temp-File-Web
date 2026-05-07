use crate::cmd::urls;
use crate::config::Config;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{auth_user, path_state, print_kv, print_kv_state};

pub fn run(cfg: &Config, lang: Lang) {
    let acme_text = if cfg.install_acme == "1" {
        msg(MsgKey::EnabledYes, lang)
    } else {
        msg(MsgKey::EnabledNo, lang)
    };
    let au = auth_user(&cfg.auth_file).unwrap_or_else(|| msg(MsgKey::None_, lang).to_string());

    print_kv(
        msg(MsgKey::RuntimeConfig, lang),
        &format!(
            "{} ({})",
            cfg.config_file.to_string_lossy(),
            path_state(&cfg.config_file, lang)
        ),
    );
    print_kv(msg(MsgKey::Language, lang), &cfg.language);
    print_kv(msg(MsgKey::SiteMode, lang), &cfg.site_mode);
    print_kv(msg(MsgKey::SiteTitle, lang), &cfg.site_title);
    print_kv(msg(MsgKey::ProjectUrl, lang), &cfg.project_url);
    print_kv(msg(MsgKey::SiteId, lang), &cfg.site_id);
    if !cfg.domain.is_empty() {
        print_kv(msg(MsgKey::Domain, lang), &cfg.domain);
    }
    print_kv(msg(MsgKey::AccessHost, lang), &cfg.access_host);
    print_kv(msg(MsgKey::HttpPort, lang), &cfg.http_port);
    print_kv(msg(MsgKey::HttpsPort, lang), &cfg.https_port);
    print_kv(msg(MsgKey::ResolveIp, lang), &cfg.ip);
    print_kv_state(
        msg(MsgKey::SiteDir, lang),
        &cfg.site_dir.to_string_lossy(),
        &path_state(&cfg.site_dir, lang),
    );
    print_kv_state(
        msg(MsgKey::ConfigFile, lang),
        &cfg.conf.to_string_lossy(),
        &path_state(&cfg.conf, lang),
    );
    print_kv_state(
        msg(MsgKey::AuthFile, lang),
        &cfg.auth_file.to_string_lossy(),
        &path_state(&cfg.auth_file, lang),
    );
    print_kv_state(
        msg(MsgKey::DataDir, lang),
        &cfg.data_dir.to_string_lossy(),
        &path_state(&cfg.data_dir, lang),
    );
    print_kv_state(
        msg(MsgKey::UploadDir, lang),
        &cfg.upload_dir.to_string_lossy(),
        &path_state(&cfg.upload_dir, lang),
    );
    print_kv_state(
        msg(MsgKey::BrowserHtml, lang),
        &cfg.browser_html.to_string_lossy(),
        &path_state(&cfg.browser_html, lang),
    );
    print_kv_state(
        msg(MsgKey::UploadHtml, lang),
        &cfg.upload_html.to_string_lossy(),
        &path_state(&cfg.upload_html, lang),
    );
    print_kv(msg(MsgKey::AcmeEnabled, lang), acme_text);
    if cfg.install_acme == "1" {
        print_kv_state(
            msg(MsgKey::AcmeWebroot, lang),
            &cfg.acme_webroot.to_string_lossy(),
            &path_state(&cfg.acme_webroot, lang),
        );
    }
    print_kv_state(
        msg(MsgKey::CertFile, lang),
        &cfg.cert_file.to_string_lossy(),
        &path_state(&cfg.cert_file, lang),
    );
    print_kv_state(
        msg(MsgKey::KeyFile, lang),
        &cfg.key_file.to_string_lossy(),
        &path_state(&cfg.key_file, lang),
    );
    print_kv_state(
        msg(MsgKey::AccessLog, lang),
        &cfg.access_log.to_string_lossy(),
        &path_state(&cfg.access_log, lang),
    );
    print_kv_state(
        msg(MsgKey::ErrorLog, lang),
        &cfg.error_log.to_string_lossy(),
        &path_state(&cfg.error_log, lang),
    );
    print_kv(msg(MsgKey::AuthUserLabel, lang), &au);
    println!();
    urls::run(
        &crate::config::Urls::from_config(cfg),
        &cfg.project_url,
        lang,
    );
}
