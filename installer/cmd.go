package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Run executes a shell command, capturing output. Returns error with output on failure.
func Run(cmdStr string) error {
	cmd := exec.Command("sh", "-c", cmdStr)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%v: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
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
	_, _ = cmd.CombinedOutput()
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

// Retry runs a function with exponential backoff. Returns error on exhaustion.
func Retry(name string, maxAttempts int, baseDelay time.Duration, fn func() error) error {
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		lastErr = fn()
		if lastErr == nil {
			return nil
		}
		if attempt < maxAttempts {
			wait := baseDelay * time.Duration(1<<(attempt-1))
			time.Sleep(wait)
		}
	}
	return fmt.Errorf("%s failed after %d attempts: %w", name, maxAttempts, lastErr)
}
