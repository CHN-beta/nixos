//! AIDesk backend: a Rust port of the omp-web API surface.
//!
//! Listens on a Unix domain socket (for nginx + Authelia) and/or TCP.

use aidesk_backend::config::Config;

#[tokio::main]
async fn main() {
    let config = Config::load();
    if let Err(error) = aidesk_backend::run(config).await {
        eprintln!("[aidesk] fatal: {}", error);
        std::process::exit(1);
    }
}
