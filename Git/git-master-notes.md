# Git Master Notes — Interview & Production Reference

> **Living document**, built the same way as the Kubernetes, ArgoCD, Terraform and AI master notes. As you
> dictate what a session/video covered (or share screenshots), the topic gets its own section below,
> written as theory + real-world/production example + command reference + hands-on practice tasks.

---

## Table of Contents
1. [Git Fundamentals: Architecture, Commits, config & .gitignore](#1-git-fundamentals-architecture-commits-config--gitignore) *(Ch 01)*
2. [Branches & Merge: Pointers, HEAD, Fast-forward & Three-way](#2-branches--merge-pointers-head-fast-forward--three-way) *(Ch 02)*
3. [Merge Conflicts & Undoing Commits (Reset vs Revert)](#3-merge-conflicts--undoing-commits-reset-vs-revert) *(Ch 03)*

---

## 1. Git Fundamentals: Architecture, Commits, config & .gitignore

### 📘 Theory
- **Git** = distributed version control (Linus Torvalds, 2005). Every clone has the full history. Solves overwritten work, missing history, hard rollbacks and hard collaboration.
- **Git vs GitHub:** the tool vs a host for remotes (GitHub, GitLab, Bitbucket, Azure Repos, CodeCommit, self-hosted Gitea/Gerrit).
- **Architecture:** working directory →`add`→ staging area (index) →`commit`→ local repo →`push`→ remote; `clone`/`pull` bring it back. Staging + local repo live in `.git`.
- **Commit:** immutable snapshot + metadata (author, time, message, parent). Hash = SHA-1 ID; changes create new commits.
- **Config scopes:** system `/etc/gitconfig` < global `~/.gitconfig` < local `.git/config`.
- **.gitignore:** keeps secrets and generated files out; only affects untracked files.

### 🏢 Real-world example
A Terraform repo: `.gitignore` contains `.terraform/`, `*.tfstate*`, `*.tfvars` with secrets, `crash.log`. Engineers commit with `feat: add VPC module` / `fix: correct NSG rule`. If someone had already committed `terraform.tfstate`, `git rm --cached terraform.tfstate` + commit stops tracking it, and any leaked credentials get rotated.

### 🛠️ Command reference
```bash
git --version
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --list --show-origin

git init                       # creates .git
git status                     # untracked / staged / modified
git add <file> | git add .     # → staging
git rm --cached <file>         # unstage / stop tracking, keep file
git restore <file>             # DISCARD working-dir edits
git restore --staged <file>    # unstage, keep edits
git commit -m "feat: add login page"
git log | git log --oneline
git diff | git diff --staged
git branch --show-current | git branch -m main
```

| `git status` shows | Meaning | Do |
|---|---|---|
| Untracked (red) | Git not watching | `git add` |
| Changes to be committed (green) | Staged | `git commit` |
| Not staged / modified (red) | Edited after add | `git add` or `git restore` |

### 🧪 Practice tasks
1. `git init` a folder, then run `ls -a` and `tree .git` and identify HEAD, config, objects, refs.
2. Stage a file, edit it again, and explain why `git status` lists it twice. Then fix it both ways (add / restore).
3. Set a global email, then a different local email in one repo; verify with `git config --list --show-origin`.
4. Commit a file, then add it to `.gitignore`: observe it's still tracked, then fix it with `git rm --cached`.
5. Generate a `.gitignore` for Terraform + VS Code with gitignore.io and commit it with a Conventional Commit message.

## 2. Branches & Merge: Pointers, HEAD, Fast-forward & Three-way

### 📘 Theory
- **Branch** = a lightweight pointer to its tip commit (a file in `.git/refs/heads/`); independent line of development; creating one copies nothing.
- **Why:** primary branch (`main`) stays releasable; isolation; parallel work; protected branch, so changes go via PR (GitHub) / MR (GitLab) after CI + review.
- **Naming:** `feature/`, `bugfix/`, `hotfix/`, `release/`, `experiment/`/`spike/`, `chore/`. **Atomic:** one branch one purpose, one commit one logical change.
- **HEAD** = the current branch (detached HEAD = pointing at a commit).
- **Merge:** run from the target. **Fast-forward** when the target has no new commits (the pointer moves, no commit; see it in `reflog`). **Three-way** when diverged after the common ancestor: base + ours + theirs → merge commit with 2 parents (`ort` strategy).

### 🏢 Real-world example
`hotfix/eks-nodegroup-failure` is branched from the prod tag, fixed with one atomic `fix:` commit, and merged into `main` via a PR. Meanwhile `feature/terraform-vpc-setup` continues in parallel; when it merges later, main has moved on, so it's a three-way merge (or a rebase; see Part 3).

### 🛠️ Command reference
```bash
git branch                         # list (* = current)
git branch feature/login           # create
git checkout feature/login         # switch      (git switch feature/login)
git checkout -b feature/login      # create+switch (git switch -c …)
git checkout -b bugfix/typo 0e3ffcd   # from a specific commit
git branch -d feature/login        # delete merged (not current); -D = force
git checkout main && git merge feature/login            # FF or 3-way
git merge bugfix/typo -m "merge branch bugfix/typo"     # 3-way with message
git merge --no-ff X | --ff-only X
git log --oneline --all --graph
git show <merge-hash>              # Merge: p1 p2
git reflog                         # every HEAD move; recover lost commits
```

| | Fast-forward | Three-way |
|---|---|---|
| Condition | Target has no new commits | Both diverged |
| New commit | No | Merge commit (2 parents) |
| Seen via | `reflog` | `log`, `show`, `--graph` |

### 🧪 Practice tasks
1. Create `feature/x`, make 2 commits, fast-forward merge into main, and confirm via `git reflog`.
2. Create `bugfix/y`, commit on both it and main, three-way merge, then inspect with `git show` and `git log --graph --all`.
3. Try `git branch -d` on the current branch and on an unmerged branch; note both errors.
4. Branch from your first commit and observe which files exist.
5. `cat .git/refs/heads/main` and compare it with `git log -1 --format=%H`.

## 3. Merge Conflicts & Undoing Commits (Reset vs Revert)

### 📘 Theory
- **Conflict** = both branches changed the same lines differently since the merge base (divergence alone is fine). Git pauses; a human resolves.
- Markers: `<<<<<<< HEAD` (ours = current) / `=======` / `>>>>>>> branch` (theirs = incoming). Remove them, `git add`, `git commit`; or `git merge --abort`.
- **reset** moves the branch pointer back (rewrites history; local only). **revert** adds an inverse commit (keeps history; safe after push).
- Reset modes: `--soft` (changes staged) · `--mixed` default (unstaged) · `--hard` (discarded). Reset commits stay in `reflog` (~90 days).

### 🏢 Real-world example
Two PRs edit the same Helm `values.yaml` replica count → the second PR shows "conflicts must be resolved"; the author merges main into their branch, resolves, pushes. A bad config commit already deployed from main is undone with `git revert <sha>` via a new PR, so the audit trail stays intact and nobody force-pushes.

### 🛠️ Command reference
```bash
git merge feature/x                 # → CONFLICT
git status                          # both modified
vim file && git add file && git commit
git merge --abort
git checkout --ours|--theirs file
grep -n '<<<<<<<\|>>>>>>>' file      # check no markers remain

git branch -m master main

git reset --soft HEAD~1             # undo commit, keep staged
git reset HEAD~1                    # mixed (default): keep unstaged
git reset --hard HEAD~1             # discard ⚠
git revert <sha>                    # safe undo for pushed commits
git reflog && git branch rescue <sha>
```

### 🧪 Practice tasks
1. Recreate the green/blue conflict, resolve it keeping **both** lines, and check `git log --graph`.
2. Start a conflicting merge and cancel it with `git merge --abort`.
3. Make 3 commits; try `reset --soft`, `--mixed`, `--hard` back one commit, checking `git status` after each.
4. After a `--hard` reset, recover the commit from `git reflog`.
5. `git revert` a middle commit and look at the new commit with `git show`.

