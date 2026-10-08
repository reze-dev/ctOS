# Target specification

The authoritative design target for the ctOS shell.

| File | Purpose |
| --- | --- |
| [`neon-notch-spec.md`](neon-notch-spec.md) | The specification. Behaviour, geometry, interaction, implementation order. |
| [`colors.md`](colors.md) | Palette, navy ramp, semantic token mapping for `Theme.qml`. |
| `images/` | The four reference diagrams. Source of truth for visual decisions. |

## Reference images

| # | File | State |
| --- | --- | --- |
| 1 | [`images/01-notch-idle.png`](images/01-notch-idle.png) | Unexpanded / idle notch |
| 2 | [`images/02-notch-expanded.png`](images/02-notch-expanded.png) | Expanded / hover notch |
| 3 | [`images/03-command-center.png`](images/03-command-center.png) | Adaptive Command & Control Center |
| 4 | [`images/04-calendar-timeline.png`](images/04-calendar-timeline.png) | Calendar C — Event Timeline Fusion |

`images/before/` holds the current green-on-graphite shell for comparison. These
are historical only and carry no specification weight.

## Authority order

1. The reference images decide visual and layout questions.
2. `neon-notch-spec.md` decides behaviour, and decides every question the images
   leave ambiguous — it states the chosen interpretation rather than deferring.
3. `colors.md` decides colour.

Where an older document contradicts this directory, this directory wins. The
`../design/` documents have been reconciled to agree; if they ever drift again,
this directory is correct.

## Conventions for implementers

- Read `neon-notch-spec.md` §7 before starting. It fixes the order, and the early
  steps exist to make later steps verifiable.
- Do not introduce fixed heights for any CCC section. The spec's height
  requirement is content-driven throughout.
- Do not add a second top-edge surface. The notch is the only one.
- New colours go into `Theme.qml` as tokens. Do not inline hex values.
- `Settings.reducedMotion` must be honoured by anything that animates.
