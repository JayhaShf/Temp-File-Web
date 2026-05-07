use crate::config::Config;
use crate::http::{build_client, http_code};
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::{auth_user, path_state, print_kv, read_state};

pub async fn run(
    cfg: &Config,
    user: Option<&str>,
    password: Option<&str>,
    lang: Lang,
) -> Result<(), String> {
    let client = build_client(cfg).map_err(|e| format!("http client: {}", e))?;
    let urls = crate::config::Urls::from_config(cfg);

    let au = auth_user(&cfg.auth_file).unwrap_or_else(|| msg(MsgKey::None_, lang).to_string());

    let session_code = http_code(&client, &urls.url_session_status, None, "GET").await;
    let upload_api_url = format!(
        "{}://{}/_upload_api/.tfw-auth-probe",
        urls.url_scheme, urls.url_authority
    );
    let upload_api_code = http_code(&client, &upload_api_url, None, "OPTIONS").await;

    let invalid_code = if !au.is_empty() && au != msg(MsgKey::None_, lang) {
        http_code(
            &client,
            &urls.url_session_login,
            Some(&format!("{}:__tfw_invalid_password__", au)),
            "POST",
        )
        .await
    } else {
        msg(MsgKey::None_, lang).to_string()
    };

    let valid_code = if let (Some(u), Some(p)) = (user, password) {
        if !u.is_empty() && !p.is_empty() {
            http_code(
                &client,
                &urls.url_session_login,
                Some(&format!("{}:{}", u, p)),
                "POST",
            )
            .await
        } else {
            msg(MsgKey::None_, lang).to_string()
        }
    } else {
        msg(MsgKey::None_, lang).to_string()
    };

    print_kv(msg(MsgKey::AuthCurrent, lang), &au);
    print_kv(
        msg(MsgKey::AuthFile, lang),
        &format!(
            "{} ({}, {})",
            cfg.auth_file.to_string_lossy(),
            path_state(&cfg.auth_file, lang),
            read_state(&cfg.auth_file, lang)
        ),
    );
    print_kv(msg(MsgKey::AuthEndpoint, lang), &urls.url_session_login);
    print_kv(msg(MsgKey::SessionStatus, lang), &session_code);
    print_kv(msg(MsgKey::AuthInvalid, lang), &invalid_code);
    print_kv(msg(MsgKey::AuthValid, lang), &valid_code);
    print_kv(msg(MsgKey::UploadApiOptions, lang), &upload_api_code);

    Ok(())
}
