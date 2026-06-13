# Planning Folder Format

The `.planning/` convention this plugin's hooks understand and enforce. Adopt it
in any project and the hooks light up automatically; ignore it and the hooks stay
silent (every hook fails open when there's no `.planning/`).

---

## Why

Three problems this format solves:

1. **Visual collision** when many plan artifacts share a flat folder — a per-plan
   subfolder with short filenames keeps each plan self-contained.
2. **No archive answer** — completed plans pile up next to active work. A
   `.planning/archive/` folder gives them a home (and preserves git history).
3. **Resume-handoff pollution** — a single handoff doc mixes plan progress with
   incidental sidequest notes. A 2-tier resume (global vs per-plan) separates them.

---

## Layout

```
.planning/
├── resume-next-session.md          ← GLOBAL handoff (out-of-scope / sidequest carries)
├── archive/
│   └── <completed-plan>/           ← whole plan folder migrates here on completion
└── <plan-name>/                    ← per-plan folder, self-contained
    ├── plan.md                     ← multi-phase plan, source of truth
    ├── scope.md                    ← active scope manifest (files in scope)
    └── resume-next-session.md      ← PROJECT-SCOPED handoff (this plan's continuation)
```

- **Plan-name** = kebab-case workstream identifier (`payments-refactor/`,
  `onboarding-redesign/`). Use the same string as your commit-message scope prefix.
- **Short filenames inside the folder** — `plan.md`, `scope.md`,
  `resume-next-session.md`. The folder name carries the context; don't repeat it.
- Multiple plans can be in flight at once — each folder is independent.

A lightweight **scope-only sidequest** is valid too: just a
`.planning/<workstream>/scope.md` with no `plan.md`. It still gets the same
completion → archive flow (see Completion marker below).

---

## The `**N.M**` checkbox step-ID format

Every checkable step in `plan.md` is a markdown bullet with a bold-bracketed,
dotted step ID:

```markdown
- [x] **0.1** First step in phase 0
- [ ] **0.2** Another step
- [x] **1.10** Tenth step in phase 1
```

Pattern: `^[ \t]*[-*]\s+\[([ xX])\]\s+\*\*([0-9]+(?:\.[0-9]+)+)\*\*`

Conventions:
- `N.0` — the phase summary line (check when the whole phase is done).
- `N.1`, `N.2`, … — individual steps within phase N.
- Step IDs MUST have at least one dot — `0.1` matches, bare `1` does not.

The hooks read these boxes to (a) block "phase N complete" claims while phase N's
boxes are still open, and (b) flag a phase whose `**N.0**` summary box is still
unchecked while every `**N.x**` sub-step is checked.

---

## The `**99.0**` completion marker (human-gated)

The final checkbox of a plan is the designated completion gate. It carries the
`<!-- plan-complete-trigger -->` HTML comment marker:

```markdown
- [ ] **99.0** Plan COMPLETE <!-- plan-complete-trigger -->
```

Rules the hooks enforce:

- **Only a human flips `**99.0**`.** An agent must NEVER flip it from `[ ]` to
  `[x]` without the human's explicit, specific instruction — "check the 99.0 box",
  "mark it complete", "flip 99.0". Generic instructions ("complete the plan", "do
  the rest", "finish it") do NOT authorize it. `plan-complete-flip-guard.sh` blocks
  the flip unless `PLAN_COMPLETE_AUTHORIZED` is set to the human's words.
- **The flip triggers archival.** When `**99.0**` goes `[x]`,
  `plan-completion-detector.sh` notices and suggests moving the folder to
  `.planning/archive/`.
- A scope-only sidequest puts the same `**99.0** ... <!-- plan-complete-trigger -->`
  line at the bottom of its `scope.md`.

---

## The 2-tier resume

Mirrors the global-vs-project pattern (like a global config file vs a per-project
one):

| File | Holds |
|---|---|
| `.planning/resume-next-session.md` (GLOBAL) | Out-of-scope sidequest carries, blocker fixes, observations that don't belong to any one plan. |
| `.planning/<plan>/resume-next-session.md` (PER-PLAN) | Continuation context for THAT plan only: locked decisions, current phase state, next action, plan-specific gotchas. |

On session start, `auto-load-resume-notes.sh` surfaces the most relevant resume
file (preferring an active plan-scoped one over the global pointer) and tells the
new session to read it in full. On session end, `end-session-handoff.sh` requires
writing/refreshing the handoff. `plan-folder-discipline-reminder.sh` nudges you to
keep plan-specific content out of the global file and vice versa.

---

## Archival

When a plan is done (human flipped `**99.0**`), move the whole folder:

```bash
git mv .planning/<plan-name> .planning/archive/<plan-name>
git commit -m 'chore(planning): archive completed <plan-name>'
```

Moving (not deleting) preserves git history. If your repo has a broad
`archive/`-style `.gitignore` rule, make sure `.planning/archive/**` is un-ignored.
