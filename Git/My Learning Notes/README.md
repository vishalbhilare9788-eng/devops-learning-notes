# My Learning Notes — Git, Session-wise Log

Mirrors the AI, Kubernetes, ArgoCD and Terraform tracks' convention.

Goal of this track: understand **Git fundamentals** properly this week, then move on to
**GitHub** and **GitHub Actions for CI pipelines**.

## Naming convention
`NN-topic-name.md`, e.g. `01-git-fundamentals.md`, `02-branching-and-merging.md`

## How this works
1. You tell me you're starting a "Git chapter" and dictate what you learned (and/or share screenshots).
2. I write it up here as `NN-topic-name.md`, cleaned up but kept in your voice.
3. A polished, print-ready PDF version goes into `PDF/`, with the same filename but `.pdf` instead of `.md`.
4. Screenshots from that session get bundled into their own gallery PDF in `Screenshots/`
   (`NN-topic-name-screenshots.pdf`).
5. Reusable reference content (concepts, commands, workflows) gets merged into
   `../git-master-notes.md` as a new or expanded section.

## Roadmap
Course: **Git Masterclass: Complete Git & GitHub Tutorial**

| Part | Topics | When |
|---|---|---|
| **1** | Why & what of Git · core commands (init, status, add, commit) · Git architecture · `.gitignore` · branches · merge (fast-forward & 3-way, conflicts) · undoing commits: reset vs revert | This week |
| **2** | Remote repositories (why, types, authentication) · `git fetch` & `git pull` · pull requests & production PR workflow · `git stash` | Next |
| **3** | Rebase · interactive rebase · squash merge · cherry-pick | After Part 2 |
| **Then** | GitHub Actions for CI pipelines | Later |

## Log
| File | Topic | Date | Notes PDF | Screenshots PDF |
|---|---|---|---|---|
| [01-git-fundamentals.md](01-git-fundamentals.md) | Why Git (Linus Torvalds 2005), DVCS, Git vs GitHub, hosting options, Git in DevOps/GitOps; install (`apt install git`, `git -v`); `git init` + the `.git` folder (HEAD, config, objects, refs, hooks); architecture (working dir → staging → local repo → remote); commits (immutable snapshots, parent chain, hashes); hands-on: status / add / `rm --cached` / restore / commit / log / `--oneline`; "Author identity unknown" → `git config` + scopes (system/global/local); Conventional Commits; `.gitignore` (demo, patterns, tracked-file gotcha, gitignore.io). Full command reference. ✅ **Complete.** | 2026-10-13 | [PDF/01-git-fundamentals.pdf](PDF/01-git-fundamentals.pdf) | [Screenshots/01-git-fundamentals-screenshots.pdf](Screenshots/01-git-fundamentals-screenshots.pdf) (39 shots) |
| [02-git-branches-and-merge.md](02-git-branches-and-merge.md) | Why branches (releasable main, risk isolation, protected PR/MR workflow, parallel work), branch = pointer to the tip, naming conventions (feature/bugfix/hotfix/release/spike/chore), atomic development; visualising branches; HEAD; `branch`, `checkout`, `checkout -b`, `branch -d` (can't delete the current branch), branch from an old commit (`0e3ffcd`); merge: divergence + common ancestor, fast-forward (no commit, `reflog`), three-way (base/ours/theirs, merge commit `b18b077`, `ort`), `git show`, `log --all` / `--graph`. Command reference. ✅ **Complete.** | 2026-10-13 | [PDF/02-git-branches-and-merge.pdf](PDF/02-git-branches-and-merge.pdf) | [Screenshots/02-git-branches-and-merge-screenshots.pdf](Screenshots/02-git-branches-and-merge-screenshots.pdf) (45 shots) |
| [03-merge-conflicts-and-undoing-commits.md](03-merge-conflicts-and-undoing-commits.md) | Merge conflicts: overlapping changes (not divergence) cause them; base/ours/theirs; demo green (master) vs blue (conflict/demo) → `CONFLICT (content)`, markers `<<<<<<< HEAD` / `=======` / `>>>>>>>`, resolve → add → commit (09ba6f9), `--graph`, `reflog`; `--abort`/`--ours`/`--theirs`. `git branch -m master main`. Undoing commits: reset (rewrites, local) vs revert (new commit, pushed); mixed-reset demo (`git reset d516faa` → recommit 7b015bd, old 522bf5f in reflog); soft / mixed / hard table. Completes Part 1. ✅ **Complete.** | 2026-10-13 | [PDF/03-merge-conflicts-and-undoing-commits.pdf](PDF/03-merge-conflicts-and-undoing-commits.pdf) | [Screenshots/03-merge-conflicts-and-undoing-commits-screenshots.pdf](Screenshots/03-merge-conflicts-and-undoing-commits-screenshots.pdf) (26 shots) |
