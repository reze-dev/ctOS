# ctOS engineering guidelines

These rules apply to all new desktop-shell work. They are intentionally practical: the current repository already shows where a small Quickshell project can become tightly coupled or difficult to package.

## 1. Build the smallest runnable slice

Work in tracker order. A milestone begins with a narrow, demonstrable vertical slice and ends only at its documented gate.

- T1 is an **empty packaged shell**, not a redesigned bar.
- T2 proves window lifecycle, settings, and overlay routing before a panel has real controls.
- A service is introduced only when a visible surface or test needs it.
- Do not begin deferred features while the current milestone has unresolved validation work.

For each implementation change, state the tracker item, acceptance scenario, and whether it changes a public Home Manager option.

## 2. Respect boundaries

- `desktop/` must never import `greeter/`. The greeter remains a separate executable and authentication boundary.
- `common/` may contain only dependency-free visual primitives, tokens, utilities, and configuration helpers. A component that imports desktop, greeter, or compositor settings is not common.
- `desktop/services/` owns backend state, side effects, parsing, retry behavior, and diagnostics.
- `desktop/surfaces/` renders service state and emits named intent. It does not spawn shell commands, parse output, or mutate unrelated global state.
- The OverlayController is the only owner of primary-panel visibility and focus routing. Surfaces must request an operation rather than directly opening a peer panel.
- Hyprland-specific imports remain below `desktop/adapters/hyprland/`; generic UI talks to normalized adapter state.

## 3. Prefer reactive state over polling

- Use native Quickshell/DBus state where available.
- If a command bridge is unavoidable, put it in one adapter with explicit start/stop behavior, bounded retries, parsed typed state, and debouncing.
- Never place a persistent `Process` loop in a QML surface. The CPU/RAM loops in the prototype bar are a migration anti-pattern.
- Model missing backends explicitly with `available` and a diagnostic/status value. Never display dummy values such as `000%` as if they were live data.

## 4. Make side effects narrow and safe

- QML launches only an allowlisted argument array owned by a service/action adapter. Do not construct shell strings from UI text.
- Do not use `sh -c` for logging, file writes, or user-provided values. In particular, replace the current logger’s shell-quoted `echo` approach before desktop logging is reused.
- Store desktop runtime settings under a Home Manager-owned user path; do not add new `/etc/ctos` or `/var/lib/ctos` state for desktop features.
- Do not log credentials, Wi-Fi secrets, notification bodies, or other sensitive user data.
- Session actions are typed/allowlisted. Lock may execute immediately; logout, reboot, and power off require the confirmation state defined in the interaction spec.

## 5. Design QML APIs deliberately

- Use typed properties and named signals for component contracts; avoid broad `var` properties except for framework collections that cannot be typed.
- Keep a component’s public API small: data in, named intent out. Document non-obvious properties beside the component.
- Keep `id`s local. Do not reach across surface/component ownership boundaries.
- Keep bindings declarative. Imperative setup belongs in one lifecycle owner and must be safe on reload.
- Follow `.qmlformat.ini`: four spaces, spaces rather than tabs, Unix newlines. Format only files intentionally changed.
- Make focus behavior explicit for every interactive panel and control. Keyboard and pointer paths must invoke the same service action.

## 6. Treat configuration as an API

- The Nix/Home Manager module is the public configuration contract; QML consumes generated settings rather than Nix expressions or host paths.
- Every new `programs.ctOS` option needs a default, type, documentation, and behavior test/evaluation.
- New optional features need a feature flag and graceful unavailable state.
- Do not rename/remove an option without a documented migration; v1 should prefer stable defaults over a large option surface.
- Keep NixOS system services outside the Home Manager module. Validate and document prerequisites instead of enabling privileged services implicitly.

## 7. Verify before declaring progress

- Run formatting/static checks appropriate to changed files before updating tracker status.
- For UI work, exercise the corresponding manual scenario in `validation-strategy.md`, including an unavailable-backend case when applicable.
- For Nix work, evaluate the flake and a minimal Home Manager configuration before claiming the module works.
- Update `delivery-tracker.md` and record evidence in the implementation change. A checkbox is evidence-backed status, not a to-do reminder.
- Keep unrelated changes out of a milestone. Current legacy installer/greeter/schema repairs remain separate unless they block the active milestone.

## First implementation slice

When coding begins, take only these actions:

1. Add the flake-parts skeleton and package layout.
2. Export a minimal Home Manager module with `programs.ctOS.enable`.
3. Package a new, empty `shell.qml` that imports no greeter code and opens no UI beyond a smoke-test scope.
4. Start it from a user service, then prove flake evaluation, package build, Home Manager evaluation, and service startup.

Only after those four checks pass should the project create the desktop module tree and ambient bar.
