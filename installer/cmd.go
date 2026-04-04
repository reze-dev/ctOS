package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Run executes a shell command, printing output to stdout/stderr.
func Run(cmdStr string) error {
	cmd := exec.Command("sh", "-c", cmdStr)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// RunCapture executes a command and returns stdout trimmed.
func RunCapture(cmdStr string) (string, error) {
	cmd := exec.Command("sh", "-c", cmdStr)
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}

// RunSilent runs a command, ignoring errors.
func RunSilent(cmdStr string) {
	cmd := exec.Command("sh", "-c", cmdStr)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}

// IsMounted checks if a path is a mount point.
func IsMounted(path string) bool {
	err := exec.Command("mountpoint", "-q", path).Run()
	return err == nil
}

// HasFilesystem checks if a device has a filesystem via blkid.
func HasFilesystem(device string) bool {
	out, err := RunCapture(fmt.Sprintf("blkid -o value -s TYPE %s", device))
	return err == nil && out != ""
}

// GetFilesystem returns the filesystem type of a device.
func GetFilesystem(device string) string {
	out, _ := RunCapture(fmt.Sprintf("blkid -o value -s TYPE %s", device))
	return out
}

// SubvolumeExists checks if a btrfs subvolume exists.
func SubvolumeExists(mount, name string) bool {
	out, _ := RunCapture(fmt.Sprintf("btrfs subvolume list %s", mount))
	return strings.Contains(out, name)
}

// PathExists checks if a file/dir exists.
func PathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// Retry runs a function with exponential backoff.
// On exhaustion, prompts the user for retry/skip/abort.
func Retry(name string, maxAttempts int, baseDelay time.Duration, fn func() error) error {
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		lastErr = fn()
		if lastErr == nil {
			return nil
		}
		if attempt < maxAttempts {
			wait := baseDelay * time.Duration(1<<(attempt-1))
			Warn(fmt.Sprintf("  Attempt %d/%d failed: %v\n  Retrying in %v...", attempt, maxAttempts, lastErr, wait))
			time.Sleep(wait)
		} else {
			Err(fmt.Sprintf("  All %d attempts failed: %v", maxAttempts, lastErr))
		}
	}

	// Interactive fallback
	for {
		choice := Prompt(fmt.Sprintf("%s[r]etry / [s]kip / [a]bort? %s", Yellow, Reset))
		switch strings.ToLower(choice) {
		case "r":
			return Retry(name, maxAttempts, baseDelay, fn)
		case "s":
			Warn("  Skipped.")
			return nil
		case "a":
			Die("Aborted by user.")
		}
	}
}
