package main

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

//go:embed flake
var flakeFS embed.FS

func main() {
	if os.Geteuid() != 0 {
		fmt.Println("\033[0;31mPlease run as root\033[0m")
		os.Exit(1)
	}

	// Extract embedded flake to temp dir
	workDir, err := extractFlake()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to extract flake: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(workDir)

	if err := os.Chdir(workDir); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to enter work directory: %v\n", err)
		os.Exit(1)
	}

	state := NewState()
	m := newModel(state, workDir)

	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// extractFlake extracts the embedded flake directory to a temp dir.
func extractFlake() (string, error) {
	tmpDir, err := os.MkdirTemp("", "snowflake-go-install-*")
	if err != nil {
		return "", err
	}

	err = fs.WalkDir(flakeFS, "flake", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
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
