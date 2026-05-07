use crate::config::Config;
use crate::http::build_client;
use crate::i18n::{msg, Lang, MsgKey};
use crate::util::print_kv;
use std::process::Command;

pub async fn run(cfg: &Config, lang: Lang) -> Result<(), String> {
    let client = build_client(cfg).map_err(|e| format!("http client: {}", e))?;

    // nginx test
    let nginx_test_text = if Command::new("nginx")
        .arg("-t")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        msg(MsgKey::OkFile, lang)
    } else {
        msg(MsgKey::Fail, lang)
    };

    // nginx process
    let nginx_process_text =
        if let Ok(output) = Command::new("pgrep").args(["-x", "nginx"]).output() {
            if output.status.success() {
                let count = output.stdout.iter().filter(|&&b| b == b'\n').count();
                format!("{} ({})", msg(MsgKey::OkFile, lang), count)
            } else {
                msg(MsgKey::Fail, lang).to_string()
            }
        } else {
            msg(MsgKey::Unavailable, lang).to_string()
        };

    let au = crate::util::auth_user(&cfg.auth_file)
        .unwrap_or_else(|| msg(MsgKey::None_, lang).to_string());

    let urls = crate::config::Urls::from_config(cfg);

    // HTTP checks
    let root_code = crate::http::http_code(&client, &urls.url_root, None, "GET").await;
    let listing_code = crate::http::http_code(&client, &urls.url_listing, None, "GET").await;
    let upload_code = crate::http::http_code(&client, &urls.url_upload, None, "GET").await;
    let session_code = crate::http::http_code(&client, &urls.url_session_status, None, "GET").await;
    let upload_api_url = format!(
        "{}://{}/_upload_api/.tfw-status-probe",
        urls.url_scheme, urls.url_authority
    );
    let upload_api_code = crate::http::http_code(&client, &upload_api_url, None, "OPTIONS").await;

    let login_verify_code = if !au.is_empty() && au != msg(MsgKey::None_, lang) {
        crate::http::http_code(
            &client,
            &urls.url_session_login,
            Some(&format!("{}:__tfw_invalid_password__", au)),
            "POST",
        )
        .await
    } else {
        msg(MsgKey::None_, lang).to_string()
    };

    // summary
    let summary_text = if root_code == "200" && listing_code == "200" && upload_code == "200" {
        msg(MsgKey::SummaryOk, lang)
    } else if root_code == "200" || listing_code == "200" || upload_code == "200" {
        msg(MsgKey::SummaryPartial, lang)
    } else {
        msg(MsgKey::SummaryFail, lang)
    };

    let listing_payload = crate::http::http_body(&client, &urls.url_listing)
        .await
        .unwrap_or_default();
    let listing_count = listing_payload.matches("\"name\":\"").count();

    println!(
        "{:<15}: {}",
        msg(MsgKey::StatusTime, lang),
        chrono::Local::now().format("%Y-%m-%d %H:%M:%S %Z (%z)")
    );
    println!("{:<15}: {}", msg(MsgKey::SiteMode, lang), cfg.site_mode);
    if !cfg.domain.is_empty() {
        println!("{:<15}: {}", msg(MsgKey::Domain, lang), cfg.domain);
    }
    println!("{:<15}: {}", msg(MsgKey::AccessHost, lang), cfg.access_host);
    println!("{:<15}: {}", msg(MsgKey::ResolveIp, lang), cfg.ip);
    print_kv(
        msg(MsgKey::ConfigFile, lang),
        &format!(
            "{} ({})",
            cfg.conf.to_string_lossy(),
            crate::util::path_state(&cfg.conf, lang)
        ),
    );
    print_kv(
        msg(MsgKey::AuthFile, lang),
        &format!(
            "{} ({})",
            cfg.auth_file.to_string_lossy(),
            crate::util::path_state(&cfg.auth_file, lang)
        ),
    );
    print_kv(
        msg(MsgKey::CertFile, lang),
        &format!(
            "{} ({})",
            cfg.cert_file.to_string_lossy(),
            crate::util::path_state(&cfg.cert_file, lang)
        ),
    );
    print_kv(
        msg(MsgKey::KeyFile, lang),
        &format!(
            "{} ({})",
            cfg.key_file.to_string_lossy(),
            crate::util::path_state(&cfg.key_file, lang)
        ),
    );
    print_kv(
        msg(MsgKey::DataDir, lang),
        &format!(
            "{} ({})",
            cfg.data_dir.to_string_lossy(),
            crate::util::path_state(&cfg.data_dir, lang)
        ),
    );
    print_kv(
        msg(MsgKey::UploadDir, lang),
        &format!(
            "{} ({})",
            cfg.upload_dir.to_string_lossy(),
            crate::util::path_state(&cfg.upload_dir, lang)
        ),
    );
    println!(
        "{:<15}: {}",
        msg(MsgKey::FreeSpace, lang),
        crate::util::free_space(&cfg.data_dir)
    );
    println!("{:<15}: {}", msg(MsgKey::NginxTest, lang), nginx_test_text);
    println!(
        "{:<15}: {}",
        msg(MsgKey::NginxProcess, lang),
        nginx_process_text
    );
    println!("{:<15}: {}", msg(MsgKey::AuthUserLabel, lang), au);
    println!(
        "{:<15}: {}",
        msg(MsgKey::RootItems, lang),
        crate::util::count_entries(&cfg.data_dir, "all")
    );
    println!(
        "{:<15}: {}",
        msg(MsgKey::UploadFiles, lang),
        crate::util::count_entries(&cfg.upload_dir, "files")
    );
    println!(
        "{:<15}: {}",
        msg(MsgKey::UploadSize, lang),
        crate::util::dir_size(&cfg.upload_dir)
    );
    println!("{:<15}: {}", msg(MsgKey::Summary, lang), summary_text);
    println!("{:<15}: {}", msg(MsgKey::RootPage, lang), root_code);
    println!("{:<15}: {}", msg(MsgKey::ListingJson, lang), listing_code);
    println!("{:<15}: {}", msg(MsgKey::UploadExpect, lang), upload_code);
    println!("{:<15}: {}", msg(MsgKey::SessionStatus, lang), session_code);
    println!(
        "{:<15}: {}",
        msg(MsgKey::UploadApiExpect, lang),
        upload_api_code
    );
    println!(
        "{:<15}: {}",
        msg(MsgKey::LoginVerify, lang),
        login_verify_code
    );
    println!(
        "{:<15}: {}",
        msg(MsgKey::ListingCount, lang),
        listing_count.to_string()
    );

    Ok(())
}
