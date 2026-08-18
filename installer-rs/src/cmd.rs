use std::path::Path;
use std::time::Duration;
use tokio::process::Command;

/// Run a shell command, returning error with output on failure.
pub async fn run(cmd: &str) -> Result<(), String> {
    let output = Command::new("sh")
        .arg("-c")
        .arg(cmd)
        .output()
        .await
        .map_err(|e| format!("Failed to execute: {e}"))?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        Err(format!(
            "Command failed ({}): {} {}",
            output.status, stdout, stderr
        ))
    }
}

/// Run a shell command and capture stdout.
pub async fn run_capture(cmd: &str) -> Result<String, String> {
    let output = Command::new("sh")
        .arg("-c")
        .arg(cmd)
        .output()
        .await
        .map_err(|e| format!("Failed to execute: {e}"))?;

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Run a shell command, ignoring errors.
pub async fn run_silent(cmd: &str) {
    let _ = Command::new("sh").arg("-c").arg(cmd).output().await;
}

/// Check if a path is a mount point.
pub async fn is_mounted(path: &str) -> bool {
    Command::new("mountpoint")
        .arg("-q")
        .arg(path)
        .status()
        .await
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Check if a device has a filesystem.
#[allow(dead_code)]
pub async fn has_filesystem(device: &str) -> bool {
    run_capture(&format!("blkid -o value -s TYPE {device}"))
        .await
        .map(|s| !s.is_empty())
        .unwrap_or(false)
}

/// Get filesystem type of a device.
#[allow(dead_code)]
pub async fn get_filesystem(device: &str) -> String {
    run_capture(&format!("blkid -o value -s TYPE {device}"))
        .await
        .unwrap_or_default()
}

/// Check if a btrfs subvolume exists.
#[allow(dead_code)]
pub async fn subvolume_exists(mount: &str, name: &str) -> bool {
    run_capture(&format!("btrfs subvolume list {mount}"))
        .await
        .map(|s| s.contains(name))
        .unwrap_or(false)
}

/// Check if a path exists.
pub fn path_exists(path: &str) -> bool {
    Path::new(path).exists()
}

/// Validate a disk device name — reject path traversal attempts.
#[allow(dead_code)]
pub fn validate_device_name(name: &str) -> Result<(), String> {
    if name.contains("..") || name.contains('/') {
        return Err("Invalid device name: must not contain '..' or '/'".into());
    }
    if name.is_empty() {
        return Err("Device name cannot be empty".into());
    }
    Ok(())
}

/// Retry a function with exponential backoff, capped to prevent overflow.
pub async fn retry<F, Fut>(name: &str, max: usize, base_delay: Duration, f: F) -> Result<(), String>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<(), String>>,
{
    let mut last_err = String::new();
    for attempt in 1..=max {
        match f().await {
            Ok(()) => return Ok(()),
            Err(e) => {
                last_err = e;
                if attempt < max {
                    // Cap the multiplier at 64x to prevent overflow
                    let multiplier = 1u32.checked_shl((attempt - 1) as u32).unwrap_or(64).min(64);
                    let wait = base_delay * multiplier;
                    tokio::time::sleep(wait).await;
                }
            }
        }
    }
    Err(format!("{name} failed after {max} attempts: {last_err}"))
}
