---
name: bump-version-stage-commit-push
description: >
  Bump the project version, stage all intended files, generate an appropriate
  commit message from the staged diff, commit, and push the current branch.
  Use this skill when the user asks for a version bump plus full git release
  flow in one pass.
---

## Overview

This skill performs a lightweight release-style git workflow for this
repository:

1. Bump the version
2. Stage the intended files
3. Review staged scope
4. Generate a commit message from the staged changes
5. Commit
6. Push the current branch

The version source and bump method depend on which repo is being released.
Detect the repo from the `repo=` argument or the current working directory,
then follow the repo-specific rules below.

---

## Canonical version files by repo

### devops (`~/Documents/GitHub/devops`)

| File | Rule |
|------|------|
| `scripts/git_sync.sh` | Contains `readonly SCRIPT_VERSION="X.Y.Z"` |

Read the current value:

```bash
grep 'SCRIPT_VERSION=' scripts/git_sync.sh
```

Bump with `sed -i`. Default to a **patch** bump unless the user specifies otherwise.

### agora_na_copa_2026 (`~/Documents/GitHub/agora_na_copa_2026`)

| File | Rule |
|------|------|
| `package.json` | Canonical version; `package-lock.json` must stay in sync |

Bump with:

```bash
npm version patch --no-git-tag-version
```

Stage both files:

```bash
git add package.json package-lock.json
```

### mpbarbosa.com (`~/Documents/GitHub/mpbarbosa.com`)

| File | Rule |
|------|------|
| `humans.txt` | Contains `Version: X.Y.Z` line under the `/* SITE */` section |

Read the current value:

```bash
grep 'Version:' humans.txt
```

Bump with `sed -i`. Default to a **patch** bump unless the user specifies otherwise.

Example (patch bump from 1.0.0 → 1.0.1):

```bash
sed -i 's/^Version: [0-9]*\.[0-9]*\.[0-9]*/Version: 1.0.1/' humans.txt
```

Stage the file:

```bash
git add humans.txt
```

---

## Preconditions

Before committing:

1. Confirm the current branch and its upstream exist.
2. Inspect `git status --short`.
3. Never discard unrelated user changes.

---

## Execution flow

### Step 1 — Inspect repo state

```bash
git status --short
git branch --show-current
git rev-parse --abbrev-ref --symbolic-full-name '@{u}'
```

If upstream is missing, stop and report that push cannot proceed.

### Step 2 — Bump the version

Read the current version, compute the new one, apply with `sed -i`.

### Step 3 — Stage changes

```bash
git add -A
```

### Step 4 — Review staged scope

```bash
git diff --cached --stat --summary
```

Generate the commit message from the staged diff, not from guesswork.

### Step 5 — Generate commit message

Use a short conventional-style subject that reflects the staged scope.

Examples:

- `chore: bump version to 1.0.1`
- `feat: add post-pull hook for agora_na_copa_2026`
- `fix: skip repos with no upstream tracking branch`

Heuristics:

- Use `chore:` for version bumps, scripts, deployment helpers, and repo ops.
- Use `feat:` for new shipped functionality or scripts.
- Use `fix:` for bug fixes.
- Use `docs:` for documentation-only changes.

### Step 6 — Commit

```bash
git commit -m "GENERATED_SUBJECT" -m "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Step 7 — Push

```bash
git push origin "$(git branch --show-current)"
```

---

## Safety rules

- Do **not** amend previous commits unless the user explicitly asks.
- Do **not** use destructive git commands like `reset --hard`.
- Do **not** manually guess a version string — always read the current value first.
- Do **not** claim success before push completes.
- Pushing to the remote is a shared, hard-to-reverse action — confirm with the
  user before Step 7 unless they have already authorized pushing in this
  conversation.
