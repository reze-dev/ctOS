package main

import (
	"fmt"
	"os"
	"strings"

	"golang.org/x/term"
)

// ANSI color codes
const (
	Green  = "\033[0;32m"
	Yellow = "\033[1;33m"
	Red    = "\033[0;31m"
	Cyan   = "\033[0;36m"
	Bold   = "\033[1m"
	Reset  = "\033[0m"
)

func Msg(text string)  { fmt.Printf("%s%s%s\n", Green, text, Reset) }
func Warn(text string) { fmt.Printf("%s%s%s\n", Yellow, text, Reset) }
func Err(text string)  { fmt.Printf("%s%s%s\n", Red, text, Reset) }
func Step(num, text string) {
	fmt.Printf("\n%s[%s] %s%s\n", Green, num, text, Reset)
}

func Prompt(prompt string) string {
	fmt.Print(prompt)
	var input string
	fmt.Scanln(&input)
	return input
}

func PromptDefault(prompt, def string) string {
	fmt.Print(prompt)
	var input string
	fmt.Scanln(&input)
	if input == "" {
		return def
	}
	return input
}

func PromptRequired(prompt, errMsg string) string {
	val := Prompt(prompt)
	if val == "" {
		Die(errMsg)
	}
	return val
}

func PromptPassword(prompt string) string {
	fmt.Print(prompt)
	pw, err := term.ReadPassword(int(os.Stdin.Fd()))
	fmt.Println() // newline after hidden input
	if err != nil {
		Die(fmt.Sprintf("Failed to read password: %v", err))
	}
	return strings.TrimSpace(string(pw))
}

func ConfirmYes(prompt string) {
	ans := Prompt(prompt + " ")
	if ans != "yes" {
		Die("Aborted.")
	}
}

func Die(text string) {
	Err(text)
	panic("fatal")
}
