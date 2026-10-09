# Terraform Master Notes — Interview & Production Reference

> **Living document**, built the same way as the ArgoCD/Kubernetes master notes: as you dictate what
> a session/video covered (or share screenshots), the relevant topic gets its own section below,
> written as theory + real-world example + full command reference + hands-on practice tasks.

---

## Table of Contents
1. [Terraform Workflow](#1-terraform-workflow)
2. [Terraform State Files, HCL Block Syntax & Resource References](#2-terraform-state-files-hcl-block-syntax--resource-references)
3. [Advanced Commands — Taint/Replace, Import, Workspaces, Refresh, Logging, User Data](#3-advanced-commands--taintreplace-import-workspaces-refresh-logging-user-data)
4. [Provisioners — file, remote-exec, local-exec & connection](#4-provisioners--file-remote-exec-local-exec--connection)
5. [Plugin Cache — .terraformrc & plugin_cache_dir](#5-plugin-cache--terraformrc--plugin_cache_dir)
6. [Variables — Input, Types, tfvars & Precedence, count, Outputs & Locals](#6-variables--input-types-tfvars--precedence-count-outputs--locals)
7. [Data Sources — Import vs Data, Existing SG → New EC2, AMI Lookup](#7-data-sources--import-vs-data-existing-sg--new-ec2-ami-lookup)
8. [Backend — Remote State, S3 + DynamoDB Locking, Versioning, Migration](#8-backend--remote-state-s3--dynamodb-locking-versioning-migration)
9. [Modules — Root vs Child, Sources (Local/GitHub/Registry), Inputs & Outputs](#9-modules--root-vs-child-sources-localgithubregistry-inputs--outputs)
10. [Meta-Arguments — count, for_each, depends_on, provider, lifecycle (+ Version Constraints, state rm/mv)](#10-meta-arguments--count-for_each-depends_on-provider-lifecycle--version-constraints-state-rmmv)
11. [Terraform Cloud (HCP Terraform): Organization, Workspaces, VCS Workflow, Variables, Notifications, Cost Estimation](#11-terraform-cloud-hcp-terraform-organization-workspaces-vcs-workflow-variables-notifications-cost-estimation)

---

## 1. Terraform Workflow

### 📘 Theory — 5 steps, one predictable loop
Terraform is HashiCorp's **Infrastructure as Code (IaC)** tool: infrastructure is defined in code
(`.tf` files, written in **HCL** — HashiCorp Configuration Language) instead of clicked together in
a cloud console, so it's version-controlled, repeatable, and reviewable like any other code.

The **Terraform Workflow** is the standard 5-step loop for managing infrastructure this way:

| Step | Command | What happens |
|---|---|---|
| **Write** | *(author `.tf` files)* | Describe the desired infrastructure in HCL |
| **Initialize** | `terraform init` | Set up the working directory, download the provider plugin(s) the code references |
| **Plan** | `terraform plan` | Dry run — shows what will be created/changed/destroyed, touches nothing real |
| **Apply** | `terraform apply` | Executes the plan — provisions/updates real infrastructure |
| **Destroy** | `terraform destroy` | Tears down everything Terraform is tracking for this config |

**Mental model:** `plan` is the safety net of the whole workflow — it's the one step whose entire
job is to let you catch a mistake **before** anything real is touched. Skipping straight from
`write` to `apply` without ever reading a `plan` is the single most common way to be surprised by
what Terraform just did.

### 🌍 Real-World Example
An engineer writes `ec2.tf` describing one EC2 instance and one S3 bucket. `terraform init`
downloads the AWS provider (inferred purely from the resource types in the code — no explicit
provider download step needed). `terraform plan` shows "2 to add, 0 to change, 0 to destroy" before
anything happens. `terraform apply --auto-approve` provisions both. Later, only the EC2 instance
needs to go away (the S3 bucket holds data still in use) — `terraform destroy --target
aws_instance.web` removes just that one resource, confirmed via `terraform state list`, leaving the
bucket untouched until it's separately destroyed with its own `--target`.

### 🧾 Provider auto-detection
Terraform doesn't require you to manually fetch a provider — `terraform init` reads the resource
blocks in your `.tf` files and downloads whichever provider(s) those resource types belong to (e.g.
an `aws_instance` resource pulls the AWS provider; an `azurerm_virtual_machine` would pull the Azure
provider instead). Mixed-cloud configs pull multiple providers in the same `init`.

### ⚙️ Full CLI cheat sheet
```bash
# Info / setup
terraform version                    # display the Terraform binary version
terraform --help                     # top-level help (add a subcommand for its specific flags)
terraform init                       # initialize the directory, pull down required providers

# Sanity checks before touching real infra
terraform validate                   # validate the code for syntax correctness
terraform fmt                        # reformat code to canonical HCL style
terraform providers                  # show which providers this config requires

# The core loop
terraform plan                       # dry run — creates an execution plan
terraform apply                      # execute changes to reach the desired state
terraform apply --auto-approve       # apply without the interactive "yes" confirmation prompt

# Inspecting what's under Terraform's management
terraform show                       # human-readable dump of the current state
terraform state list                 # list every resource currently tracked in state
terraform state show <resource>      # full attributes of one specific resource (e.g. aws_instance.web)

# Tearing down
terraform destroy                    # destroy everything this config is tracking
terraform destroy --target <resource> # destroy only the named resource, leave the rest intact
```

**Shell autocompletion:** Terraform ships a built-in completion helper — add a line like
`complete -C terraform terraform` to `.bashrc` and `source ~/.bashrc` to enable tab-completion for
subcommands and flags.

### 🛠 Practice Tasks
- [ ] Write a `.tf` file with a single resource, run `terraform init`, and confirm the correct provider is auto-downloaded purely from the resource type — no manual provider step.
- [ ] Make `terraform plan` a non-negotiable habit before every `apply` — practice reading its output well enough to predict exactly what `apply` will do.
- [ ] Provision two independent resources in one config, then use `terraform state list` + `terraform state show <resource>` to inspect each individually.
- [ ] Practice `terraform destroy --target <resource>` to remove exactly one resource from a multi-resource config, confirming via `terraform state list` that the rest survive untouched.
- [ ] Deliberately introduce an HCL syntax error and confirm `terraform validate` catches it before you ever reach `plan`.
- [ ] Run `terraform fmt` against a deliberately messy `.tf` file and confirm it's reformatted to canonical style.

---

## 2. Terraform State Files, HCL Block Syntax & Resource References

### 📘 Theory — the state file is Terraform's database of truth
`terraform.tfstate` is a local (by default) JSON file that stores **all details about the
resources Terraform created for this project** — both the attributes you specified and the ones
the provider filled in automatically (AZ, IPs, default SG, generated IDs, etc.). It acts as
Terraform's **database for provisioned resources**: it maps real-world infrastructure back to your
`.tf` config, tracks metadata, and lets Terraform skip re-querying the cloud API for everything on
every run.

Before any `plan`/`apply`, Terraform **refreshes** — it re-checks real infrastructure and
reconciles it against two states:

| | Definition |
|---|---|
| **Desired State** | What's written in your resource blocks in the `.tf` file — the infra as it *should* be. |
| **Current State** | The infra as it *actually* is right now (may have drifted from desired). |

```
Tf config files  →  tf state file  →  Target Environment
```

**Terraform is a state-based engine.** On every run it computes a simple delta:

- In desired but not actual → **create**
- In both, but configured differently → **update**
- In actual but not desired → **delete**

Any time the state file is about to be modified, Terraform first backs up the previous version to
**`terraform.tfstate.backup`**, automatically, before writing the change.

### 🧾 HCL block syntax — how every `.tf` file is built
HCL (HashiCorp Configuration Language) is **declarative** — you describe the end state you want,
not step-by-step imperative instructions. Every block follows this shape:

```hcl
<block_type> "<block_label>" "<block_name>" {
  # Configuration settings for the resource
  attribute1 = value1
  attribute2 = value2
}
```

| Part | What it is | Examples |
|---|---|---|
| **Block type** | Reserved keyword, the kind of block | `resource`, `provider`, `variable`, `output`, `module` |
| **Block label** | Provider- and resource-specific | `aws_instance`, `aws_s3_bucket`, `aws_vpc`, `aws_security_group`, `azurerm_virtual_machine` |
| **Block name** | Your own unique reference name for *this* block | `linux`, `first`, `allow_ssh` |

Attributes inside `{ }` are key/value pairs. Some are mandatory (resource creation fails without
them), others optional (the provider supplies a default, which then gets recorded into the state
file once the resource exists). A single `.tf` file can hold multiple independent resource blocks,
each addressable as `block_label.block_name` (e.g. `aws_instance.linux`, `aws_s3_bucket.first`).

### 🔗 Resource references & implicit dependencies
Reference another block's generated attribute with:
```
<block_label>.<block_name>.<attribute>
```
e.g. `aws_security_group.allow_ssh.id` — valid even though that security group doesn't exist yet
at write-time; Terraform resolves it at apply-time **and** uses the reference to infer creation
order automatically (an implicit dependency — no `depends_on` required). Chain enough of these
together (security group → ingress rule → EC2 instance → EBS volume → volume attachment) and
Terraform builds the whole dependency graph from the reference expressions alone.

> **HCL gotcha:** an attribute that expects a **list** (e.g. `vpc_security_group_ids`) needs the
> reference wrapped in brackets even for a single value — `[aws_security_group.allow_ssh.id]` — or
> it's the wrong type for that attribute.

### 📊 `terraform graph` — visualizing the dependency graph
```bash
yum install graphviz                        # provides the `dot` renderer
terraform graph -type=plan | dot -Tpng > graph.png
```
`terraform graph` emits the dependency graph in machine-readable **DOT** language; piping through
Graphviz's `dot -Tpng` renders it as an image. Read it bottom-up — resources at the bottom (only
depending on the provider) get created first, resources above them depend on what's below.

### 🌍 Real-World Example
A `main.tf` defines `aws_security_group.allow_ssh`, an `aws_vpc_security_group_ingress_rule`
referencing that SG's `.id`, an `aws_instance.linux` attaching the same SG via
`vpc_security_group_ids = [aws_security_group.allow_ssh.id]`, an `aws_ebs_volume.example`, and an
`aws_volume_attachment` referencing both the volume's and the instance's `.id`. On `apply`,
Terraform creates the security group first (its `id` is needed by two other resources), then the
ingress rule and EBS volume in parallel, then the instance, and finally the volume attachment —
purely because the reference expressions describe that order. Rendering
`terraform graph -type=plan | dot -Tpng > graph.png` afterward produces a PNG that visually
confirms exactly that build order, with `provider["registry.terraform.io/hashicorp/aws"]` as the
common root every resource ultimately depends on.

### ⚙️ Command reference additions
```bash
terraform state list                          # list every resource currently tracked in state
terraform state show <resource>               # full attributes of one resource, e.g. aws_s3_bucket.first
terraform graph                               # dependency graph in DOT format
terraform graph -type=plan | dot -Tpng > graph.png   # render it to PNG (needs graphviz)
```

**Referenced but not yet hands-on** — good to know for later chapters:
| Command | What it does |
|---|---|
| `terraform taint` | Manually mark a resource as tainted — treated as damaged/needing replacement on next `apply` |
| `terraform import` | Bring existing infra (created outside Terraform) under Terraform's management |
| `terraform workspace` | Manage multiple deployments of the same config (dev/stage/prod) via separate state per workspace |
| `terraform refresh` | Reads current settings from all managed remote objects and updates state to match (same refresh that runs implicitly before `plan`/`apply`) |
| *(provisioners)* | Execute scripts/commands on a local or remote machine as part of resource provisioning |
| *(plugin cache)* | Local storage for provider plugins so `init` is faster/more reliable across projects |
| *(user data)* | Instructions given to a new server (e.g. EC2) to run automatically at startup |

### 🛠 Practice Tasks
- [ ] Apply a two-resource config and confirm `terraform.tfstate` is auto-created, with both resources showing up in `terraform state list`.
- [ ] Re-run `terraform plan` with no code changes and confirm "No changes. Your infrastructure matches the configuration."
- [ ] Add a tag to an existing resource, run `plan`, and read the `~ update in-place` diff — confirm only the delta shows.
- [ ] Apply that change and confirm `terraform.tfstate.backup` appears automatically.
- [ ] Write a security group + ingress rule as separate blocks, reference the SG's `.id` in the rule, and confirm from the apply log that the SG is created first.
- [ ] Attach that SG to an EC2 instance via `vpc_security_group_ids = [aws_security_group.<name>.id]`; try dropping the brackets once to see the type error.
- [ ] Add an EBS volume + `aws_volume_attachment` referencing both the volume's and instance's `.id`, and confirm creation order in the apply log.
- [ ] Install `graphviz`, render `terraform graph -type=plan | dot -Tpng > graph.png`, and trace the dependency chain in the PNG against your code's reference expressions.

---

## 3. Advanced Commands — Taint/Replace, Import, Workspaces, Refresh, Logging, User Data

### 📘 Theory
**Taint → `-replace`.** `terraform taint <addr>` marks a resource `"status": "tainted"` in state so
the *next* `apply` destroys and recreates it (default order destroy → create; flip with
`lifecycle { create_before_destroy = true }`). It's **deprecated since v0.15.2** because it writes
to shared state immediately: a "ticking time bomb" that fires on whoever's next `apply`, even an
unrelated one. The replacement, `terraform apply -replace="<addr>"`, replaces within that same run
and shows as `-/+` in the plan for review. `terraform untaint` undoes a taint.

**Import.** `terraform import <addr> <provider-id>` maps an existing, console-created resource into
**state only**. It does not write `.tf` code. After importing, fill in the config (copying values
from `terraform show`) until `terraform plan` reports **"No changes"**. Any `~`/`-` left means the
next apply would modify the real resource (e.g. strip a tag you forgot). Terraform 1.5+ has a
declarative `import { to = ..., id = ... }` block that goes through plan/apply and can generate the
config with `terraform plan -generate-config-out=generated.tf`: the preferred modern approach.

**Workspaces.** Same configuration, **separate isolated state per workspace**. Non-default
workspaces store state under `terraform.tfstate.d/<name>/terraform.tfstate` (created on first
apply). `default` stays at `./terraform.tfstate`. Names are case-sensitive. Use
`${terraform.workspace}` in HCL to vary names/sizes per environment. Caveat: all workspaces share one
backend and credentials, so for hard isolation between accounts, many teams use separate
directories/backends instead.

**Refresh.** `terraform refresh` updates state to match real infra, silently and without approval,
so it's deprecated. Use `terraform plan -refresh-only` (preview drift) and `terraform apply
-refresh-only` (accept it into state with approval). Refresh never changes real infra or `.tf`
files. Normal plan/apply refresh implicitly.

**Logging.** `TF_LOG` = `OFF` (default) / `ERROR` / `WARN` / `INFO` / `DEBUG` / `TRACE` (most
verbose). `TF_LOG_PATH` writes to a file. `TF_LOG_CORE` / `TF_LOG_PROVIDER` split core vs provider
logs. Prefer per-command (`TF_LOG=DEBUG terraform plan`) over permanent `.bashrc` exports, since TRACE
logs are noisy and may contain secrets.

**User data.** `user_data = file("${path.module}/script.sh")` on `aws_instance` hands a script to
cloud-init, which runs it **once at first boot**. Later edits don't re-run on an existing instance
unless `user_data_replace_on_change = true` (which forces replacement).

### 🌍 Real-World Example
A team inherits an EC2 instance built by hand in the console and is asked to downsize/upsize it
"through Terraform only". They write an empty `aws_instance` block, run `terraform import
aws_instance.app i-0abc...`, then iterate on the config (ami, instance_type, key_name, tags) until
`plan` says *No changes*. Only then do they change `instance_type` and apply. The plan shows an
in-place update, but `public_ip -> (known after apply)` warns that AWS will stop/start the instance
and release its public IP. So they schedule the change in a maintenance window and point DNS at an
Elastic IP first.

### ⚙️ Command reference
```bash
terraform taint <addr> / terraform untaint <addr>       # legacy
terraform apply -replace="<addr>"                       # modern forced replacement
terraform import <addr> <id>                            # e.g. aws_instance.web i-0c27f664619a950cc
terraform plan -generate-config-out=generated.tf        # with an import {} block
terraform workspace new|list|show|select|delete <name>
terraform plan -refresh-only / terraform apply -refresh-only
export TF_LOG=TRACE TF_LOG_PATH=./terraform.log; unset TF_LOG TF_LOG_PATH
```

### 🛠 Practice Tasks
- [ ] Taint a resource, inspect `"status": "tainted"` in `terraform.tfstate`, untaint it, then do the same replacement with `apply -replace` and compare the plans.
- [ ] Add `lifecycle { create_before_destroy = true }` and confirm the replacement order flips in the apply log.
- [ ] Import a console-created EC2 with the CLI; iterate the config until `plan` says "No changes".
- [ ] Repeat the import with an `import {}` block + `terraform plan -generate-config-out=generated.tf` and compare the generated config to your hand-written one.
- [ ] Change an imported instance's type and note whether the public IP changes; retry with an Elastic IP attached.
- [ ] Create dev/uat/prod workspaces, deploy a `${terraform.workspace}`-named bucket in two of them, and inspect `terraform.tfstate.d/`.
- [ ] Drive `instance_type` from a `lookup()` map keyed by `terraform.workspace`.
- [ ] Change a tag manually in the console, then compare `terraform plan -refresh-only` vs `terraform apply -refresh-only`.
- [ ] Run one `plan` with `TF_LOG=DEBUG` and one with `TRACE` + `TF_LOG_PATH`; compare the log sizes.
- [ ] Launch an EC2 with a `user_data` script that installs httpd, then curl the public IP to confirm the page is served.

---

## 4. Provisioners — file, remote-exec, local-exec & connection

### 📘 Theory
**What.** Provisioners run scripts/commands/file transfers on the local machine or on a newly
created resource during its **creation** (default) or **destruction** (`when = destroy`). They are
Terraform's *imperative escape hatch*: not in the plan, not in state, not idempotent. HashiCorp
calls them a **last resort**.

**Linux analogy.** `file` = `scp` (copy from the Terraform machine to the resource). `remote-exec` =
`ssh` + run commands inside the resource (`inline` list, `script`, or `scripts`). `local-exec` = run
a command on the Terraform machine itself (e.g. save the new server's IP to a local file).

**Rules.**
- A provisioner is always **nested inside a `resource`** block.
- `file` and `remote-exec` need a **`connection`** block (`type` ssh/winrm, `user`, `private_key =
  file(...)`, `host`). It can sit at resource level (shared) or inside one provisioner.
- `self.<attr>` refers to the enclosing resource (`self.public_ip`). A resource can't reference
  itself by name.
- Provisioners run **in the order written**, **only at creation**. Editing them later does nothing
  to an existing resource. Re-run with `apply -replace` or a `triggers` / `triggers_replace` change.
- A failing creation-time provisioner **taints** the resource (recreated next apply). Override with
  `on_failure = continue`.

**Separate "create" from "configure".** Put provisioners on a `null_resource` (needs the
`hashicorp/null` provider + `init`) or, on TF ≥ 1.4, the built-in **`terraform_data`**, whose
`connection.host = aws_instance.x.public_ip` creates the implicit dependency. This lets you re-run
configuration without rebuilding the server, and it avoided the `panic: value is unknown` crash
hit in the lab.

**Prefer instead:** `user_data`/cloud-init (first boot), pre-baked AMIs (Packer), or Ansible after
Terraform. `local-exec` for glue (inventory file, API call, kick off Ansible) is the most defensible
use.

### ⚠️ Gotchas seen in the lab
- `sudo cmd > /root-owned/file` → *Permission denied*: the redirect runs as the login user. Use `| sudo tee file`.
- `dnf update` without `-y` aborts in a non-interactive session.
- A Terraform-managed `aws_security_group` has **no egress** unless you declare it (AWS's default allow-all is removed), so package installs hang.
- `Waiting for process with pid N to finish` in remote-exec output = dnf lock held by cloud-init on a fresh Amazon Linux instance.
- Hard-coded `key_name`/SG names drift from the resources (`my_tf_key` vs `my_tf-key`). Reference `aws_key_pair.x.key_name` and `aws_security_group.x.id`.
- `user` depends on the AMI: `ec2-user` (Amazon Linux/RHEL), `ubuntu` (Ubuntu).

### 🌍 Real-World Example
A team spins up a short-lived EC2 build agent with Terraform in CI. `user_data` installs the base
packages at boot. A `terraform_data` resource then uses `file` to push a job-specific config and
`remote-exec` to register the agent with the CI server. A `local-exec` writes the agent's private
IP into an Ansible inventory file for the next pipeline stage. A `when = destroy` provisioner
deregisters the agent before `terraform destroy` removes the instance, so the CI server is never
left with ghost agents.

### ⚙️ Command / syntax reference
```hcl
connection {
  type        = "ssh"                      # or "winrm"
  user        = "ec2-user"
  private_key = file("/root/project1/ram")
  host        = self.public_ip
}
provisioner "file"        { source = "/tmp/redhat.txt"  destination = "/tmp/redhat1.txt" }
provisioner "remote-exec" { inline = ["sudo dnf install -y httpd", "sudo systemctl enable --now httpd"] }
provisioner "local-exec"  { command = "echo ${self.private_ip} > ip.txt" }
provisioner "local-exec"  { when = destroy  command = "echo destroying ${self.id}" }
# on_failure = continue | fail (default)
```
```bash
ssh-keygen -f ram                  # ram (private) + ram.pub (public, for aws_key_pair)
terraform init                     # after adding null_resource
terraform apply -replace="null_resource.configure_server"   # re-run provisioners only
```

### 🛠 Practice Tasks
- [ ] Rebuild the lab with an `egress` block, port 80 open, `dnf update -y` and `| sudo tee`, then `curl http://<public-ip>` and see the page.
- [ ] Replace hard-coded `key_name` / `security_groups` with resource references and check the dependency order in `terraform graph`.
- [ ] Move the provisioners onto `terraform_data` instead of `null_resource` and confirm no `hashicorp/null` provider is downloaded.
- [ ] Change one `inline` command and observe that `apply` does nothing, then force it with `-replace` on the null/terraform_data resource.
- [ ] Make `remote-exec` fail deliberately (`exit 1`) and check that the resource shows as tainted; repeat with `on_failure = continue`.
- [ ] Add a `when = destroy` `local-exec` that appends to a log file and run `terraform destroy`.
- [ ] Rewrite the httpd install as `user_data` and compare which approach shows up in `plan` and in state.

---

## 5. Plugin Cache — .terraformrc & plugin_cache_dir

### 📘 Theory
**Problem.** By default every `terraform init` downloads a **separate copy of each provider** into
that project's `.terraform/providers/`. The AWS provider alone is ~800 MB (one lab project's
`.terraform` was **874M**). With 10 projects on one server that's 10 downloads and ~8–10 GB of
identical binaries.

**Fix.** The plugin cache: one central local directory holding providers, reused by every project.
Set it in the **CLI configuration file** `~/.terraformrc` (Windows: `%APPDATA%\terraform.rc`),
which uses HCL syntax but CLI-level settings, not project settings:
```hcl
plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache"
disable_checkpoint = true      # stop the HashiCorp version/security "checkpoint" call
```
or with the env var `TF_PLUGIN_CACHE_DIR`.

**How it works.** On `init`, Terraform puts the provider in
`<cache>/<registry>/<namespace>/<type>/<version>/<os_arch>/` and the project's
`.terraform/providers/.../linux_amd64` becomes a **symlink** into the cache. `tree .terraform` shows
`0 files`, so the 822M lives once.

**Rules and caveats.**
- Terraform **does not create the cache dir**. If it's missing, `init` warns *"plugin cache dir …
  cannot be opened: no such file or directory"* and falls back to a per-project download.
  `mkdir -p` it first.
- The cache changes *where* the binary comes from, not *which version*: `.terraform.lock.hcl` still
  pins versions and should be committed.
- TF ≥ 1.4 only uses a cached provider if it matches checksums **already in the lock file**. A new
  project with no lock file may still download once. `plugin_cache_may_break_dependency_lock_file =
  true` relaxes this, but it isn't recommended.
- The cache isn't guaranteed safe for concurrent `init`s, and it never prunes old versions.
- `TF_CLI_CONFIG_FILE` points Terraform at a different CLI config file.
- For teams or air-gapped setups use a **provider mirror** (`terraform providers mirror` +
  `provider_installation { filesystem_mirror {…} }` or `network_mirror`).

### 🌍 Real-World Example
A consultancy runs Terraform for 30 clients from one shared jump server. Every client repo uses
`hashicorp/aws`, and a fresh `init` per repo used to pull ~800 MB each time. That filled the disk
and made pipeline runs slow on the office link. The platform team sets `TF_PLUGIN_CACHE_DIR` for all
users in `/etc/profile.d/terraform.sh`, pointing at `/opt/terraform/plugin-cache` (group-writable),
and commits `.terraform.lock.hcl` in every repo. Now a new AWS provider version is downloaded once
per server, each `init` is a symlink operation taking seconds, and disk use drops from ~24 GB to
under 1 GB. The CI runners bake the same cache into their Docker image, so jobs don't depend on the
public registry being reachable.

### ⚙️ Command reference
```bash
cat > ~/.terraformrc <<'RC'
plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache"
disable_checkpoint = true
RC
mkdir -p ~/.terraform.d/plugin-cache            # required: Terraform won't create it
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"   # alternative to the file
terraform init                                  # "... from the shared cache directory" on reuse
tree ~/.terraform.d ; du -sh ~/.terraform.d/plugin-cache
tree .terraform ; du -sh .terraform             # symlink only, tiny
terraform providers mirror /opt/tf-mirror       # build a local mirror for teams/air-gap
```

### 🛠 Practice Tasks
- [ ] Without a cache, `init` in folders a, b and c and record `du -sh */.terraform`. Then enable the cache, delete `.terraform` everywhere, re-init, and compare.
- [ ] Run `init` in `b` and `c` and look for "from the shared cache directory" in the output. Test once with a copied `.terraform.lock.hcl` and once without.
- [ ] Remove the cache folder and reproduce the "cannot be opened" warning, then fix it with `mkdir -p`.
- [ ] Use `TF_PLUGIN_CACHE_DIR` instead of `.terraformrc` in a fresh shell and confirm the same symlink behaviour.
- [ ] Pin `version = "~> 6.66"` in a `required_providers` block, bump to a newer version, and see a second version folder appear in the cache.
- [ ] Build a filesystem mirror with `terraform providers mirror` and configure `provider_installation` to install only from it.

---

## 6. Variables — Input, Types, tfvars & Precedence, count, Outputs & Locals

### 📘 Theory
**Three kinds of values.**
- **Input variables** (`variable`) send values **into** Terraform. They're the parameters of the code, like function arguments.
- **Output values** (`output`) get values **out** (IDs, IPs) to the CLI or to a parent module.
- **Local values** (`locals`) name an expression inside the module. They can't be set from outside.

**Declaring.** Put declarations in `variables.tf`, referenced as `var.<name>`:
`variable "x" { description, type, default, sensitive, validation, nullable }`. `type` is optional
but should always be set.

**Types.**
- Primitive: `string`, `number`, `bool`.
- Complex: `list(T)` (read by index, `var.users[0]`), `map(T)` (read by key, `var.amis[var.region]`),
  `set(T)`, `object({...})`, `tuple([...])`.
- `null` is a special value that means "unset".

**Ways to set a value**, from lowest to highest precedence:

`default` → `TF_VAR_<name>` env var → `terraform.tfvars` → `terraform.tfvars.json` →
`*.auto.tfvars(.json)` (alphabetical) → `-var` / `-var-file` on the CLI (in the order given; the
last one wins).

With no value anywhere, Terraform **prompts**, showing the `description` as help text.
`-input=false` makes it fail instead, which is what you want in CI. A custom-named file such as
`dev-team.tfvars` is only read via `-var-file`.

**Code layout, from weakest to best.**
1. Everything in `main.tf`.
2. `main.tf` + `variable.tf` with defaults.
3. `main.tf` + `variable.tf` (declarations) + `*.tfvars` (values).

Layout 3 lets the code go to a public repo while environment or secret values stay out of Git. It
also lets one code base serve many teams or environments via `-var-file`.

**`count` + a number variable.** `count = var.instance_count` creates N copies, addressed
`aws_instance.ram[0..N-1]`. `count.index` **starts at 0**: use `"web_server_${count.index}"`, or
`+ 1` for 1-based names. Without it, every copy gets the same Name tag.

**Syntax notes.**
- `var.cpu` is the modern form. `"${var.cpu}"` is legacy interpolation, needed only inside a larger
  string.
- Locals are declared in a `locals {}` block but referenced as `local.<name>` (singular).
- `export TF_VAR_x` lasts only for that shell. Add it to `~/.bashrc` to make it permanent.

### 🌍 Real-World Example
A platform team keeps one EC2/ALB module in a public-facing repo. `variables.tf` declares `env`,
`instance_type`, `instance_count` and `amis` (a map keyed by region), each with `type`,
`description` and `validation` (e.g. `contains(["dev","stage","prod"], var.env)`).
`envs/dev.tfvars` and `envs/prod.tfvars` hold the per-environment values. The pipeline runs
`terraform plan -input=false -var-file=envs/${ENV}.tfvars`. The DB password comes from the CI
secret store as `TF_VAR_db_password`, and the variable is marked `sensitive = true`, so it never
appears in logs or Git. A `locals` block builds `common_tags` and the name prefix
`"${var.project}-${var.env}"` once. Outputs expose `alb_dns_name` and `instance_ids` for the next
stage (DNS and smoke tests), read with `terraform output -raw alb_dns_name`.

### ⚙️ Command / syntax reference
```hcl
variable "cpu" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  validation {
    condition     = can(regex("^t[23]\.", var.cpu))
    error_message = "Only t2/t3 types allowed."
  }
}
variable "users" {                          # var.users[0]
  type    = list(string)
  default = ["root", "user1", "user2"]
}
variable "amis" {                           # var.amis[var.region]
  type    = map(string)
  default = { "us-east-1" = "ami-b374d5a5" }
}
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_instance" "ram" {
  count         = var.instance_count
  instance_type = var.cpu
  tags          = { Name = "web_server_${count.index + 1}" }
}
locals { environment = "dev" }                  # use as local.environment
output "instance_ip" { value = aws_instance.linux.private_ip }
```
```bash
terraform plan -var="cpu=t2.medium"             # override one value (highest)
terraform plan -var-file="dev-team.tfvars"      # custom tfvars (not auto-loaded)
terraform plan -input=false                     # never prompt (CI)
export TF_VAR_cpu=t2.small                      # env var (lowest; this shell only)
terraform output | terraform output -raw instance_ip | terraform output -json
terraform console                               # test var.amis["us-east-1"], var.users[0]
terraform validate                              # catches typos like varaible / kay_name
```

### 🛠 Practice Tasks
- [ ] Set `cpu` in all of these at once: default, `TF_VAR_cpu`, `terraform.tfvars`, `x.auto.tfvars` and `-var`. Remove them one by one, checking with `terraform plan` which value wins each time.
- [ ] Pass two `-var-file`s that both set `cpu` and confirm the last one wins.
- [ ] Add a `validation` block to `region` so only us-east-1/us-west-2 are accepted, then try `ap-south-1`.
- [ ] Recreate the `count` lab with `web_server_${count.index + 1}`, then drop `instance_count` from 2 to 1 and see which index `plan` destroys.
- [ ] Rewrite the same thing with `for_each` over a `set(string)` of names and compare the resource addresses.
- [ ] Mark an output `sensitive = true` and compare `terraform output` with `terraform output -raw`.
- [ ] Move repeated tags into `locals { common_tags = {...} }` and use `merge(local.common_tags, {...})` in two resources.
- [ ] Add `*.tfvars` to `.gitignore` (keep a `terraform.tfvars.example`) and explain the choice.

---

## 7. Data Sources — Import vs Data, Existing SG → New EC2, AMI Lookup

### 📘 Theory
**Definition.** A data source lets a configuration **fetch or compute information defined outside
Terraform** (or in another Terraform workspace/state). It is a **read-only view**: it references
existing infrastructure without creating, changing or destroying it. *A data source reads; a
resource manages.*

**Import vs data source.**
| | `terraform import` | `data` block |
|---|---|---|
| Goal | Adopt an existing resource **into** Terraform management | **Read** an existing resource's attributes |
| Owner afterwards | Terraform (`destroy` deletes it) | Unchanged: cloud team / console / other TF project |
| Block | `resource` + `import {}` / CLI | `data` |

**Syntax.** `data "<type>" "<name>" { <lookup criteria> }`, referenced as
`data.<type>.<name>.<attr>`. Nearly every resource type has a matching data source
(`aws_security_group`, `aws_instance`, `aws_vpc`…). Some exist only as data sources
(`aws_caller_identity`, `aws_availability_zones`, `aws_ami_ids`).

**Behaviour.**
- Read at **every plan/apply** (refresh), so values are always current.
- Stored in state as `mode = "data"` and listed as `data.x.y` in `terraform state list`, but never managed.
- **Zero matches**, or **more than one match** for a single-result data source, makes `plan` fail
  early.
- A data-only config applies with **`0 added, 0 changed, 0 destroyed`** and only "Changes to Outputs".
- Referencing a data attribute from a resource creates an **implicit dependency**.
- If a data source's arguments depend on a not-yet-created resource, the read is deferred to apply
  time and shows `(known after apply)`.

**`aws_ami` lookup.** Combine `owners` (always set it: `"amazon"`, Canonical `099720109477`),
`filter { name = "name", values = [wildcard] }` (same filters as `aws ec2 describe-images`) and
`most_recent = true`. **Side effect:** a newly published AMI changes the ID, so the next plan
**replaces** the instance. Pin it, or use `lifecycle { ignore_changes = [ami] }` and roll
deliberately. Amazon Linux 2 reached end of support on 2026-06-30, so use AL2023
(`al2023-ami-2023.*-x86_64`) for new builds.

**`aws_security_group` by `name`** matches the *group name* (`ram_sg`), not the *Name tag* (`ram_SG`).
To match the tag, use `tags = { Name = "..." }` or `filter { name = "tag:Name" }`.

### 🌍 Real-World Example
The network/cloud team owns the shared VPC, subnets and baseline security groups, built in the
console or in their own Terraform repo. The app team's Terraform does **not** import them, because
that would let the app pipeline destroy shared networking. Instead it uses data sources:
- `data "aws_vpc" "shared" { tags = { Name = "prod-vpc" } }`
- `data "aws_subnets" "private" { filter { name = "vpc-id", values = [data.aws_vpc.shared.id] } }`
- `data "aws_security_group" "baseline" { name = "corp-baseline" }`
- `data "aws_ami" "al2023"` with `owners = ["amazon"]`

The EC2/ASG uses `vpc_security_group_ids = [data.aws_security_group.baseline.id]`. Account-specific
ARNs come from `data.aws_caller_identity.current.account_id`. Where the network team publishes
outputs, `data "terraform_remote_state" "network"` reads `vpc_id` straight from their state.

### ⚙️ Command / syntax reference
```hcl
data "aws_security_group" "example" { name = "ram_sg" }

resource "aws_instance" "example" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = "ram_nv"
  vpc_security_group_ids = [data.aws_security_group.example.id]
  lifecycle { ignore_changes = [ami] }        # don't replace on every new AMI
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_caller_identity" "current" {}       # .account_id
data "aws_availability_zones" "azs" { state = "available" }   # .names
output "sg_id" { value = data.aws_security_group.example.id }
```
```bash
terraform plan                                       # "Reading..." / "Read complete [id=...]"
terraform state list                                 # data.aws_security_group.example
terraform state show data.aws_security_group.example
terraform console                                    # data.aws_ami.al2023.id
aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId'    # cross-check the AMI lookup
```

### 🛠 Practice Tasks
- [ ] Create an SG in the console, read it with `data "aws_security_group"` by `name`, then by `tags`, and output the ID and `vpc_id`.
- [ ] Launch an EC2 with that SG via `vpc_security_group_ids`. Run `terraform destroy` and confirm the SG survives.
- [ ] Change the lookup `name` to something that doesn't exist and read the `plan` error.
- [ ] Replace a hard-coded AMI with `data "aws_ami"` for AL2023 and for Ubuntu (Canonical owner). Compare the IDs in us-east-1 and ap-south-1.
- [ ] Remove `owners` from the AMI lookup and explain why that's a security risk.
- [ ] Add `lifecycle { ignore_changes = [ami] }` and explain what happens when a new AMI is published, with and without it.
- [ ] Use `aws_caller_identity` + `aws_region` to build a bucket name like `logs-<account>-<region>`.
- [ ] Split a lab into two projects (network + app) and read the VPC ID with `terraform_remote_state`.
- [ ] Interview drill: explain import vs data source in 30 seconds, and when you'd choose each.

---

## 8. Backend — Remote State, S3 + DynamoDB Locking, Versioning, Migration

### 📘 Theory
**Definition.** A backend defines **where Terraform stores its state**. It gives Terraform a single
place to look up what it expects of your resources from the last apply.

**Local vs remote.**
- **Local** (`terraform.tfstate` on the machine running Terraform) is the **default**. It's fine for
  testing and dev, but nobody else can use it, and a lost or corrupted file means lost tracking.
- **Remote** (S3, `azurerm`, `gcs`, HCP Terraform…) gives centralized storage (collaboration),
  versioning, a history of changes for troubleshooting and audit, and **state locking**.

**Locking.** With shared state, two people running `apply` at the same time can produce race
conditions, overwrites, drift or corruption. A lock lets only one write operation hold the state at
a time.
- **S3 + DynamoDB:** the table's partition key **must be `LockID` (String)**. The lock is a
  conditional `PutItem`. A second run fails with **"Error acquiring the state lock"**
  (`ConditionalCheckFailedException`) and prints the holder's ID, Operation, Who (`user@host`),
  Version and Created.
- The `<key>-md5` item is the state **checksum**, not a lock.
- **Terraform ≥ 1.10/1.11:** use `use_lockfile = true` (S3-native `.tflock`). **`dynamodb_table` is
  deprecated.**

**Backend block rules.**
- It goes inside `terraform {}` and takes effect on `terraform init`.
- The bucket and table **must already exist**.
- **No variables allowed.** Use `-backend-config` (partial configuration) instead.
- `region` isn't inherited from the provider, so set it explicitly.
- Any change to the backend config makes `plan` fail with **"Backend initialization required"**.

**Migration.**
- Local → S3: `terraform init`, then answer **yes** to "copy existing state". **no** = empty state.
- S3 → local: remove the backend block, then `terraform init -migrate-state`.
- `-reconfigure` switches the config **without copying** state.
- After migrating to S3, the local `terraform.tfstate` is **0 bytes**. `.backup` keeps the old copy.

**Versioning.** Every write is a new S3 object version (lab: 6.4 KB → 11.6 KB, and the old version
is still listed under *Show versions*). This lets you roll back after a bad apply.

### 🌍 Real-World Example
A bootstrap stack (its own repo/state, or CloudFormation) creates `acme-tfstate-<account>`:
versioning, SSE-KMS, Block Public Access, `prevent_destroy`, and a bucket policy limited to the CI
role and the platform admins. Every stack has its own key, e.g. `prod/network/terraform.tfstate`
and `prod/eks/terraform.tfstate`. The backend uses `use_lockfile = true` (older estates still have a
`terraform-locks` DynamoDB table). Per-environment backends come from `envs/prod.s3.tfbackend`
through `terraform init -backend-config=...` in the pipeline. When a CI runner is killed mid-apply,
the on-call engineer reads the lock info, confirms no job is running, and runs
`terraform force-unlock <ID>`. After a bad state write, they restore the previous object version
from S3.

### ⚙️ Command / syntax reference
```hcl
terraform {
  backend "s3" {
    bucket       = "ramprateek"
    key          = "state/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true                         # modern; legacy: dynamodb_table = "terraform-state-locking"
  }
}

resource "aws_s3_bucket" "state" {
  bucket = "ramprateek"
  lifecycle { prevent_destroy = true }          # lab used force_destroy = true — never on real state
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_dynamodb_table" "lock" {          # only if using DynamoDB locking
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
```
```bash
terraform init                                   # local → backend: answer "yes" to copy state
terraform init -migrate-state                    # move state between backends (incl. back to local)
terraform init -reconfigure                      # new backend config, no copy
terraform init -backend-config=dev.s3.tfbackend  # partial config per environment
terraform state pull > backup.tfstate            # snapshot the remote state
terraform force-unlock <LOCK_ID>                 # stale lock, only when nothing is running
terraform apply -lock-timeout=5m                 # wait for the lock instead of failing
aws s3api list-object-versions --bucket ramprateek --prefix state/
```

### 🛠 Practice Tasks
- [ ] Rebuild the lab: bucket + versioning + DynamoDB table with local state, then add `back.tf` and migrate (answer `yes`). Confirm the local file is 0 bytes.
- [ ] Run `terraform init` and answer **no** instead, then run `plan` and explain why it wants to create everything again.
- [ ] Hold an `apply` at the prompt, run `plan` in a second terminal, and read the lock error. Find the same ID in the DynamoDB item.
- [ ] Kill an `apply` mid-run (Ctrl-C twice). If a lock remains, release it with `terraform force-unlock`.
- [ ] Switch the backend to `use_lockfile = true` (no DynamoDB) with `terraform init -reconfigure`, and look for the `.tflock` object during an apply.
- [ ] Restore the previous state version from S3 and check what `terraform plan` shows.
- [ ] Move the state back to local with `-migrate-state`, then explain the difference from `-reconfigure`.
- [ ] Move the backend values into `dev.s3.tfbackend` and init with `-backend-config`. Try putting `var.bucket` in the backend block and read the error.
- [ ] Interview drill: "Why remote state? How does locking work? What do you do with a stuck lock?" in 60 seconds.

---

## 9. Modules — Root vs Child, Sources (Local/GitHub/Registry), Inputs & Outputs

### 📘 Theory
**Definition.** A module is a set of `.tf` files in **one directory**: a reusable building block,
like a function. *"Group resources together and reuse the group, possibly many times."* Modules are
used in every production setup, and their purpose is **reusability**. Teams (front end, back end,
network) publish their code once, and other projects call it and only change the values.

**Root vs child.**
- **Root module:** the directory where you run `terraform`. Every configuration is a module.
- **Child module:** a module **called by** another module through a `module` block.
- A subfolder (e.g. `modules/ec2_modules`) is **ignored until it's called**. Copying it in does
  nothing, and `apply` would build only the root's resources.

**Syntax.** `module "<NAME>" { source = "<SOURCE>"  <inputs…> }`.
- `source` is the only required argument.
- Every other argument sets a child `variable`. Variables without a default are required.
- Read values back with `module.<NAME>.<output>`. That only works if the child declares `output`
  blocks; resources inside a module can't be referenced directly.

**Init.** Adding or changing a module block or `source` requires `terraform init`, otherwise you get
**"Module not installed"**.
- Remote modules (Git, registry) are downloaded into **`.terraform/modules/<name>`**, indexed by
  `modules.json`.
- Local modules are referenced in place, not copied.

**Addresses.** Resources inside a module are addressed as `module.<name>.<type>.<name>`
(e.g. `module.adam-module.aws_instance.server-instance`, `module.my_module.aws_instance.linux[0]`).

**Sources.**
| Source | Example |
|---|---|
| Local | `./modules/ec2_modules` |
| Registry | `terraform-aws-modules/s3-bucket/aws` + `version` |
| GitHub | `github.com/org/repo` / `git::https://…git//subdir?ref=v1.0.0` |
| Other | HTTPS archive, S3/GCS, private registry `app.terraform.io/org/name/provider` |

Pin **registry modules with `version`** (`~> 5.14`) and **Git modules with `?ref=`**. Unpinned
modules pull the latest version (5.14.1 in the lab).

**Anti-patterns seen in the shared lab code.**
- A `provider` block inside a child module. This blocks `count`/`for_each`/`depends_on`, and
  removing the module then fails.
- `"${var.x}"` interpolation, `"true"` written as a string, untyped variables, no outputs.
- A stray `}` in the root file.
- Deleting with `*` leaves the hidden `.terraform/` folder and the lock file behind.

### 🌍 Real-World Example
The platform team maintains versioned modules in Git or a private registry: `network` (VPC,
subnets, NAT, endpoints), `eks`, `rds` and `s3-secure`. Each has `variables.tf` (typed and
validated), `outputs.tf`, `versions.tf` and a README generated by `terraform-docs`, and releases are
tagged `v1.4.0`. Each environment's root (`envs/dev`, `envs/prod`) is thin. It configures providers
and the backend (Chapter 08) and then calls:
- `module "network" { source = "git::https://git.acme/tf-modules.git//network?ref=v1.4.0" … }`
- `module "eks" { subnet_ids = module.network.private_subnet_ids … }`

Upgrades go through a PR that bumps `ref`/`version`, the plan is reviewed, and then it's applied.
Public building blocks such as `terraform-aws-modules/vpc/aws` are used with a pinned
`version = "~> 5.0"`. When resources are moved into a module, `moved {}` blocks prevent them being
destroyed and recreated.

### ⚙️ Command / syntax reference
```hcl
module "my_module" {                              # local child module
  source         = "./modules/ec2_modules"
  instance_count = 2                              # overrides the child's default (1)
}

module "vpc-module" {
  source      = "./modules/vpc_modules"
  vpc_cidr    = "192.168.0.0/16"
  subnet_cidr = "192.168.1.0/24"
}

module "adam-module" {                            # GitHub; pin with ?ref= in real code
  source        = "git::https://github.com/srm71118/adamrepo.git?ref=main"
  ami           = "ami-0cca134ec43cf708f"
  instance_type = "t2.micro"
  instance_name = "Demo-server"
  key           = "ram_aws"
}

module "s3_bucket" {                              # Terraform Registry
  source     = "terraform-aws-modules/s3-bucket/aws"
  version    = "~> 5.14"
  bucket     = "lalalalal123212344"
  acl        = "private"
  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  versioning = { enabled = true }
}

# child: outputs.tf → root reads module.vpc-module.vpc_id
output "vpc_id" { value = aws_vpc.vpcone.id }

moved {                                           # refactor into a module without recreate
  from = aws_instance.linux
  to   = module.my_module.aws_instance.linux
}
```
```bash
terraform init                    # after any module add/change ("Module not installed" otherwise)
terraform init -upgrade           # newer module/provider versions within constraints
terraform get                     # modules only
terraform state list              # module.<name>.<type>.<name>
terraform plan -target=module.vpc-module
terraform fmt -recursive && terraform validate
ls .terraform/modules/            # adam-module  modules.json  s3_bucket
```

### 🛠 Practice Tasks
- [ ] Recreate `project1/modules/{ec2_modules,vpc_modules}`. Run `apply` **without** a module block and confirm only the S3 bucket is created.
- [ ] Add `module "my_module"` with `instance_count = 2`. Hit "Module not installed", run `init`, and check the addresses in `terraform state list`.
- [ ] Add `outputs.tf` to the VPC module and pass `module.vpc-module.subnet_id` into the EC2 module.
- [ ] Remove the `provider` block from the VPC module and configure the provider in the root instead. Then call the module twice with `for_each = { dev = "10.10.0.0/16", prod = "10.20.0.0/16" }`.
- [ ] Use a GitHub module pinned with `?ref=<tag>`. Push a change to `main` and confirm your plan doesn't change until you bump `ref`.
- [ ] Use `terraform-aws-modules/vpc/aws` with `version = "~> 5.0"`. Inspect `.terraform/modules/modules.json`.
- [ ] Move an existing root `aws_instance` into a module using a `moved {}` block and confirm the plan shows no destroy.
- [ ] Interview drill: "What is a module, root vs child, how do you version and share modules, and how do modules pass data?" in 60 seconds.

---

## 10. Meta-Arguments — count, for_each, depends_on, provider, lifecycle (+ Version Constraints, state rm/mv)

### 📘 Theory
**Definition.** Meta-arguments are built-in arguments, available on **resource** and **module**
blocks (and some on `data` blocks), that change **how Terraform handles** a block rather than what
the resource is. They work with every provider.

| Meta-arg | Purpose | Key facts |
|---|---|---|
| `count` | N near-identical copies | Number input. `count.index` starts at 0. Address `res[0]`. Removing a middle item shifts the rest, so they get recreated. `count = var.on ? 1 : 0` works as an on/off switch |
| `for_each` | One copy per key | Takes a map or set(string) (`toset()` for lists). Use `each.key` / `each.value`. Address `res["web"]`, which stays stable. Can't be combined with `count`. Keys must be known at plan time |
| `depends_on` | Explicit order | A list of resources/modules. Use it for **hidden** dependencies only (references already create implicit ones). A last resort that slows parallelism. If the dependency fails, the dependent isn't created |
| `provider` | Non-default provider config | `provider "aws" { alias = "NV" region = "us-east-1" }`, then `provider = aws.NV` (no quotes). Keep one un-aliased default. AMIs and key pairs are per region. Modules take `providers = { aws = aws.NV }`. Cross-account uses `assume_role` |
| `lifecycle` | Override create/update/destroy | `create_before_destroy`, `prevent_destroy` (the plan errors with *"Instance cannot be destroyed"*), `ignore_changes = [tags, …]` (gives "No changes"), `replace_triggered_by`, `precondition`/`postcondition` |

**`prevent_destroy` caveats.**
- It doesn't help if the resource block itself is deleted from the code.
- It also blocks force-replacements.
- Pair it with the provider-side protection: `deletion_protection` (RDS) or `disable_api_termination`
  (EC2).

**Version constraints.**
- Use `terraform { required_version = "…"; required_providers { aws = { source, version } } }`.
- Operators: `=`, `!=`, `>=`, `<=`, `~>`, and ranges like `">= 1.7.5, < 1.9.5"`.
- **`~>` lets only the rightmost number rise:** `~> 3.74.0` = 3.74.x, `~> 3.74` = 3.x ≥ 3.74,
  `~> 5.0` = any 5.x.
- `init` installs the newest version allowed (lab: `~> 3.74.0` → 3.74.3) and records it in
  **`.terraform.lock.hcl`** (version, constraints, hashes). **Commit the lock file.**
- Without a constraint you get the latest (6.52.0), and old code breaks. Lab: `acl` on
  `aws_s3_bucket` is deprecated since provider v4, so use `aws_s3_bucket_acl`.
- A lock file that conflicts with a new constraint gives *"locked provider 6.52.0 does not match
  configured version constraint ~> 3.74.0"*. The fix is **`terraform init -upgrade`**, which
  re-selects versions and can go down as well as up.

**State surgery.**
- **`terraform state rm <addr>`:** Terraform forgets the resource, and the real one stays. Also
  delete the block from the code, or the next plan recreates it.
- **`terraform state mv <old> <new>`:** renames or moves the resource in state with no recreate.
  Rename the block in the code to match.
- Declarative equivalents: **`removed {}`** (TF ≥ 1.7, `lifecycle { destroy = false }`) and
  **`moved {}`** (TF ≥ 1.1).

### 🌍 Real-World Example
A platform repo pins `required_version = ">= 1.9, < 2.0"` and `aws = "~> 6.0"`, and commits
`.terraform.lock.hcl`. Renovate opens PRs that run `init -upgrade` and include the plan.

The app module creates per-service SQS queues and alarms with `for_each = var.services` (a map), so
adding or removing a service affects only that service. It uses `count = var.enable_waf ? 1 : 0`
for optional WAF.

A second aliased provider, `aws.use1`, creates the ACM certificate for CloudFront in us-east-1,
while everything else stays in ap-south-1.

Lifecycle settings:
- The prod RDS has `lifecycle { prevent_destroy = true }` plus `deletion_protection = true`.
- The ASG launch template uses `create_before_destroy`.
- Tags owned by the FinOps tooling are covered by `ignore_changes = [tags["CostCenter"]]`.

When a team refactors names, they add `moved {}` blocks instead of running `state mv` by hand. When
an S3 bucket is handed to the data team's stack, it's released with a `removed {}` block
(`destroy = false`) and imported there.

### ⚙️ Command / syntax reference
```hcl
resource "aws_instance" "linux" {
  count = 2
  tags  = { Name = "Demo-server-${count.index}" }
}

resource "aws_instance" "app" {
  for_each      = { web = "t2.micro", db = "t2.medium" }
  instance_type = each.value
  tags          = { Name = "Ec2-server-${each.key}" }
}

resource "aws_instance" "redhat" {
  depends_on = [aws_s3_bucket.first]
}

provider "aws" { region = "ap-south-1" }                      # default
provider "aws" {
  alias  = "NV"
  region = "us-east-1"
}
resource "aws_instance" "nv" { provider = aws.NV }

resource "aws_instance" "web" {
  lifecycle {
    prevent_destroy       = true
    ignore_changes        = [tags, instance_type]
    create_before_destroy = true
    replace_triggered_by  = [aws_launch_template.web.latest_version]
  }
}

terraform {
  required_version = "~> 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.74.0"
    }
  }
}

moved {
  from = aws_s3_bucket.first
  to   = aws_s3_bucket.hello
}
removed {
  from = aws_s3_bucket.first
  lifecycle { destroy = false }
}
```
```bash
terraform init -upgrade                     # re-select provider versions (fixes lock/constraint mismatch)
terraform providers                         # who requires which provider version
terraform version
terraform state list                        # linux[0] / app["web"]
terraform state show 'aws_instance.app["web"]'
terraform state rm aws_s3_bucket.first      # forget, keep the real bucket
terraform state mv aws_s3_bucket.first aws_s3_bucket.hello
terraform plan -target=aws_instance.linux1
```

### 🛠 Practice Tasks
- [ ] Create 3 instances with `count` from `var.names = ["a","b","c"]`, remove `"a"`, and read the plan. Redo it with `for_each = toset(var.names)` and compare.
- [ ] Use `for_each` over a map of `{ name = { type, az } }` objects, reading the values via `each.value.type`.
- [ ] Make an EC2 wait for an IAM instance profile with **no** reference, using `depends_on`. Then replace that with a real reference and show the order is the same.
- [ ] Deploy the same SG + EC2 to ap-south-1 (default) and us-east-1 (alias), then pass the aliased provider into a module with `providers = {}`.
- [ ] Set `prevent_destroy = true` and try `destroy`, then a change that forces replacement (AMI). Delete the whole block and see what happens.
- [ ] Change tags in the console and confirm `plan` shows changes, then add `ignore_changes = [tags]` and confirm it shows none.
- [ ] Use `create_before_destroy` on an SG with a fixed `name` and read the error. Fix it with `name_prefix`.
- [ ] Recreate the A/B version lab: get the lock-file conflict and fix it with `init -upgrade`. Explain `~> 3.74.0` vs `~> 3.74`.
- [ ] `state rm` a bucket while the code still has it, run `plan`, and explain the result. Then do it properly with a `removed {}` block.
- [ ] Rename a resource three ways: code only (see the destroy/create plan), `state mv`, and a `moved {}` block.
- [ ] Interview drill: "Name the 5 meta-arguments and when you'd use each; count vs for_each; how do you pin versions?" in 90 seconds.

---

---

## 11. Terraform Cloud (HCP Terraform): Organization, Workspaces, VCS Workflow, Variables, Notifications, Cost Estimation

### 📘 Theory
**Definition.** Terraform Cloud, renamed **HCP Terraform** in 2024, is HashiCorp's **managed SaaS** for
running Terraform. It's a centralized, collaborative platform that runs the same Terraform remotely
and adds what the CLI doesn't have: shared state, team workflow and governance.
**Terraform Enterprise** is the same platform, self-hosted.

**Ways to use Terraform:** the CLI (Core / Community Edition, our laptop), HCP Terraform (SaaS),
or Terraform Enterprise (self-hosted).

| Capability | What it means |
|---|---|
| Remote state | Stored, **versioned** (one state version per run, tied to the commit) and **locked** automatically |
| VCS integration | GitHub/GitLab/Bitbucket/Azure DevOps. Push → plan. PR → **speculative plan** posted to the PR |
| Remote runs | Plans/applies run in isolated HashiCorp workers (execution mode **Remote**), or **Local** (state only), or **Agent** (self-hosted, private network) |
| Policy as code | **Sentinel** / OPA checks every plan for security, cost and config rules before apply (paid tier). Enforcement levels: advisory, soft-mandatory, hard-mandatory |
| Cost estimation | Org setting. Shows hourly/monthly cost and the **monthly delta** before apply |
| RBAC | Teams + permissions per org/project/workspace. Only authorised people confirm prod applies |
| Notifications | Webhook / Email / Slack / MS Teams, for events Created, Planning, Needs attention, Applying, Completed, Errored |

**Hierarchy.** **Organization** (company/team, globally unique name) → **Project** (folder of
workspaces, e.g. `Default Project`) → **Workspace** (one config + variables + state + run history;
one per client or environment).

> **An HCP workspace is not a CLI workspace.** `terraform workspace` = several state files for one
> directory. An HCP workspace = a full unit with its own code source, variables, permissions and runs.

**3 workflows.** **VCS-driven** (commits/PRs trigger runs: traceability), **CLI-driven** (`cloud {}`
block + `terraform login`, runs stream to the terminal), **API-driven** (custom pipelines).

**Variables.** Two kinds:
- **Terraform variable**: must match a `variable` block. Tick **HCL** for lists/maps.
- **Environment variable**: exported into the run, e.g. `AWS_ACCESS_KEY_ID`, `TF_LOG`.

Mark secrets **Sensitive**, which makes them write-only. **Variable sets** share variables across
workspaces, and workspace variables override them. Production should use **dynamic provider
credentials** (OIDC, short-lived per run, `TFC_AWS_PROVIDER_AUTH` + `TFC_AWS_RUN_ROLE_ARN`)
instead of static keys.

**Run lifecycle.** Pending → Planning → Cost estimating → Policy check → **Needs confirmation**
(when auto-apply is Off) → *Confirm & apply + comment* → Applying → Applied. The other outcomes
are Discarded and Errored. Only one run applies per workspace at a time.

### 🌍 Real-World Example
A company org has one project per product. Each product has the workspaces `payments-dev`,
`payments-stg` and `payments-prod`, all VCS-connected to the same repo with different
**working directories** and **trigger path filters**.

Credentials and policies:
- AWS access uses **dynamic credentials** (an OIDC IAM role per environment), so there are no
  access keys anywhere.
- An org-wide **variable set** carries common tags and the `TF_LOG` level.

The change flow:
1. A developer opens a PR. HCP posts a **speculative plan** and the **cost delta** on the PR.
2. **Sentinel** hard-fails a run if an SG opens 22 to `0.0.0.0/0` or a resource lacks `CostCenter`.
   It soft-fails if the monthly increase is over $500, and a lead can override that.
3. After the merge, `dev` auto-applies.
4. `prod` waits in **Needs confirmation**, and only the `platform-admins` team can Confirm & apply.

Slack notifications fire on *Needs attention* and *Errored*. Each state version is tied to a commit
and a person, which answers every "who changed this and why?" in an audit.

### ⚙️ Command / syntax reference
```hcl
# CLI-driven workflow — replaces the backend block
terraform {
  cloud {
    organization = "helloyello123321456"
    workspaces {
      name = "demorepo-cli"        # or: tags = ["app:payments"] to pick several
    }
  }
}
```
```bash
terraform login                  # token → ~/.terraform.d/credentials.tfrc.json
terraform init                   # link dir to HCP workspace (offers to migrate local state)
terraform init -migrate-state    # move existing S3/local state into HCP
terraform plan                   # remote speculative plan, streamed locally
terraform apply                  # remote apply (rejected on VCS-driven workspaces)
terraform logout
```
| Task | UI path |
|---|---|
| Create org | Organizations → Create organization (Business / Personal, unique name, email) |
| New workspace | Workspaces → New Workspace → Version Control Workflow → GitHub App → repo → name |
| AWS creds | Workspace → Variables → Add variable → **Environment variable** → Sensitive |
| Manual run | Runs → New run → *Plan and apply (standard)* |
| Approve | Run → **Confirm & apply** → comment |
| Notifications | Workspace → Settings → Notifications → Email / Slack / Teams / Webhook |
| Cost estimation | Organization Settings → Integrations → Cost estimation → enable |
| State history | Workspace → States (version ↔ run ↔ commit) |
| Tear down | Workspace → Settings → Destruction and deletion → **Queue destroy plan** |

**Lab facts:**
- Org `helloyello123321456`, workspace `demorepo` (`ws-ntpPVcq1AyXTfZaY`), repo `srm71118/demorepo`,
  Terraform v1.15.7, execution mode Remote, auto-apply Off.
- **Run 1** (UI): `Test_server` t2.micro in ap-south-1b, commit `83d4441`.
- **Run 2** (GitHub commit "Update ec2.tf", `5297b1e`): t2.micro → t2.nano as an **in-place update**.
  The public IP/DNS became *known after apply*, because a type change means a stop/start.
- Cost estimate: $0.007/h, $5.115/month, **delta -$4.315**.
- Email notifications: Run Created → Planning → *Cost Estimated – Needs Confirmation* → Applying.

### 🛠 Practice Tasks
- [ ] Sign up and create a Personal org, then a VCS-driven workspace on a repo with one EC2.
- [ ] Run a plan with **no** AWS credentials and read the error. Add both keys as Sensitive env variables and re-run.
- [ ] Commit an instance-type change in GitHub, watch the auto-triggered run, and read the cost delta before confirming.
- [ ] Open a PR instead of committing to `main`, and find the speculative plan status check on the PR.
- [ ] Move the AWS keys into an org **variable set** and attach it to two workspaces.
- [ ] Replace the static keys with **dynamic credentials** (OIDC provider + IAM role + `TFC_AWS_*` env vars).
- [ ] Create a second, **CLI-driven** workspace with a `cloud {}` block, then `terraform login` / `init` / `plan` from your server.
- [ ] Migrate the Ch 08 S3-backend project into HCP with `terraform init -migrate-state`.
- [ ] Add a Slack or Teams notification for *Needs attention* + *Errored* only.
- [ ] Turn auto-apply on for a dev workspace and compare the run timeline with the prod-style one.
- [ ] Clean up: **Queue destroy plan**, confirm the EC2 is gone, then delete the workspace.
- [ ] Interview drill: "CLI + S3 backend vs HCP Terraform: when would you pick each, and how do you keep credentials safe?" in 90 seconds.
