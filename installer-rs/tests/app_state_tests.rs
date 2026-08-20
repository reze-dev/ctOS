use northstar_installer::app::{App, DualBootEntry, Page, ProfileChoice};
use northstar_installer::state::State;

#[test]
fn test_app_initial_state() {
    let app = App::new("/tmp/test-northstar-workdir".to_string());
    assert_eq!(app.page, Page::Welcome);
    assert!(!app.should_quit);
    assert!(app.err.is_empty());
}

#[test]
fn test_app_text_input_and_cursor() {
    let mut app = App::new("/tmp/test-northstar-workdir".to_string());
    app.go_to_page(Page::Hostname);

    app.type_char('m');
    app.type_char('y');
    app.type_char('h');
    app.type_char('o');
    app.type_char('s');
    app.type_char('t');

    assert_eq!(app.input, "myhost");
    assert_eq!(app.input_value(), "myhost");
    assert_eq!(app.cursor_pos, 6);

    app.delete_char();
    assert_eq!(app.input, "myhos");
    assert_eq!(app.cursor_pos, 5);
}

#[test]
fn test_app_profile_and_feature_toggling() {
    let mut app = App::new("/tmp/test-northstar-workdir".to_string());
    app.apply_profile(ProfileChoice::Desktop);

    // Hyprland is enabled by default on Desktop
    assert_eq!(app.config.features[0].id, "hyprland");
    assert!(app.config.features[0].enabled);

    // Toggle hyprland off
    app.cursor = 0;
    app.toggle_current_feature();
    assert!(!app.config.features[0].enabled);

    // Toggle hyprland back on
    app.toggle_current_feature();
    assert!(app.config.features[0].enabled);

    // Switch to Base profile (minimal)
    app.apply_profile(ProfileChoice::Base);
    assert!(!app.config.features[0].enabled);
}

#[test]
fn test_app_dual_boot_toggling() {
    let mut app = App::new("/tmp/test-northstar-workdir".to_string());
    app.config.dual_boot_entries = vec![
        DualBootEntry {
            name: "Fedora Linux".to_string(),
            efi_path: "/EFI/fedora/shimx64.efi".to_string(),
            disk_uuid: "CB41-6695".to_string(),
            enabled: true,
        },
    ];

    assert!(app.config.dual_boot_entries[0].enabled);
    app.cursor = 0;
    app.toggle_current_dual_boot();
    assert!(!app.config.dual_boot_entries[0].enabled);
}

#[test]
fn test_state_step_transitions_and_skip() {
    let mut state = State::new();
    state.clear();

    assert_eq!(state.current_step(), "generate_config");
    assert!(!state.should_skip("generate_config"));
    assert!(!state.should_skip("partition"));

    state.set_step("partition");
    assert_eq!(state.current_step(), "partition");
    assert!(state.should_skip("generate_config"));
    assert!(!state.should_skip("partition"));
    assert!(!state.should_skip("install_nixos"));

    state.set_step("install_nixos");
    assert!(state.should_skip("generate_config"));
    assert!(state.should_skip("partition"));
    assert!(!state.should_skip("install_nixos"));

    state.clear();
}
