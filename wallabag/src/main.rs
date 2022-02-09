use std::collections::{HashMap, HashSet};
use std::env;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{bail, Context, Result};
use clap::Parser;
use futures::future::{join_all, try_join_all};
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
        s.maybe_create_non_existent_entries().await;
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

        s.merge_entries(results);

        Ok(s)
    }

    async fn new_with_ids_from_wallabag<T: Into<String>>(urls: Vec<T>) -> ClientResult<Self> {
        let mut s = Self::new_without_ids(urls);
        s.fill_in_ids().await?;
        Ok(s)
    }

    // In an ideal world, this should return an optional error.
    // But, we are not able to add some artilces to wallabag due to some persistent backend error.
    // See https://github.com/wallabag/wallabag/issues/5558
    // https://github.com/wallabag/wallabag/issues/5437
    // https://blog.wallaroolabs.com/2018/09/make-python-pandas-go-fast
    // Error: Other(BadGateway, "<html>\r\n<head><title>502 Bad Gateway</title></head>\r\n<body>\r\n<center><h1>502 Bad Gateway</h1></center>\r\n<hr><center>nginx</center>\r\n</body>\r\n</html>\r\n")
    async fn maybe_create_non_existent_entries(&mut self) {
        let urls = self
            .inner
            .iter()
            .filter(|(_, v)| v.is_none())
            .map(|(url, _)| url.to_owned());
        let results: HashMap<String, Entry> = join_all(urls.map(|url| async move {
            let result = create_entry_for_url(&url).await;
            (url, result)
        }))
        .await
        .into_iter()
        .filter_map(|(url, result)| match result {
            Ok(e) => Some((url.to_owned(), e)),
            Err(e) => {
                dbg!("creating entry for url failed", &url, &e);
                None
            }
        })
        .collect();

        self.merge_entries(results);
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
        if !entries.is_empty() {
            dbg!(&entries);
        }
        self.inner.extend(
            entries
                .into_iter()
                .map(|(url, e)| (url, Some(EntryInfo::Entry(e)))),
        );
    }

    fn check(&self) -> Result<()> {
        let urls: Vec<&String> = self
            .inner
            .iter()
            .filter(|(_, v)| v.is_none())
            .map(|(url, _)| url)
            .collect();
        if urls.is_empty() {
            Ok(())
        } else {
            bail!("Following URLs have no associated entries: {:?}", urls)
        }
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
    let e = NewEntry::new_with_url(url.to_owned());
    client.create_entry(&e).await
}

#[async_std::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    let res = if args.archive {
        State::new_from_archived_urls(args.urls)
            .await
            .context("Failed to add archived entries")?
    } else {
        State::new(args.urls)
            .await
            .context("Failed to add entries")?
    };

    dbg!(&res);
    res.check()
}
