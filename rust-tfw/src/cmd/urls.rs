use crate::config::Urls;
use crate::i18n::{msg, Lang, MsgKey};

pub fn run(urls: &Urls, project_url: &str, lang: Lang) {
    println!("{:<15}: {}", msg(MsgKey::RootUrl, lang), urls.url_root);
    println!("{:<15}: {}", msg(MsgKey::UploadPage, lang), urls.url_upload);
    println!(
        "{:<15}: {}",
        msg(MsgKey::ListingApi, lang),
        urls.url_listing
    );
    println!("{:<15}: {}", msg(MsgKey::ProjectUrl, lang), project_url);
}
