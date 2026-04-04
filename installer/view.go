package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func (m model) View() string {
	header := titleStyle.Render("  ❄️  Snowflake NixOS Installer  ❄️") + "\n" +
		titleStyle.Render("  ══════════════════════════════════") + "\n"

	var content string

	switch m.page {
	case pageWelcome:
		content = m.viewWelcome()
	case pageHostname:
		content = m.viewInput("1/8", "Host Configuration", "Enter hostname:", "")
	case pageUsername:
		content = m.viewInput("2/8", "User Configuration", "Enter username:", "")
	case pagePassword:
		content = m.viewInput("2/8", "User Configuration", "Enter password:", "")
	case pagePasswordConfirm:
		content = m.viewInput("2/8", "User Configuration", "Confirm password:", "")
	case pageMode:
		content = m.viewSelect("3/8", "Installation Mode", "Select installation mode:")
	case pageDisk:
		content = m.viewInput("4/8", "Disk Selection", "Enter target disk device:", m.cmdOutput)
	case pageDiskConfirm:
		warn := fmt.Sprintf("⚠ WARNING: All data on /dev/%s will be DESTROYED!", m.diskDev)
		content = m.viewInput("4/8", "Confirm", warn+"\n\nType 'yes' to confirm:", "")
	case pagePartSelect:
		content = m.viewSelect("4/8", "Partition Selection", "What would you like to do?")
	case pagePartNewStart:
		content = m.viewInput("4/8", "Create Partition", "Enter start position:", "")
	case pagePartNewEnd:
		content = m.viewInput("4/8", "Create Partition", "Enter end position:", "")
	case pagePartExist:
		content = m.viewInput("4/8", "Select Partition", "Enter NixOS partition device:", m.cmdOutput)
	case pagePartConfirm:
		warn := fmt.Sprintf("⚠ WARNING: All data on %s will be DESTROYED!", m.nixosPart)
		content = m.viewInput("4/8", "Confirm", warn+"\n\nType 'yes' to confirm:", "")
	case pageEFI:
		content = m.viewInput("4/8", "EFI Partition", "EFI System Partition:", m.cmdOutput)
	case pageSwap:
		hint := "Enter swap size (e.g., 8G, 16G, 0 to disable)"
		content = m.viewInput("5/8", "Swap Configuration", hint, "")
	case pageFS:
		content = m.viewSelect("6/8", "Filesystem", "Select root filesystem:")
	case pageGPU:
		content = m.viewSelect("7/8", "GPU Configuration", "Select GPU type:")
	case pageGPUNvBus:
		content = m.viewInput("7/8", "NVIDIA Configuration", "NVIDIA Bus ID:", m.cmdOutput)
	case pageGPUIgpuType:
		content = m.viewSelect("7/8", "NVIDIA Prime", "Select iGPU type:")
	case pageGPUIgpuBus:
		content = m.viewInput("7/8", "NVIDIA Prime", "iGPU Bus ID:", "")
	case pageSummary:
		content = m.viewSummary()
	case pageInstalling:
		content = m.viewInstalling()
	case pageDone:
		content = m.viewDone()
	}

	return header + content
}

// ── Page views ─────────────────────────────────────────────────────

func (m model) viewWelcome() string {
	art := `
     *    .  ❄  .    *
   .    ❄    *    ❄    .
     .    *  .  *    .
         ❄  .  ❄
           *`

	body := lipgloss.NewStyle().Foreground(cyan).Render(art) + "\n\n" +
		labelStyle.Render("  Welcome to the Snowflake NixOS Installer") + "\n\n" +
		hintStyle.Render("  This wizard will guide you through setting up") + "\n" +
		hintStyle.Render("  a fresh NixOS system with your configuration.") + "\n\n" +
		hintStyle.Render("  Press Enter to begin...")

	return boxStyle.Render(body) + "\n"
}

func (m model) viewInput(step, title, label, extra string) string {
	var b strings.Builder

	b.WriteString(stepStyle.Render(fmt.Sprintf("  [Step %s] %s", step, title)))
	b.WriteString("\n\n")

	if extra != "" {
		b.WriteString(hintStyle.Render(extra))
		b.WriteString("\n\n")
	}

	b.WriteString(labelStyle.Render(label))
	b.WriteString("\n")
	b.WriteString("  " + m.input.View())
	b.WriteString("\n")

	if m.err != "" {
		b.WriteString("\n" + errStyle.Render("  ✗ "+m.err))
	}

	b.WriteString("\n\n")
	b.WriteString(hintStyle.Render("  enter: next  •  esc: back  •  ctrl+c: quit"))

	return boxStyle.Render(b.String()) + "\n"
}

