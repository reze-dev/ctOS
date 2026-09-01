# ctOS technical package

These documents turn the approved design into an implementation baseline. They are deliberately separate from the product design documents: design defines the intended experience; this package records repository facts, technical decisions, delivery gates, and validation evidence.

| Document | Purpose |
| --- | --- |
| [Repository audit](repository-audit.md) | Current codebase inventory, reusable assets, constraints, and migration risks. |
| [Technical decision log](decision-log.md) | Accepted implementation decisions and deferred decisions. |
| [Delivery tracker](delivery-tracker.md) | Ordered milestones, definition of done, and the current implementation state. |
| [Validation strategy](validation-strategy.md) | Checks and manual acceptance evidence required for each milestone. |
| [Engineering guidelines](engineering-guidelines.md) | Rules for implementing ctOS without coupling, unsafe runtime behavior, or undocumented scope growth. |

## Update rules

- Update the tracker in the same change that implements or verifies work.
- Mark an item **done** only after its listed acceptance evidence is recorded.
- Mark an item **blocked** with the missing external dependency or decision; do not use it for ordinary unfinished work.
- Keep the repository audit factual. Planned structure belongs in the decision log or tracker, not in the audit.
