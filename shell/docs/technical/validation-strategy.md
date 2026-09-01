# ctOS validation strategy

## Evidence policy

Each tracker item is complete only when its implementation is reviewed and the relevant command/manual evidence is recorded in its change or pull request. A successful QML launch is not proof that packaging, input routing, or degraded states work.

## Automated gates

| Gate | Starts at | Required evidence |
| --- | --- | --- |
| Formatting/static QML checks | T1 | QML formatter/linter command succeeds for changed QML. |
| Flake evaluation | T1 | `nix flake check` evaluates exported package and modules. |
| Package build | T1 | ctOS package builds with all packaged QML/resources present. |
| Home Manager evaluation | T1 | A minimal `programs.ctOS.enable = true` configuration evaluates. |
| Shell smoke test | T1 | User service starts the empty shell and exits/restarts predictably. |
| Regression checks | T7 | Existing greeter test mode remains launchable independently. |

Current T1 commands are `nix flake check --no-build` and `nix build .#ctos-shell`. The latter is also checked for the packaged `share/ctos/shell.qml` smoke entry. Graphical service startup is validated manually on the Hyprland acceptance host.

## Manual acceptance matrix

| Area | Scenario | Expected result |
| --- | --- | --- |
| Multi-monitor | Add/remove an output while the shell runs. | One bar per active output; panels close safely if their target output disappears. |
| Overlay routing | Open each primary panel from keybind and pointer. | One primary overlay; correct focus; `Escape` and background close it. |
| Command Deck | Search, navigate, launch, and invoke an action. | Query has initial focus; keyboard/mouse outcomes match; destructive actions ask for confirmation. |
| System controls | Change/mute volume, mic, brightness, Wi-Fi, and power profile. | State updates reactively or control is clearly unavailable. |
| Session safety | Request lock/logout/reboot/power off. | Lock is immediate; other actions require the specified confirmation state. |
| Notifications | Send normal and urgent notifications; enable do-not-disturb. | Toasts/history respect urgency and do-not-disturb; no duplicated server behavior. |
| Accessibility | Enable reduced motion and navigate controls by keyboard. | Decorative motion disappears; focus remains visible and usable. |
| Failure handling | Disable/stop an optional backend. | Shell remains running; affected widget/control degrades cleanly with diagnostic output. |

## Test environments

- **Primary acceptance:** the maintainer’s ctos NixOS + Hyprland configuration.
- **Package evaluation:** a clean Nix evaluation independent of host-specific paths.
- **Greeter safety:** a non-production/test configuration only; do not use a live display-manager session as the first verification target.

## Completion evidence for v1

T8 is complete when all T1–T7 exit gates are satisfied, the manual matrix has passed on the primary acceptance host, `nix flake check` is clean, and the user-facing Nix activation/recovery documentation matches the tested path.
