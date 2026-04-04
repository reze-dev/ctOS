package main

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.progress.Width = min(msg.Width-10, 50)
		return m, nil
	case progressUpdateMsg:
		return m.handleProgress(ProgressUpdate(msg))
	case hashDoneMsg:
		if msg.err != nil {
			m.err = fmt.Sprintf("Failed to hash password: %v", msg.err)
			m.goToPage(pagePassword)
			return m, nil
		}
		m.hashedPW = msg.hash
		m.goToPage(pageMode)
		return m, nil
	}

	// Spinner tick (always update for installing page)
	if m.page == pageInstalling {
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd
	}

	// Dispatch to page-specific handler
	switch m.page {
	case pageWelcome:
		return m.updateWelcome(msg)
	case pageHostname, pageUsername, pageDisk, pagePartNewStart, pagePartNewEnd,
		pagePartExist, pageSwap, pageGPUNvBus, pageGPUIgpuBus:
		return m.updateTextInput(msg)
	case pagePassword, pagePasswordConfirm:
		return m.updatePassword(msg)
	case pageDiskConfirm, pagePartConfirm:
		return m.updateConfirm(msg)
	case pageEFI:
		return m.updateEFI(msg)
	case pageMode, pagePartSelect, pageFS, pageGPU, pageGPUIgpuType:
		return m.updateSelection(msg)
	case pageSummary:
		return m.updateSummary(msg)
	case pageDone:
		return m.updateDone(msg)
	}

	return m, nil
}

// ── Page handlers ──────────────────────────────────────────────────

func (m model) updateWelcome(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		if key.Type == tea.KeyEnter || key.String() == " " {
			m.goToPage(pageHostname)
		}
	}
	return m, nil
}

func (m model) updateTextInput(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)

	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.Type {
		case tea.KeyEnter:
			val := strings.TrimSpace(m.input.Value())
			next, err := m.saveAndNext(val)
			if err != "" {
				m.err = err
				return m, cmd
			}
			m.goToPage(next)
		case tea.KeyEsc:
			m.goToPage(m.prevPage())
		}
	}
	return m, cmd
}

func (m model) updatePassword(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)

	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.Type {
		case tea.KeyEnter:
			val := m.input.Value()
			if val == "" {
				m.err = "Password cannot be empty"
				return m, cmd
			}
			if m.page == pagePassword {
				m.password = val
				m.goToPage(pagePasswordConfirm)
			} else {
				if val != m.password {
					m.err = "Passwords do not match"
					m.goToPage(pagePassword)
					return m, cmd
				}
				m.passConfirm = val
				// Hash password asynchronously
				pw := m.password
				return m, func() tea.Msg {
					hash, err := HashPassword(pw)
					return hashDoneMsg{hash: hash, err: err}
				}
			}
		case tea.KeyEsc:
			if m.page == pagePasswordConfirm {
				m.goToPage(pagePassword)
			} else {
				m.goToPage(pageUsername)
			}
		}
	}
	return m, cmd
}

func (m model) updateConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)

	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.Type {
		case tea.KeyEnter:
			if strings.TrimSpace(m.input.Value()) != "yes" {
				m.err = "Type 'yes' to confirm"
				return m, cmd
			}
			if m.page == pageDiskConfirm {
				if m.mode == "whole-disk" {
					m.goToPage(pageSwap)
				} else {
					m.goToPage(pagePartSelect)
				}
			} else { // pagePartConfirm
				m.goToPage(pageEFI)
			}
		case tea.KeyEsc:
			m.goToPage(pageDisk)
		}
	}
	return m, cmd
}

func (m model) updateEFI(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)

	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.Type {
		case tea.KeyEnter:
			if m.efiPart != "" {
				// Auto-detected, skip input
				m.goToPage(pageSwap)
			} else {
				val := strings.TrimSpace(m.input.Value())
				if val == "" {
					m.err = "EFI partition cannot be empty"
					return m, cmd
				}
				m.efiPart = "/dev/" + val
				m.goToPage(pageSwap)
			}
		case tea.KeyEsc:
			m.goToPage(pagePartConfirm)
		}
	}
	return m, cmd
}

