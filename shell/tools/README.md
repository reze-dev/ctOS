# ctOS shell tooling

Headless verification for the shell. Nothing here is shipped in the package --
`shell/nix/package.nix` strips nothing from this directory, so keep it
development-only.

## Why a compositor is required

The shell is `wlr-layer-shell` only. Every surface is a Quickshell `PanelWindow`,
which maps to a layer surface. Qt's `offscreen` platform cannot present one --
quickshell fails with `No PanelWindow backend loaded` -- and `qmltestrunner`
cannot either. So visual checks need a real Wayland compositor with layer-shell
support.

`sway` with `WLR_BACKENDS=headless` and the **pixman** renderer provides one with
no GPU, no X server and no input devices. That is what makes this work over SSH
and in CI.

## ctos-shot.sh

Boots sway headless, runs the shell, screenshots the output with `grim`.

```bash
ctos-shot                              # /tmp/ctos-shell.png at 1280x800
ctos-shot /tmp/hover.png 1280x800 8     # explicit path, size, settle seconds
ctos-shot /tmp/x.png 640 480 4          # size as separate args
CTOS_KEEP=1 ctos-shot                   # leave the compositor up for poking at
```

Geometry is accepted as `1280x800` or as two arguments. Quickshell's stdout is
echoed on exit, because a surface that fails to appear usually explains itself
there.

Three environment details that are easy to get wrong and are handled in the
script:

- `WLR_HEADLESS_OUTPUTS=1` is required. The headless backend creates no outputs
  on its own and sway exits with `Could not find config for output`.
- The output name is not stable across wlroots versions, so the config matches
  `output *` rather than `HEADLESS-1`.
- `QT_QPA_PLATFORM` must be `wayland`. The devshell presets it to `offscreen`
  for `qmllint` and `qmltestrunner`, which is fatal here.

## ctos-pick.py

Reads a render and prints exact colours, so design tokens are verifiable rather
than approximate.

```bash
ctos-pick shot.png                      # dominant colours
ctos-pick shot.png --top 20             # more of them
ctos-pick shot.png --crop 528,0,224,34  # just the notch
ctos-pick shot.png --at 640,15          # one pixel
```

Percentages matter more than the hex list: the surface is translucent over a
background and pixman dithers, so a crop of the notch legitimately contains
several hundred distinct colours. To check a token, sample a pixel with `--at`.
To check that a surface rendered at all, look at the top colour's share -- the
script warns above 92 %, which is what an empty frame looks like.

A wall with a distinct background is worth setting before capturing: the notch
surface is `rgba(5,14,30,0.94)`, so what is behind it changes the measured
value.

## Adding this to CI

`flake/checks.nix` currently gates on parse errors only, because qmllint cannot
resolve QtQuick's `linktarget Qt6::qtquick2plugin` from a Nix sandbox and so
cannot type-check. Render comparison needs the compositor above and a baseline
image per surface state. `ctos-shot` plus a pixel comparison is enough to build
that; it is deliberately not wired up yet because a baseline has to be reviewed
by a human before it becomes an assertion.
