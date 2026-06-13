# Change-Scope Discipline

A solo-developer discipline for keeping every change tight: **every change has a
stated scope, and the diff that ships contains only changes that serve that scope.**
Two hooks in this plugin implement it — a pre-edit gate and a pre-commit reminder.

---

## The core principle

Collateral drift compounds invisibly. A "while I'm here" cleanup, an autoformat
sweep, a copilot accept mid-edit, a mass-rename script that overreached — each
small unintended mutation accumulates until the code is structurally different
from where you meant to take it, without anyone consciously deciding. The
discipline catches drift at two moments: when you're about to edit an unplanned
file, and when you're about to commit.

---

## The `.planning/` manifest workflow

When you start a change:

1. **Find or create a scope manifest in `.planning/`.** Either the active plan's
   `.planning/<plan>/scope.md`, or a standalone `.planning/<workstream>-scope.md`
   for a scope-only sidequest. Writing it IS the scope-thinking step.

2. **Declare the in-scope file list before editing:**

   ```markdown
   # Scope manifest — <change description>

   Files in scope:
   - path/to/file1.ext
   - path/glob/*.ts — rationale after an em-dash is fine
   - docs/**/*.md
   ```

3. **Then edit code.** Touch only files declared in the manifest.

The `change-scope-pre-edit-gate.sh` hook reads this manifest. If you try to
Edit/Write a file that isn't covered by a "Files in scope" bullet (and the
manifest wasn't edited in the last ~10 minutes), it blocks the edit and tells you
how to proceed.

### Mid-change expansion — scope before code

If you discover mid-change that you need to touch a file outside the manifest:

1. **Stop touching code.**
2. **Edit the manifest first** — add the new file with a one-line rationale.
3. **Then edit the file.**

The wrong order is "edit the file, then add it to the manifest to match what you
did" — that's scope expanding to fit what you happened to touch. The pre-edit gate
enforces the right order: a recent manifest edit opens a grace window during which
the just-added file is allowed.

### Proportionality carve-out

Trivial planning-only or doc-only changes don't need a manifest file. The gate
only enforces inside a git work tree that already has a `.planning/` scope
manifest — if a project hasn't adopted the discipline (no manifest), the gate
stays silent. Don't manufacture ceremony for a one-line typo fix; do declare scope
for anything that touches code across more than a file or two.

### Escape hatches

- **`.scope-ignore`** (gitignore-style patterns) — for auto-generated / vendored /
  out-of-discipline files you don't want the gate to police.
- **`SCOPE_BYPASS_REASON="<reason>"`** env var — a one-off, audit-logged bypass.
  Sustained use means the discipline isn't right for this case; refine it rather
  than silence it.

---

## Component A — iatrogenic script risk

Don't reach for a script to mass-mutate code when manual editing is safer. Before
writing a one-shot script (rename across 25 files, swap a class name everywhere,
normalize imports repo-wide), pause and ask:

1. **Is the code in a fragile state right now?** (broken build, in-flight refactor,
   recent regression, mid-migration) — if yes, edit manually.
2. **Has the script been validated on a 3-file sample first?** — if no, validate
   before scaling.
3. **Does it have a `--dry-run` mode, and have you reviewed its output?** — if no,
   add it.

Bugs in mass-mutation scripts distribute uniformly across every touched file —
that's the worst place to introduce a new defect. A script can "succeed" by every
automated signal (build green, tests green, rescan clean) and still have
overreached. Default to manual; reach for a script only when the count is
genuinely intractable AND the gates above are cleared.

---

## Component B — hunk-level diff audit

Before every commit, read `git diff --staged` **hunk by hunk**. For each hunk ask:
does this serve the stated scope? Yes → keep. No → revert it before committing:

```bash
git restore --staged --worktree -p <file>
```

Audit at the **hunk** level, not the file level — a file with 12 changed hunks can
hide 6 out-of-scope hunks behind a single "yes, this file changed" glance.

For a branch or PR, audit the **cumulative** diff against the base branch, not just
the latest commit — drift compounds across commits:

```bash
git diff <base-branch>...HEAD
```

The `change-scope-discipline-reminder.sh` hook fires on `git commit` to surface
this ritual at the right moment. It's advisory (non-blocking) — the discipline is
yours to run.

---

## Anti-patterns (read once)

- ❌ Editing code first, then updating the manifest to match what you touched.
- ❌ Trusting "build green + tests green" as proof of correctness.
- ❌ Bulk scripts without 3-file sample validation or `--dry-run`.
- ❌ Autoformat-on-save changes bundled into a scoped commit.
- ❌ "While I'm here" cleanup creep mixed into a scoped change — split it out.
- ❌ File-level diff review instead of hunk-level.
- ❌ Reviewing only the latest commit for a PR instead of the cumulative branch diff.
