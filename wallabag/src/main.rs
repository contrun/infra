use std::env;

use futures::future::join_all;

use wallabag_api::errors::ClientResult;
use wallabag_api::types::{Config, Entry, ExistsInfo, NewEntry};
use wallabag_api::Client;

fn get_client() -> Client {
    let config = Config {
        client_id: env::var("WALLABAG_CLIENT_ID").expect("WALLABAG_CLIENT_ID not set"),
        client_secret: env::var("WALLABAG_CLIENT_SECRET").expect("WALLABAG_CLIENT_SECRET not set"),
        username: env::var("WALLABAG_USERNAME").expect("WALLABAG_USERNAME not set"),
        password: env::var("WALLABAG_PASSWORD").expect("WALLABAG_PASSWORD not set"),
        base_url: env::var("WALLABAG_URL").expect("WALLABAG_URL not set"),
    };

    Client::new(config)
}

async fn get_entries_info<T: Into<String>>(urls: Vec<T>) -> ClientResult<ExistsInfo> {
    let mut client = get_client();
    client.check_urls_exist(urls).await
}

async fn create_entry_for_url(url: &str) -> ClientResult<Entry> {
    let mut client = get_client();
    let e = NewEntry::new_with_url(url.to_owned());
    client.create_entry(&e).await
}

async fn create_non_existent_entries(info: &ExistsInfo) -> ClientResult<Vec<Entry>> {
    dbg!(&info);

    let urls = info.iter().filter(|(_, v)| v.is_none());
    let results = join_all(urls.map(|(url, _)| create_entry_for_url(url)))
        .await
        .into_iter()
        .collect();

    dbg!(&results);
    results
}

#[async_std::main]
async fn main() -> ClientResult<()> {
    let urls = std::env::args().skip(1).into_iter().collect();
    let entries_info = get_entries_info(urls).await?;
    let _results = create_non_existent_entries(&entries_info).await?;
    Ok(())
}
