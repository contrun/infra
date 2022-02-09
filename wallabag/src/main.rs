use std::collections::HashMap;
use std::env;

use futures::future::try_join_all;

use wallabag_api::errors::ClientResult;
use wallabag_api::types::{Config, Entry, ExistsInfo, NewEntry, ID as EntryID};
use wallabag_api::Client;

#[derive(Debug)]
pub struct State {
    inner: HashMap<String, Option<EntryID>>,
}

impl State {
    async fn new<T: Into<String>>(urls: Vec<T>) -> ClientResult<Self> {
        let mut s = Self::new_with_ids_from_wallabag(urls).await?;
        s.create_non_existent_entries().await?;
        Ok(s)
    }

    async fn new_with_ids_from_wallabag<T: Into<String>>(urls: Vec<T>) -> ClientResult<Self> {
        let mut s = Self::new_without_ids(urls);
        s.fill_in_ids().await?;
        Ok(s)
    }

    fn new_without_ids<T: Into<String>>(urls: Vec<T>) -> Self {
        Self {
            inner: urls.into_iter().map(|url| (url.into(), None)).collect(),
        }
    }

    async fn fill_in_ids(&mut self) -> ClientResult<()> {
        let mut client = get_client();
        let result = client.check_urls_exist(self.inner.keys().collect()).await?;
        self.merge_exists_info(result);
        Ok(())
    }

    fn merge_exists_info(&mut self, info: ExistsInfo) {
        self.inner.extend(info.into_iter())
    }

    async fn create_non_existent_entries(&mut self) -> ClientResult<()> {
        let urls = self.inner.iter().filter(|(_, v)| v.is_none());
        let results: HashMap<String, Entry> =
            try_join_all(urls.map(|(url, _)| create_entry_for_url(url)))
                .await?
                .into_iter()
                .map(|(url, entry)| (url.to_owned(), entry))
                .collect();

        dbg!(&results);
        Ok(())
    }
}

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

async fn create_entry_for_url(url: &str) -> ClientResult<(&str, Entry)> {
    let mut client = get_client();
    let e = NewEntry::new_with_url(url.to_owned());
    let entry = client.create_entry(&e).await?;
    Ok((url, entry))
}

#[async_std::main]
async fn main() -> ClientResult<()> {
    let urls = std::env::args().skip(1).into_iter().collect();
    let state = State::new(urls)
        .await
        .expect("must get information for urls");
    dbg!(&state);
    Ok(())
}
