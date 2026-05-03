use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tauri::{AppHandle, Manager};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum PingIslandStatus {
    AlreadyRunning,
    Launched { path: String },
    NotBundled,
    LaunchFailed { error: String },
}

/// Detect whether a Ping Island process is already running on this machine
/// (covers both the user's global install and any bundled copy we launched).
fn is_ping_island_running() -> bool {
    // pgrep returns 0 when at least one process matches; other codes mean none.
    std::process::Command::new("pgrep")
        .args(["-f", "Ping Island.app/Contents/MacOS/Ping Island"])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Resolve the Ping Island.app path inside our bundled resources, if present.
fn bundled_ping_island_path(app: &AppHandle) -> Option<PathBuf> {
    // In a debug build (`bun tauri dev`), Tauri's resource copy mangles macOS
    // .app signatures (bundle format becomes ambiguous, Gatekeeper rejects).
    // Prefer the source-tree vendor copy in that case — it's properly signed
    // and notarized as shipped by the upstream author.
    if cfg!(debug_assertions) {
        if let Ok(cwd) = std::env::current_dir() {
            for rel in [
                "vendor/Ping Island.app",
                "../vendor/Ping Island.app",
            ] {
                let candidate = cwd.join(rel);
                if candidate.join("Contents/MacOS/Ping Island").exists() {
                    return Some(candidate);
                }
            }
        }
    }

    // Production / packaged path: Tauri rewrites "../vendor/..." into
    // "_up_/vendor/..." inside the resources tree.
    let resource_dir = app.path().resource_dir().ok()?;
    for rel in ["_up_/vendor/Ping Island.app", "vendor/Ping Island.app"] {
        let candidate = resource_dir.join(rel);
        if candidate.exists() {
            return Some(candidate);
        }
    }
    None
}

/// Tauri command: ensure a Ping Island instance is running, launching the
/// bundled copy if neither the user's global install nor a previous launch
/// is alive. Idempotent — safe to call on every app startup.
#[tauri::command]
pub async fn launch_ping_island(app: AppHandle) -> Result<PingIslandStatus, String> {
    if is_ping_island_running() {
        log::info!("Ping Island already running; skipping bundled launch");
        return Ok(PingIslandStatus::AlreadyRunning);
    }

    let Some(app_path) = bundled_ping_island_path(&app) else {
        log::warn!("Bundled Ping Island.app not found in resources");
        return Ok(PingIslandStatus::NotBundled);
    };

    let path_str = app_path.to_string_lossy().to_string();
    log::info!("Launching bundled Ping Island at: {}", path_str);

    // Strip macOS quarantine xattrs that Tauri's bundler may re-apply when
    // copying resources. Without this, Gatekeeper rejects the app as
    // "damaged" because the quarantine flag invalidates the embedded
    // notarized signature.
    let _ = std::process::Command::new("xattr")
        .args(["-cr"])
        .arg(&app_path)
        .status();

    match std::process::Command::new("open").arg(&app_path).status() {
        Ok(s) if s.success() => Ok(PingIslandStatus::Launched { path: path_str }),
        Ok(s) => Ok(PingIslandStatus::LaunchFailed {
            error: format!("open exited with status {}", s),
        }),
        Err(e) => Ok(PingIslandStatus::LaunchFailed {
            error: e.to_string(),
        }),
    }
}
