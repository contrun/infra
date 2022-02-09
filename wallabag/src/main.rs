use std::collections::{HashMap, HashSet};
use std::env;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use futures::future::try_join_all;

use clap::Parser;
use wallabag_api::errors::ClientResult;
use wallabag_api::types::{
    Config, Entries, EntriesFilter, Entry, ExistsInfo, NewEntry, PatchEntry, ID as EntryID,
};
use wallabag_api::Client;

#[derive(Debug)]
enum EntryInfo {
    ID(EntryID),
    Entry(Entry),
}

impl From<&EntryInfo> for EntryID {
    fn from(entry: &EntryInfo) -> Self {
        match entry {
            &EntryInfo::ID(id) => id,
            &EntryInfo::Entry(ref e) => *(&e.into()),
        }
    }
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[clap(short, long)]
    archive: bool,
    #[clap(last = true)]
    urls: Vec<String>,
}

#[derive(Debug)]
pub struct State {
    inner: HashMap<String, Option<EntryInfo>>,
}

impl State {
    async fn new<T: Into<String>>(urls: Vec<T>) -> ClientResult<Self> {
        let mut s = Self::new_with_ids_from_wallabag(urls).await?;
        s.create_non_existent_entries().await?;
        Ok(s)
    }

    async fn new_from_archived_urls<T: Into<String>>(urls: Vec<T>) -> ClientResult<Self> {
        let mut s = Self::new(urls).await?;
        let mut url_entries: HashMap<String, EntryID> = s
            .inner
            .iter()
            .filter_map(|(url, entry)| entry.as_ref().map(|e| (url.to_owned(), e.into())))
            .collect();

        let len = url_entries.len();
        // If there are many entries to archive, we'd better check if these entries are archived
        // first before continue.
        if len > 10 {
            let recent_archived_entries: HashSet<EntryID> = get_archived_entries_since(
                SystemTime::now()
                    .checked_sub(Duration::from_secs(3600 * 24 * 30))
                    .unwrap(),
            )
            .await?
            .into_iter()
            .map(|e| e.into())
            .collect();

            dbg!(&recent_archived_entries);

            url_entries = url_entries
                .into_iter()
                .filter(|(_, e)| !recent_archived_entries.contains(e))
                .collect();
            dbg!(&url_entries);
        }

        let results: HashMap<String, Entry> =
            try_join_all(url_entries.into_iter().map(|(url, e)| async move {
                let entry = archive_entry_with_id(e).await;
                entry.map(|e| (url, e))
            }))
            .await?
            .into_iter()
            .collect();

        dbg!(&results);

        s.merge_entries(results);

        Ok(s)
    }

    async fn new_with_ids_from_wallabag<T: Into<String>>(urls: Vec<T>) -> ClientResult<Self> {
        let mut s = Self::new_without_ids(urls);
        s.fill_in_ids().await?;
        Ok(s)
    }

    async fn create_non_existent_entries(&mut self) -> ClientResult<()> {
        let urls = self
            .inner
            .iter()
            .filter(|(_, v)| v.is_none())
            .map(|(url, _)| url.to_owned());
        let results: HashMap<String, Entry> = try_join_all(urls.map(|url| async move {
            let entry = create_entry_for_url(&url).await;
            entry.map(|e| (url, e))
        }))
        .await?
        .into_iter()
        .map(|(url, entry)| (url.to_owned(), entry))
        .collect();

        dbg!(&results);

        self.merge_entries(results);

        Ok(())
    }

    fn new_without_ids<T: Into<String>>(urls: Vec<T>) -> Self {
        Self {
            inner: urls.into_iter().map(|url| (url.into(), None)).collect(),
        }
    }

    async fn fill_in_ids(&mut self) -> ClientResult<()> {
        let mut client = get_client();
        let check_urls_result = client.check_urls_exist(self.inner.keys().collect()).await?;
        dbg!(&check_urls_result);
        self.merge_exists_info(check_urls_result);
        Ok(())
    }

    fn merge_exists_info(&mut self, info: ExistsInfo) {
        self.inner.extend(
            info.into_iter()
                .map(|(url, id)| (url, id.map(|i| EntryInfo::ID(i)))),
        );
    }

    fn merge_entries(&mut self, entries: HashMap<String, Entry>) {
        self.inner.extend(
            entries
                .into_iter()
                .map(|(url, e)| (url, Some(EntryInfo::Entry(e)))),
        );
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

async fn get_archived_entries_since(time: SystemTime) -> ClientResult<Entries> {
    let secs = time
        .duration_since(UNIX_EPOCH)
        .expect("valid time")
        .as_secs();
    let mut client = get_client();
    let filter = EntriesFilter {
        archive: Some(true),
        since: secs as i64,
        ..Default::default()
    };
    let archived_entries = client.get_entries_with_filter(&filter).await;
    dbg!(&archived_entries);
    archived_entries
}

async fn archive_entry_with_id(id: EntryID) -> ClientResult<Entry> {
    let mut client = get_client();
    let archive_it = PatchEntry {
        archive: Some(true),
        ..Default::default()
    };
    client.update_entry(id, &archive_it).await
}

async fn create_entry_for_url(url: &str) -> ClientResult<Entry> {
    let mut client = get_client();
    dbg!(url);
    let e = NewEntry::new_with_url(url.to_owned());
    client.create_entry(&e).await
}

#[async_std::main]
async fn main() -> ClientResult<()> {
    let args = Args::parse();

    let res = if args.archive {
        State::new_from_archived_urls(args.urls).await
    } else {
        State::new(args.urls).await
    };

    dbg!(&res);
    res.map(|_| ())
}
