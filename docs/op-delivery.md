# OP Delivery Workflow -- Reference

Reusable GitHub Actions workflow that delivers source code to a target Git repository (typically the OP CITnet Bitbucket).

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Setup Guide](#setup-guide)
- [Inputs Reference](#inputs-reference)
- [Secrets Reference](#secrets-reference)
- [Caller Workflow Examples](#caller-workflow-examples)
- [Deliverable Structure](#deliverable-structure)
- [Developer Responsibilities](#developer-responsibilities)
- [Troubleshooting](#troubleshooting)

## Overview

The OP CI/CD pipeline requires source code to be pushed to a target repository with a specific directory structure. This workflow automates that delivery so developers don't have to manually clone, copy, and push.

**Key design decisions:**

- **Selective copy**: Only `src/`, `test/`, `docs/` are copied (the three OP-mandatory directories).
- **Configurable target branch**: Defaults to `develop` (per OP doc section 5.4), but can be set to any branch.
- **Optional tagging**: Can create a git tag on the target repo using the VERSION value.
- **Dev responsibility**: The workflow does NOT transform anything. Developers are responsible for OP-compliant naming, version strings, and directory layout.
- **SSH auth**: Uses SSH deploy keys (one per target repo).
- **Full overwrite**: `rsync --delete` ensures the target branch exactly mirrors the deliverable.

## How It Works

```
Source repo (GitHub)          Deliverable tree (assembled)         Target repo
======================        ============================         ===========

src/  ─────────────────────>  src/                    ───────────> target branch
test/ ─────────────────────>  test/                   ───────────>
docs/ ─────────────────────>  docs/                   ───────────>
VERSION ───(copy)──────────>  src/VERSION             ───────────>
(workflow generates)────────> src/filters/*.properties ──────────>
```

Steps executed by the workflow:

1. **Checkout** the source repo at the triggering ref (`github.ref`)
2. **Copy** `src/`, `test/`, `docs/` into a staging directory
3. **Place VERSION** at `src/VERSION` (OP requirement 5.2.3)
4. **Generate** `src/filters/fortify-exclusion.properties` and `src/filters/odc-exclusion.properties` from the provided patterns
5. **Validate** that `src/`, `test/`, `docs/` all exist in the deliverable
6. **Dry run**: Upload the deliverable as a GitHub Actions artifact for inspection
7. **Real run**: Clone the target branch, rsync the deliverable over it, commit, push, and optionally tag

## Prerequisites

- The calling repo must be **public** (or in the same org with workflow sharing enabled), because GitHub does not allow public repos to call reusable workflows from private repos.
- `devops-toolkit` must have **Actions sharing** enabled ("Accessible from repositories in the organization").
- `devops-toolkit` must have `allowed_actions` set to `all` (not `local_only`), so it can use `actions/checkout` and `actions/upload-artifact`.

## Setup Guide

### 1. Create an SSH deploy key

Generate an SSH keypair dedicated to the target repository:

```bash
ssh-keygen -t ed25519 -C "op-delivery-<project-name>" -f deploy-key -N ""
```

- Add the **public key** (`deploy-key.pub`) as a deploy key with **write access** on the **target** repo (e.g., CITnet Bitbucket).
- Add the **private key** (`deploy-key`) as a GitHub Actions secret on the **calling** repo (e.g., `ted-rdf-conversion-pipeline`). The secret name is up to you — map it to `SSH_DEPLOY_KEY` in the caller's `secrets:` block.
- Delete the local key files after adding them.

### 2. Create the caller workflow

Add `.github/workflows/op-deliver.yml` to your project (see [examples](#caller-workflow-examples) below).

### 3. Test with dry run

Set `dry_run: true` in your caller workflow. Push to trigger it. Check the uploaded artifact in the GitHub Actions run to verify the deliverable structure.

### 4. Test with a throwaway repo

Before pointing at the real target repo, create a disposable test repo and use it as the `target_repo_url`. This lets you verify the full push flow without risk.

### 5. Go live

Once verified:
- Set `dry_run: false`
- Set `target_repo_url` to the real target SSH URL
- Replace the test deploy key secret with the real deploy key
- Change the trigger to `workflow_dispatch` (requires the workflow to exist on the default branch)

## Inputs Reference

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `target_repo_url` | No | `''` | SSH URL of the target repository. Not required for dry runs. |
| `target_branch` | No | `develop` | Branch to push to on the target repository |
| `dry_run` | No | `false` | If true, uploads artifact instead of pushing |
| `commit_message` | No | `''` | Multi-line commit body appended after the subject line (see below) |
| `commit_author_name` | **Yes** | -- | Git author name for delivery commits |
| `commit_author_email` | **Yes** | -- | Git author email for delivery commits |
| `create_tag` | No | `false` | Create a git tag on the target repo using the VERSION value |
| `fortify_exclude_patterns` | No | `''` | Fortify scan exclusion patterns (one per line) |
| `odc_exclude_patterns` | No | `''` | OWASP Dependency Check exclusion patterns (one per line) |

### Automatic values (no input needed)

| Value | Source | Description |
|-------|--------|-------------|
| Project name | `github.event.repository.name` | Used for artifact naming |
| Source ref | `github.ref` | The ref that triggered the caller workflow |
| VERSION path | Hardcoded `VERSION` | Must exist at repo root per OP spec |

### Commit message

The delivery commit subject is always `delivery: <version>`. If you provide `commit_message`, it becomes the commit body (separated by a blank line).

**From YAML** (hardcoded in caller) -- use block scalar for multi-line:

```yaml
commit_message: |
  - Fixed airflow Dockerfile base image
  - Updated DAG retry config
  - Added new mapping suite processor
```

**From workflow_dispatch UI** -- use pipe (`|`) as a line separator:

```
Fixed airflow Dockerfile | Updated DAG config | Added processor
```

Both produce the same git commit:

```
delivery: 2.3.0-RC.5

- Fixed airflow Dockerfile base image
- Updated DAG retry config
- Added new mapping suite processor
```

If `commit_message` is empty, the commit is simply `delivery: 2.3.0-RC.5`.

### Multi-line inputs

`fortify_exclude_patterns` and `odc_exclude_patterns` accept one entry per line using YAML block scalar syntax:

```yaml
fortify_exclude_patterns: |
  **/docs/**/*
  **/test/**/*
```

Exclusion patterns are joined with commas in the generated `.properties` files:
```
excludePatterns=**/docs/**/*,**/test/**/*
```

## Secrets Reference

| Secret | Required | Description |
|--------|----------|-------------|
| `SSH_DEPLOY_KEY` | For real runs | SSH private key for pushing to the target repo. Not needed for dry runs. |

## Caller Workflow Examples

### Dry run (testing)

```yaml
name: Deliver to OP

on:
  push:
    branches:
      - feature/my-delivery-branch

jobs:
  deliver:
    uses: meaningfy-ws/devops-toolkit/.github/workflows/op-delivery.yml@main
    with:
      commit_author_name: Your Name
      commit_author_email: plumber@meaningfy.ws
      dry_run: true
      fortify_exclude_patterns: |
        **/docs/**/*
        **/test/**/*
      odc_exclude_patterns: |
        **/docs/**/*
        **/test/**/*
```

### Production (manual dispatch)

```yaml
name: Deliver to OP

on:
  workflow_dispatch:
    inputs:
      target_repo_url:
        description: 'SSH URL of the target repository'
        default: 'git@bitbucket.org:your-org/your-repo.git'
        type: string
      target_branch:
        description: 'Branch to push to on the target repository'
        default: 'develop'
        type: string
      dry_run:
        description: 'Validate only — do not push to target'
        default: false
        type: boolean
      create_tag:
        description: 'Tag the delivery on the target repo with the VERSION value'
        default: true
        type: boolean
      commit_message:
        description: 'Commit body (use | as line separator). E.g. "Changed X | Fixed Y"'
        type: string
      commit_author_name:
        description: 'Git author name for the delivery commit'
        type: string
      commit_author_email:
        description: 'Git author email for the delivery commit'
        type: string

jobs:
  deliver:
    uses: meaningfy-ws/devops-toolkit/.github/workflows/op-delivery.yml@main
    with:
      target_repo_url: ${{ inputs.target_repo_url || 'git@bitbucket.org:your-org/your-repo.git' }}
      target_branch: ${{ inputs.target_branch || 'develop' }}
      dry_run: ${{ inputs.dry_run || false }}
      create_tag: ${{ inputs.create_tag != '' && inputs.create_tag || true }}
      commit_message: ${{ inputs.commit_message || '' }}
      commit_author_name: ${{ inputs.commit_author_name || 'Meaningfy CI' }}
      commit_author_email: ${{ inputs.commit_author_email || 'plumber@meaningfy.ws' }}
      fortify_exclude_patterns: |
        **/docs/**/*
        **/test/**/*
      odc_exclude_patterns: |
        **/docs/**/*
        **/test/**/*
    secrets:
      SSH_DEPLOY_KEY: ${{ secrets.MY_DEPLOY_KEY }}
```

The `||` fallbacks provide defaults when triggered via `push` (testing) where `inputs.*` are empty. When using `workflow_dispatch`, the user fills in values from the UI.

> **Note:** `workflow_dispatch` only works when the workflow file exists on the repo's default branch. You must merge the caller workflow to the default branch before the "Run workflow" button appears in the GitHub UI.

## Deliverable Structure

After the workflow assembles the deliverable, the tree looks like this:

```
deliverable/
  docs/
    ...                                  # your documentation
  src/
    VERSION                              # copied from repo root VERSION
    filters/
      fortify-exclusion.properties       # generated by workflow
      odc-exclusion.properties           # generated by workflow
    your_package/
      ...                                # your source code
  test/
    ...                                  # your tests
```

### Full overwrite behavior

The `rsync --delete` flag means anything on the target branch that is NOT in the deliverable gets deleted. This ensures the target always exactly mirrors what you deliver.

## Developer Responsibilities

The workflow copies files as-is. Before delivery, developers must ensure:

| Requirement | Details |
|-------------|---------|
| **VERSION format** | `X.Y.Z-RC.N` (uppercase RC, dot before count). Example: `2.3.0-RC.5` |
| **No forbidden files** | OP forbids PDFs, ZIPs, DOCX in the delivered repo. Remove from `docs/` and `test/` before delivery. |
| **Lowercase filenames** | OP requires all lowercase filenames (enforcement is on the dev side) |
| **Directory structure** | `src/`, `test/`, `docs/` must exist with the expected content |
| **Security exclusion patterns** | Provide appropriate Fortify and ODC exclusion patterns in the caller workflow |

## Troubleshooting

### "Run workflow" button not visible

The caller workflow must exist on the repo's **default branch** for `workflow_dispatch` to appear in the GitHub UI. Merge the workflow file first, or use a `push` trigger during development.

### SSH permission denied

- Verify the deploy key has **write access** on the target repo
- Verify the `SSH_DEPLOY_KEY` secret contains the **private** key (not the public key)
- Check the key format: should start with `-----BEGIN OPENSSH PRIVATE KEY-----`

### "No changes to deliver"

The workflow detects when the deliverable is identical to what's already on the target branch. This is normal if you trigger a delivery without changing any delivered files. The workflow exits successfully with this message.

### rsync deleted files I need

`rsync --delete` removes anything on the target that isn't in the deliverable. This is by design -- the target branch should exactly mirror the deliverable.

### Workflow not triggering from reusable call

- Ensure `devops-toolkit` is **public** or has Actions sharing enabled for the org
- Ensure `devops-toolkit` has `allowed_actions: all` (not `local_only`)
- Check the `@ref` in the `uses:` line matches an existing branch or tag on devops-toolkit
