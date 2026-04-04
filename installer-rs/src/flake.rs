use include_dir::{include_dir, Dir};
use std::fs;
use std::path::Path;

static FLAKE_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/flake");

/// Extract the embedded flake to a temporary directory.
pub fn extract_flake() -> Result<String, String> {
    let tmp = std::env::temp_dir().join(format!("snowflake-rs-install-{}", std::process::id()));

    if tmp.exists() {
        let _ = fs::remove_dir_all(&tmp);
    }
    fs::create_dir_all(&tmp).map_err(|e| format!("Failed to create temp dir: {e}"))?;

    extract_dir(&FLAKE_DIR, &tmp)?;

    Ok(tmp.to_string_lossy().to_string())
}

fn extract_dir(dir: &Dir, base: &Path) -> Result<(), String> {
    for file in dir.files() {
        let dest = base.join(file.path());
        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("mkdir {}: {e}", parent.display()))?;
        }
        fs::write(&dest, file.contents()).map_err(|e| format!("write {}: {e}", dest.display()))?;
    }
    for subdir in dir.dirs() {
        extract_dir(subdir, base)?;
    }
    Ok(())
}