func (m model) updateSelection(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.choices)-1 {
				m.cursor++
			}
		case "enter":
			return m.saveSelection()
		case "esc":
			m.goToPage(m.prevPage())
		}
	}
	return m, nil
}

func (m model) updateSummary(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		switch key.String() {
		case "enter", "y", "Y":
			return m.startInstallation()
		case "esc", "n", "N":
			m.goToPage(pageHostname)
		}
	}
	return m, nil
}

func (m model) updateDone(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyMsg); ok {
		if key.Type == tea.KeyEnter || key.String() == "q" {
			return m, tea.Quit
		}
	}
	return m, nil
}

// ── Helpers ────────────────────────────────────────────────────────

func (m *model) saveAndNext(val string) (page, string) {
	switch m.page {
	case pageHostname:
		if val == "" {
			return 0, "Hostname cannot be empty"
		}
		m.hostname = val
		return pageUsername, ""
	case pageUsername:
		if val == "" {
			return 0, "Username cannot be empty"
		}
		m.username = val
		return pagePassword, ""
	case pageDisk:
		if val == "" {
			return 0, "Device cannot be empty"
		}
		m.diskDev = val
		return pageDiskConfirm, ""
	case pagePartNewStart:
		if val == "" {
			return 0, "Start position required"
		}
		m.partNewStart = val
		return pagePartNewEnd, ""
	case pagePartNewEnd:
		if val == "" {
			return 0, "End position required"
		}
		// Create the partition
		before, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME /dev/%s | wc -l", m.diskDev))
		err := Run(fmt.Sprintf(`parted -s /dev/%s mkpart primary "%s" "%s"`, m.diskDev, m.partNewStart, val))
		if err != nil {
			return 0, fmt.Sprintf("Failed to create partition: %v", err)
		}
		time.Sleep(2 * time.Second)
		RunSilent(fmt.Sprintf("partprobe /dev/%s", m.diskDev))
		time.Sleep(1 * time.Second)
		after, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME /dev/%s | wc -l", m.diskDev))
		if after <= before {
			return 0, "Failed to detect new partition"
		}
		partName, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME /dev/%s | tail -1", m.diskDev))
		m.nixosPart = "/dev/" + partName
		return pagePartConfirm, ""
	case pagePartExist:
		if val == "" {
			return 0, "Partition device required"
		}
		m.nixosPart = "/dev/" + val
		return pagePartConfirm, ""
	case pageSwap:
		if val == "" {
			val = "8G"
		}
		m.swapSize = val
		if m.mode == "whole-disk" {
			return pageFS, ""
		}
		return pageGPU, ""
	case pageGPUNvBus:
		m.nvBusID = val
		return pageGPUIgpuType, ""
	case pageGPUIgpuBus:
		m.igpuBusID = val
		return pageSummary, ""
	}
	return m.page + 1, ""
}

func (m model) saveSelection() (tea.Model, tea.Cmd) {
	switch m.page {
	case pageMode:
		if m.cursor == 0 {
			m.mode = "whole-disk"
		} else {
			m.mode = "partition-only"
		}
		m.goToPage(pageDisk)
	case pagePartSelect:
		if m.cursor == 0 {
			m.goToPage(pagePartExist)
		} else {
			m.goToPage(pagePartNewStart)
		}
	case pageFS:
		if m.cursor == 0 {
			m.fsType = "btrfs"
		} else {
			m.fsType = "ext4"
		}
		m.goToPage(pageGPU)
	case pageGPU:
		m.gpuChoice = fmt.Sprintf("%d", m.cursor+1)
		if m.cursor == 2 { // Prime
			m.goToPage(pageGPUNvBus)
		} else {
			m.goToPage(pageSummary)
		}
	case pageGPUIgpuType:
		if m.cursor == 0 {
			m.igpuType = "intel"
		} else {
			m.igpuType = "amd"
		}
		m.goToPage(pageGPUIgpuBus)
	}
	return m, nil
}

