use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

const STATE_FILE: &str = "/tmp/snowflake-install-state.json";

pub const STEP_ORDER: &[&str] = &[
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
];

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct State {
    data: HashMap<String, String>,
}

#[allow(dead_code)]
impl State {
    pub fn new() -> Self {
        let mut state = Self::default();
        state.load();
        state
    }

    pub fn load(&mut self) {
        if let Ok(content) = fs::read_to_string(STATE_FILE) {
            if let Ok(data) = serde_json::from_str(&content) {
                self.data = data;
            }
        }
    }

    pub fn save(&self) {
        if let Ok(json) = serde_json::to_string_pretty(&self.data) {
            let _ = fs::write(STATE_FILE, json);
        }
    }

    pub fn get(&self, key: &str) -> String {
        self.data.get(key).cloned().unwrap_or_default()
    }

    pub fn set(&mut self, key: &str, value: &str) {
        self.data.insert(key.to_string(), value.to_string());
        self.save();
    }

    pub fn set_step(&mut self, step: &str) {
        self.set("step", step);
    }

    pub fn current_step(&self) -> &str {
        self.data
            .get("step")
            .map(|s| s.as_str())
            .unwrap_or(STEP_ORDER[0])
    }

    pub fn should_skip(&self, step_name: &str) -> bool {
        let current = self.current_step();
        let current_idx = STEP_ORDER.iter().position(|&s| s == current);
        let step_idx = STEP_ORDER.iter().position(|&s| s == step_name);
        match (current_idx, step_idx) {
            (Some(ci), Some(si)) => si < ci,
            _ => false,
        }
    }

    pub fn clear(&mut self) {
        self.data.clear();
        let _ = fs::remove_file(STATE_FILE);
    }
}

impl Drop for State {
    fn drop(&mut self) {
        // Auto-save on drop if we haven't cleared
        if !self.data.is_empty() {
            let p = Path::new(STATE_FILE);
            if p.exists() {
                self.save();
            }
        }
    }
}
