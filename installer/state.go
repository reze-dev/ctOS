package main

import (
	"encoding/json"
	"os"
)

const stateFile = "/tmp/snowflake-install-state.json"

// StepOrder defines the ordered list of installation checkpoints.
var StepOrder = []string{
	"gather_host",
	"gather_user",
	"gather_mode",
	"gather_disk",
	"gather_swap_fs_gpu",
	"confirm",
	"generate_config",
	"partition",
	"install_nixos",
	"copy_flake",
	"done",
}

// State holds persistent installer state with checkpoint resume.
type State struct {
	Data map[string]string
}

func NewState() *State {
	s := &State{Data: make(map[string]string)}
	s.Load()
	return s
}

func (s *State) Load() {
	data, err := os.ReadFile(stateFile)
	if err != nil {
		return
	}
	_ = json.Unmarshal(data, &s.Data)
}

func (s *State) Save() {
	data, _ := json.MarshalIndent(s.Data, "", "  ")
	_ = os.WriteFile(stateFile, data, 0644)
}

func (s *State) Get(key string) string {
	return s.Data[key]
}

func (s *State) Set(key, value string) {
	s.Data[key] = value
	s.Save()
}

func (s *State) SetStep(step string) {
	s.Set("step", step)
}

func (s *State) CurrentStep() string {
	if step, ok := s.Data["step"]; ok {
		return step
	}
	return StepOrder[0]
}

func (s *State) ShouldSkip(stepName string) bool {
	current := s.CurrentStep()
	currentIdx := indexOf(StepOrder, current)
	stepIdx := indexOf(StepOrder, stepName)
	if currentIdx < 0 || stepIdx < 0 {
		return false
	}
	return stepIdx < currentIdx
}

func (s *State) Clear() {
	s.Data = make(map[string]string)
	os.Remove(stateFile)
}

func indexOf(slice []string, item string) int {
	for i, v := range slice {
		if v == item {
			return i
		}
	}
	return -1
}
