use crate::config::Config;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{
    auth_user, free_space, path_state, print_kv, print_kv_state, read_state, write_state,
};

pub fn run(cfg: &Config, lang: Lang) {
    let au = auth_user(&cfg.auth_file).unwrap_or_else(|| msg(MsgKey::None_, lang).to_string());

    print_kv(
        msg(MsgKey::RuntimeConfig, lang),
        &format!(
            "{} ({}, {})",
            cfg.config_file.to_string_lossy(),
            path_state(&cfg.config_file, lang),
            read_state(&cfg.config_file, lang)
        ),
    );
    print_kv_state(
        msg(MsgKey::ConfigFile, lang),
        &cfg.conf.to_string_lossy(),
        &read_state(&cfg.conf, lang),
    );
    print_kv_state(
        msg(MsgKey::SiteDir, lang),
        &cfg.site_dir.to_string_lossy(),
        &path_state(&cfg.site_dir, lang),
    );
    print_kv(
        msg(MsgKey::DataDir, lang),
        &format!(
            "{} ({}, {})",
            cfg.data_dir.to_string_lossy(),
            path_state(&cfg.data_dir, lang),
            write_state(&cfg.data_dir, lang)
        ),
    );
    print_kv(
        msg(MsgKey::UploadDir, lang),
        &format!(
            "{} ({}, {})",
            cfg.upload_dir.to_string_lossy(),
            path_state(&cfg.upload_dir, lang),
            write_state(&cfg.upload_dir, lang)
        ),
    );
    print_kv(
        msg(MsgKey::AuthFile, lang),
        &format!(
            "{} ({}, {})",
            cfg.auth_file.to_string_lossy(),
            path_state(&cfg.auth_file, lang),
            read_state(&cfg.auth_file, lang)
        ),
    );
    print_kv(
        msg(MsgKey::BrowserHtml, lang),
        &format!(
            "{} ({}, {})",
            cfg.browser_html.to_string_lossy(),
            path_state(&cfg.browser_html, lang),
            read_state(&cfg.browser_html, lang)
        ),
    );
    print_kv(
        msg(MsgKey::UploadHtml, lang),
        &format!(
            "{} ({}, {})",
            cfg.upload_html.to_string_lossy(),
            path_state(&cfg.upload_html, lang),
            read_state(&cfg.upload_html, lang)
        ),
    );
    print_kv_state(
        msg(MsgKey::CertFile, lang),
        &cfg.cert_file.to_string_lossy(),
        &read_state(&cfg.cert_file, lang),
    );
    print_kv_state(
        msg(MsgKey::KeyFile, lang),
        &cfg.key_file.to_string_lossy(),
        &read_state(&cfg.key_file, lang),
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
    print_kv(msg(MsgKey::FreeSpace, lang), &free_space(&cfg.data_dir));
}
