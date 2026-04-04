package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ── Page enum ──────────────────────────────────────────────────────

type page int

const (
	pageWelcome page = iota
	pageHostname
	pageUsername
	pagePassword
	pagePasswordConfirm
	pageMode
	pageDisk
	pageDiskConfirm
	pagePartSelect
	pagePartNewStart
	pagePartNewEnd
	pagePartExist
	pagePartConfirm
	pageEFI
	pageSwap
	pageFS
	pageGPU
	pageGPUNvBus
	pageGPUIgpuType
	pageGPUIgpuBus
	pageSummary
	pageInstalling
	pageDone
)

// ── Messages ───────────────────────────────────────────────────────

type progressUpdateMsg ProgressUpdate
type cmdOutputMsg string
type hashDoneMsg struct {
	hash string
	err  error
}

// ── Step tracking ──────────────────────────────────────────────────

type stepStatus int

const (
	stepPending stepStatus = iota
	stepRunning
	stepDone
	stepError
)

type installStep struct {
	name   string
	label  string
	status stepStatus
}

// ── Model ──────────────────────────────────────────────────────────

type model struct {
	page   page
	width  int
	height int
	err    string

	input    textinput.Model
	spinner  spinner.Model
	progress progress.Model

	choices []string
	cursor  int

	hostname    string
	username    string
	password    string
	passConfirm string
	mode        string
	diskDev     string
	nixosPart   string
	efiPart     string
	swapSize    string
	fsType      string
	gpuChoice   string
	nvBusID     string
	igpuType    string
	igpuBusID   string
	hashedPW    string

	cmdOutput    string
	partNewStart string

	installSteps []installStep
	logLines     []string
	installDone  bool
	installErr   error

	state   *State
	workDir string
}

func newModel(state *State, workDir string) model {
	ti := textinput.New()
	ti.Focus()
	ti.CharLimit = 64

	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = lipgloss.NewStyle().Foreground(cyan)

	pg := progress.New(progress.WithDefaultGradient())

	return model{
		page:     pageWelcome,
		input:    ti,
		spinner:  sp,
		progress: pg,
		state:    state,
		workDir:  workDir,
		installSteps: []installStep{
			{name: "generate_config", label: "Generate configuration"},
			{name: "partition", label: "Partition disk"},
			{name: "install_nixos", label: "Install NixOS"},
			{name: "copy_flake", label: "Copy flake to system"},
		},
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(textinput.Blink, m.spinner.Tick)
}

// goToPage transitions to a new page, configuring the input for it.
func (m *model) goToPage(p page) {
	m.page = p
	m.err = ""
	m.cursor = 0
	m.input.Reset()

	switch p {
	case pageHostname:
		m.input.Placeholder = "my-laptop"
		m.input.EchoMode = textinput.EchoNormal
	case pageUsername:
		m.input.Placeholder = "username"
		m.input.EchoMode = textinput.EchoNormal
	case pagePassword, pagePasswordConfirm:
		m.input.Placeholder = ""
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '•'
	case pageMode:
		m.choices = []string{"Whole disk — fresh install, wipes entire disk", "Partition only — dual-boot, specific partition"}
	case pageDisk:
		m.input.Placeholder = "nvme0n1 or sda"
		m.input.EchoMode = textinput.EchoNormal
		m.cmdOutput, _ = RunCapture("lsblk -d -n -o NAME,SIZE,MODEL,TYPE 2>/dev/null | grep disk")
	case pageDiskConfirm, pagePartConfirm:
		m.input.Placeholder = ""
		m.input.EchoMode = textinput.EchoNormal
	case pagePartSelect:
		m.choices = []string{"Use an existing partition", "Create a new partition from unallocated space"}
	case pagePartNewStart:
		m.input.Placeholder = "100GiB"
		m.input.EchoMode = textinput.EchoNormal
	case pagePartNewEnd:
		m.input.Placeholder = "200GiB or 100%"
		m.input.EchoMode = textinput.EchoNormal
	case pagePartExist:
		m.input.Placeholder = "nvme0n1p5"
		m.input.EchoMode = textinput.EchoNormal
		m.cmdOutput, _ = RunCapture(fmt.Sprintf("lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS /dev/%s 2>/dev/null", m.diskDev))
	case pageEFI:
		m.input.Placeholder = "nvme0n1p1"
		m.input.EchoMode = textinput.EchoNormal
		m.efiPart = ""
		out, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME,FSTYPE,PARTTYPE /dev/%s 2>/dev/null", m.diskDev))
		for _, line := range strings.Split(out, "\n") {
			fields := strings.Fields(line)
			if len(fields) >= 3 && fields[1] == "vfat" && strings.Contains(strings.ToLower(fields[2]), "c12a7328") {
				m.efiPart = "/dev/" + fields[0]
				break
			}
		}
		if m.efiPart != "" {
			m.cmdOutput = fmt.Sprintf("Auto-detected ESP: %s", m.efiPart)
		} else {
			m.cmdOutput, _ = RunCapture(fmt.Sprintf("lsblk -n -o NAME,SIZE,FSTYPE,LABEL /dev/%s 2>/dev/null", m.diskDev))
		}
	case pageSwap:
		m.input.Placeholder = "8G"
		m.input.EchoMode = textinput.EchoNormal
	case pageFS:
		m.choices = []string{"btrfs (recommended)", "ext4"}
	case pageGPU:
		m.choices = []string{"None / Intel / AMD", "NVIDIA (proprietary)", "NVIDIA + AMD/Intel hybrid (Prime)"}
	case pageGPUNvBus:
		m.input.Placeholder = "PCI:1:0:0"
		m.input.EchoMode = textinput.EchoNormal
		m.cmdOutput, _ = RunCapture("lspci 2>/dev/null | grep -E 'VGA|3D'")
	case pageGPUIgpuType:
		m.choices = []string{"Intel", "AMD"}
	case pageGPUIgpuBus:
		m.input.Placeholder = "PCI:0:2:0"
		m.input.EchoMode = textinput.EchoNormal
	}

	m.input.Focus()
}