func (m model) viewSelect(step, title, label string) string {
	var b strings.Builder

	b.WriteString(stepStyle.Render(fmt.Sprintf("  [Step %s] %s", step, title)))
	b.WriteString("\n\n")
	b.WriteString(labelStyle.Render(label))
	b.WriteString("\n\n")

	for i, choice := range m.choices {
		if i == m.cursor {
			b.WriteString(selectedStyle.Render(fmt.Sprintf("  › %s", choice)))
		} else {
			b.WriteString(unselectedStyle.Render(fmt.Sprintf("    %s", choice)))
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(hintStyle.Render("  ↑/↓: navigate  •  enter: select  •  esc: back"))

	return boxStyle.Render(b.String()) + "\n"
}

func (m model) viewSummary() string {
	var b strings.Builder

	b.WriteString(stepStyle.Render("  [Step 8/8] Review Configuration"))
	b.WriteString("\n\n")

	row := func(label, value string) {
		b.WriteString(fmt.Sprintf("  %-16s %s\n", labelStyle.Render(label+":"), value))
	}

	row("Hostname", m.hostname)
	row("Username", m.username)
	row("Mode", m.mode)
	row("Disk", "/dev/"+m.diskDev)

	if m.mode == "partition-only" {
		row("NixOS Part", m.nixosPart)
		row("EFI Part", m.efiPart)
	}

	row("Swap", m.swapSize)

	if m.mode == "whole-disk" {
		row("Filesystem", m.fsType)
	}

	gpuLabel := "Default (no NVIDIA)"
	if m.gpuChoice == "2" {
		gpuLabel = "NVIDIA"
	} else if m.gpuChoice == "3" {
		gpuLabel = fmt.Sprintf("NVIDIA Prime (%s + %s:%s)", m.nvBusID, m.igpuType, m.igpuBusID)
	}
	row("GPU", gpuLabel)

	b.WriteString("\n")
	b.WriteString(warnStyle.Render("  ⚠ This will modify your disk. Make sure the config is correct."))
	b.WriteString("\n\n")
	b.WriteString(hintStyle.Render("  enter/y: install  •  esc/n: start over  •  ctrl+c: quit"))

	return boxStyle.Render(b.String()) + "\n"
}

func (m model) viewInstalling() string {
	var b strings.Builder

	b.WriteString(stepStyle.Render("  Installing NixOS..."))
	b.WriteString("\n\n")

	doneCount := 0
	for _, s := range m.installSteps {
		var icon string
		switch s.status {
		case stepPending:
			icon = pendingMark
		case stepRunning:
			icon = m.spinner.View()
		case stepDone:
			icon = successMark
			doneCount++
		case stepError:
			icon = errorMark
		}
		b.WriteString(fmt.Sprintf("  %s  %s\n", icon, s.label))
	}

	// Progress bar
	pct := float64(doneCount) / float64(len(m.installSteps))
	b.WriteString("\n")
	b.WriteString("  " + m.progress.ViewAs(pct))
	b.WriteString("\n")

	// Log lines
	if len(m.logLines) > 0 {
		b.WriteString("\n")
		for _, line := range m.logLines {
			b.WriteString(hintStyle.Render("  > "+line) + "\n")
		}
	}

	// Error display
	if m.installErr != nil {
		b.WriteString("\n" + errStyle.Render(fmt.Sprintf("  ✗ Error: %v", m.installErr)))
		b.WriteString("\n" + hintStyle.Render("  ctrl+c to exit"))
	}

	return boxStyle.Render(b.String()) + "\n"
}

func (m model) viewDone() string {
	var b strings.Builder

	b.WriteString(lipgloss.NewStyle().Foreground(green).Bold(true).Render("  ✅ Installation Complete!"))
	b.WriteString("\n\n")
	b.WriteString(fmt.Sprintf("  Configuration saved to: /home/%s/snowflake\n", m.username))
	b.WriteString("  You can now reboot into your new Snowflake system.\n\n")
	b.WriteString(labelStyle.Render("  After reboot:"))
	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(cyan).Render(
		fmt.Sprintf("    cd ~/snowflake && sudo nixos-rebuild switch --flake .#%s", m.hostname),
	))
	b.WriteString("\n\n")
	b.WriteString(hintStyle.Render("  Press enter or q to exit"))

	return boxStyle.Render(b.String()) + "\n"
}
