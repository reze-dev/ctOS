use include_dir::{include_dir, Dir};
use std::fs;
use std::path::Path;
use std::process::Command;

static FLAKE_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/flake");

/// Extract the embedded flake to a temporary directory and initialize git repository.
pub fn extract_flake() -> Result<String, String> {
    let tmp = std::env::temp_dir().join(format!("northstar-rs-install-{}", std::process::id()));

    if tmp.exists() {
        let _ = fs::remove_dir_all(&tmp);
    }
    fs::create_dir_all(&tmp).map_err(|e| format!("Failed to create temp dir: {e}"))?;

    // Check if FLAKE_DIR has actual content or only PLACEHOLDER
    let has_real_content = FLAKE_DIR
        .files()
        .any(|f| f.path() != Path::new("PLACEHOLDER"))
        || FLAKE_DIR.dirs().count() > 0;

    if has_real_content {
        extract_dir(&FLAKE_DIR, &tmp)?;
    } else {
        // Fallback for local development/cargo run: copy from parent workspace if flake.nix exists
        let candidates = [
            Path::new("."),
            Path::new(".."),
            Path::new("/home/reze/northstar"),
        ];
        let mut found = false;
        for c in candidates {
            if c.join("flake.nix").exists() && c.join("modules").exists() {
                copy_recursive(c, &tmp)?;
                found = true;
                break;
            }
        }
        if !found {
            // Still extract the placeholder dir so extraction succeeds in minimal test environments
            extract_dir(&FLAKE_DIR, &tmp)?;
        }
    }

    // Initialize git repository in tmp so nix flake commands recognize all files
    let _ = Command::new("git")
        .args(["init"])
        .current_dir(&tmp)
        .output();
    let _ = Command::new("git")
        .args(["config", "user.name", "Northstar Installer"])
        .current_dir(&tmp)
        .output();
    let _ = Command::new("git")
        .args(["config", "user.email", "installer@northstar.local"])
        .current_dir(&tmp)
        .output();
    let _ = Command::new("git")
        .args(["add", "-A"])
        .current_dir(&tmp)
        .output();
    let _ = Command::new("git")
        .args(["commit", "-m", "Initial extraction", "--allow-empty"])
        .current_dir(&tmp)
        .output();

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

fn copy_recursive(src: &Path, dst: &Path) -> Result<(), String> {
    let entries = [
        "flake.nix",
        "flake.lock",
        "README.md",
        "hosts",
        "home",
        "lib",
        "modules",
        "flake",
        "assets",
    ];
    for item in entries {
        let src_path = src.join(item);
        let dst_path = dst.join(item);
        if src_path.is_dir() {
            let _ = Command::new("cp")
                .arg("-r")
                .arg(&src_path)
                .arg(&dst_path)
                .output();
        } else if src_path.is_file() {
            let _ = fs::copy(&src_path, &dst_path);
        }
    }
    Ok(())
}
