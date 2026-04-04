package main

import "github.com/charmbracelet/lipgloss"

var (
	// Colors — icy snow theme
	cyan   = lipgloss.Color("#00BFFF")
	blue   = lipgloss.Color("#5B7FFF")
	green  = lipgloss.Color("#73F59F")
	red    = lipgloss.Color("#FF5F87")
	yellow = lipgloss.Color("#FADA5E")
	white  = lipgloss.Color("#EEEEEE")
	dimClr = lipgloss.Color("#666666")

	titleStyle = lipgloss.NewStyle().
			Foreground(cyan).
			Bold(true)

	stepStyle = lipgloss.NewStyle().
			Foreground(blue).
			Bold(true)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(cyan).
			Padding(1, 2).
			MarginTop(1)

	labelStyle = lipgloss.NewStyle().
			Foreground(white).
			Bold(true)

	hintStyle = lipgloss.NewStyle().
			Foreground(dimClr)

	selectedStyle = lipgloss.NewStyle().
			Foreground(cyan).
			Bold(true)

	unselectedStyle = lipgloss.NewStyle().
			Foreground(white)

	successMark = lipgloss.NewStyle().Foreground(green).Render("✓")
	errorMark   = lipgloss.NewStyle().Foreground(red).Render("✗")
	pendingMark = lipgloss.NewStyle().Foreground(dimClr).Render("○")
	warnStyle   = lipgloss.NewStyle().Foreground(yellow)
	errStyle    = lipgloss.NewStyle().Foreground(red).Bold(true)
)
