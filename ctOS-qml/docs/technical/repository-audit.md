# Repository audit

**Audited:** 2026-09-01  
**Baseline:** `468be1b` (`init: forked to create a standalone NixOS distribution`)

## Current shape

| Area | Current state | Reuse decision |
| --- | --- | --- |
| Desktop entry point | `bar.qml` is one full-width `PanelWindow`. | Replace with a desktop `shell.qml`; retain individual visual primitives only after review. |
| Bar UI | Workspace display, CPU/RAM polling, network text, PipeWire volume/mic, and clock are implemented inline or under `bar/`. | Treat as a prototype, not a v1 bar implementation. |
| Compositor support | `bar/config/Desktop.qml` detects Hyprland/Niri, but `WorkspaceManager` implements only Hyprland and throws for other compositors. | Establish Hyprland as v1; move compositor logic behind an adapter. |
| Shared QML | `common/` provides theme, env/config paths, logging, utility functions, focus manager, and accents. | Reuse selectively; remove greeter coupling from desktop-shared components. |
| Greeter/locker | Separate `greeter.qml` entry point with greetd, PAM/lockd, session, terminal, and test-mode services. | Preserve as an independent security boundary. |
| Install path | `install.sh` copies to `/opt/ctos`, writes `/etc/ctos`, and scaffolds greetd/compositor configuration. | Legacy only; do not extend for the NixOS desktop shell. |
| Packaging | No `flake.nix`, Nix modules, or package derivation exists. | First implementation milestone. |
| Tests/checks | No automated test suite, flake check, or CI configuration exists. | Add validation incrementally with packaging. |

## Existing runtime dependencies

The current QML imports show that this repository already relies on Quickshell, QtQuick, Quickshell I/O, Quickshell networking, PipeWire, Hyprland, UPower, Greetd, and PAM/Wayland locking APIs. The greeter documentation separately calls out `greetd`, `uwsm`, and optionally `cage`.

The prototype bar additionally starts persistent shell loops to read `/proc/stat` and `free`. Those loops are confined to the prototype and must not be carried into the v1 ambient bar. Desktop services own data acquisition; surfaces render reactive state.

## Assets and visual material

- `extras/wallpapers/` contains the curated dark wallpapers selected for v1.
- `bar/resources/` contains corner and distribution SVGs that may be reviewed for reuse.
- `greeter/resources/` contains lockscreen-specific identity and barcode assets. Do not move authentication/identity assets into desktop surfaces without an explicit visual decision.
- `common/Theme.qml` is the current palette source. It is a useful reference but does not yet define the complete token system required by the design documents.

## Migration constraints and risks

1. **No packaging boundary exists.** Imports currently resolve from a source-tree layout and the imperative installer copies the whole repository. Nix packaging must establish a stable QML/resource layout before the shell can be activated declaratively.
2. **The bar is monolithic.** `bar.qml` owns window layout, hardware polling, networking presentation, and indicators. Extending it for overlays would couple unrelated behavior; new surfaces must be composed under the planned shell scope instead.
3. **Shared code is not universally shared.** `common/components/Accents.qml` imports greeter settings, so it cannot be used by the desktop as-is. Shared primitives must have no greeter or compositor dependency.
4. **Current configuration is system-path oriented.** `common/Paths.qml` names `/etc/ctos` and `/var/lib/ctos`; desktop settings need a generated Home Manager-owned user path. Greeter compatibility must be maintained independently.
5. **Documentation drift exists.** The root and bar READMEs still describe an early WIP bar and imperative install path. Update them only when the corresponding Nix replacement is usable.
6. **Notification ownership is exclusive.** Enabling a native notification server requires detecting/documenting conflicts with any existing daemon.
7. **Two shared-code repairs are required before reuse.** `common/components/Accents.qml` imports greeter settings despite its shared location, and `common/Logger.qml` appends debug output through shell-quoted `echo` to a fixed `/tmp/ctos.log` path. The desktop foundation must decouple the former and use a safe, user-runtime logging policy for the latter.
8. **Greeter schema/config drift needs containment.** `schema/greeter.schema.json` describes a legacy top-level shape while the current `GeneralDto` loads a nested `general` object. Do not expand the schema during desktop work; reconcile it as a separately verified greeter maintenance task.

## Baseline conclusion

The repository has a reusable visual direction and a valuable greeter, but the desktop implementation is pre-foundation. The next code milestone is packaging and a minimal shell scaffold—not an incremental expansion of `bar.qml`.