func (m model) prevPage() page {
	switch m.page {
	case pageHostname:
		return pageWelcome
	case pageUsername:
		return pageHostname
	case pagePassword:
		return pageUsername
	case pageMode:
		return pagePassword
	case pageDisk:
		return pageMode
	case pageDiskConfirm:
		return pageDisk
	case pagePartSelect:
		return pageDiskConfirm
	case pagePartExist, pagePartNewStart:
		return pagePartSelect
	case pagePartNewEnd:
		return pagePartNewStart
	case pagePartConfirm:
		return pagePartSelect
	case pageEFI:
		return pagePartConfirm
	case pageSwap:
		if m.mode == "whole-disk" {
			return pageDiskConfirm
		}
		return pageEFI
	case pageFS:
		return pageSwap
	case pageGPU:
		if m.mode == "whole-disk" {
			return pageFS
		}
		return pageSwap
	case pageGPUNvBus:
		return pageGPU
	case pageGPUIgpuType:
		return pageGPUNvBus
	case pageGPUIgpuBus:
		return pageGPUIgpuType
	case pageSummary:
		return pageGPU
	}
	return pageWelcome
}

func (m model) handleProgress(p ProgressUpdate) (tea.Model, tea.Cmd) {
	if p.Error != nil {
		m.installErr = p.Error
		for i := range m.installSteps {
			if m.installSteps[i].name == p.Step {
				m.installSteps[i].status = stepError
			}
		}
		return m, nil
	}

	for i := range m.installSteps {
		if m.installSteps[i].name == p.Step {
			if p.Done {
				m.installSteps[i].status = stepDone
			} else {
				m.installSteps[i].status = stepRunning
			}
		}
	}

	if p.Message != "" {
		m.logLines = append(m.logLines, p.Message)
		if len(m.logLines) > 6 {
			m.logLines = m.logLines[len(m.logLines)-6:]
		}
	}

	// Check if all done
	allDone := true
	for _, s := range m.installSteps {
		if s.status != stepDone {
			allDone = false
			break
		}
	}
	if allDone {
		m.installDone = true
		m.state.Clear()
		m.goToPage(pageDone)
	}

	return m, m.waitForProgress()
}

func (m model) startInstallation() (tea.Model, tea.Cmd) {
	m.goToPage(pageInstalling)

	// Initialize git for nix flake
	RunSilent("git init")
	RunSilent("git add .")
	RunSilent(`git commit -m "Embedded flake" --allow-empty`)

	cfg := InstallConfig{
		Hostname:    m.hostname,
		Username:    m.username,
		HashedPW:    m.hashedPW,
		Mode:        m.mode,
		DiskDev:     m.diskDev,
		NixosPart:   m.nixosPart,
		EFIPart:     m.efiPart,
		SwapSize:    m.swapSize,
		FSType:      m.fsType,
		GPUChoice:   m.gpuChoice,
		NvidiaBusID: m.nvBusID,
		IGPUBusID:   m.igpuBusID,
		IGPUType:    m.igpuType,
	}

	progressCh := make(chan ProgressUpdate, 10)
	go RunInstallation(cfg, m.state, m.workDir, progressCh)

	return m, m.readProgress(progressCh)
}

// readProgress creates a tea.Cmd that stores the channel and reads from it.
var progressChan chan ProgressUpdate

func (m model) readProgress(ch chan ProgressUpdate) tea.Cmd {
	progressChan = ch
	return m.waitForProgress()
}

func (m model) waitForProgress() tea.Cmd {
	return func() tea.Msg {
		p, ok := <-progressChan
		if !ok {
			return nil
		}
		return progressUpdateMsg(p)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
