package main

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

//go:embed flake
var flakeFS embed.FS

func main() {
	defer func() {
		if r := recover(); r != nil {
			if msg, ok := r.(string); ok && msg == "fatal" {
				os.Exit(1)
			}
			panic(r)
		}
	}()

	fmt.Printf("%s\n", Cyan)
	fmt.Println("  ❄️  Snowflake NixOS Installer (Go)  ❄️")
	fmt.Println("  ======================================")
	fmt.Printf("%s\n", Reset)

	if os.Geteuid() != 0 {
		Die("Please run as root")
	}

	// Extract embedded flake to temp dir
	workDir, err := extractFlake()
	if err != nil {
		Die(fmt.Sprintf("Failed to extract flake: %v", err))
	}
	defer os.RemoveAll(workDir)

	if err := os.Chdir(workDir); err != nil {
		Die(fmt.Sprintf("Failed to enter work directory: %v", err))
	}

	// Initialize git so nix flake works
	RunSilent("git init")
	RunSilent("git add .")
	RunSilent(`git commit -m "Embedded flake" --allow-empty`)

	state := NewState()

	// Check for resume
	if state.CurrentStep() != StepOrder[0] {
		Warn(fmt.Sprintf("Resuming from checkpoint: %s", state.CurrentStep()))
		ans := PromptDefault("Continue from last checkpoint? [Y/n]: ", "Y")
		if strings.ToLower(ans) != "y" {
			state.Clear()
			Msg("Starting fresh.")
		}
	}

	// Run steps
	if !state.ShouldSkip("gather_host") {
		GatherHost(state)
	}
	if !state.ShouldSkip("gather_user") {
		GatherUser(state)
	}
	if !state.ShouldSkip("gather_mode") {
		GatherMode(state)
	}
	if !state.ShouldSkip("gather_disk") {
		GatherDisk(state)
	}
	if !state.ShouldSkip("gather_swap_fs_gpu") {
		GatherSwapFsGpu(state)
	}
	if !state.ShouldSkip("confirm") {
		ShowSummaryAndConfirm(state)
	}
	if !state.ShouldSkip("generate_config") {
		GenerateConfig(state, workDir)
	}
	if !state.ShouldSkip("partition") {
		DoPartition(state, workDir)
	}
	if !state.ShouldSkip("install_nixos") {
		DoInstallNixOS(state)
	}
	if !state.ShouldSkip("copy_flake") {
		DoCopyFlake(state, workDir)
	}

	// Done
	username := state.Get("username")
	hostname := state.Get("hostname")
	state.Clear()

	fmt.Printf("\n%s✅ Installation Complete!%s\n", Green, Reset)
	fmt.Printf("Configuration saved to: %s/home/%s/snowflake%s\n", Cyan, username, Reset)
	fmt.Println("You can now reboot into your new Snowflake system.")
	fmt.Printf("After reboot: %scd ~/snowflake && sudo nixos-rebuild switch --flake .#%s%s\n", Cyan, hostname, Reset)
	fmt.Printf("Run: %sreboot%s\n", Cyan, Reset)
}

// extractFlake extracts the embedded flake directory to a temp dir.
func extractFlake() (string, error) {
	tmpDir, err := os.MkdirTemp("", "snowflake-go-install-*")
	if err != nil {
		return "", err
	}

	Msg("Extracting embedded Snowflake flake...")

	err = fs.WalkDir(flakeFS, "flake", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		// Strip "flake/" prefix
		relPath := strings.TrimPrefix(path, "flake/")
		if relPath == "" || path == "flake" {
			return nil
		}

		destPath := filepath.Join(tmpDir, relPath)

		if d.IsDir() {
			return os.MkdirAll(destPath, 0755)
		}

		data, err := flakeFS.ReadFile(path)
		if err != nil {
			return err
		}

		if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
			return err
		}
		return os.WriteFile(destPath, data, 0644)
	})

	return tmpDir, err
}
