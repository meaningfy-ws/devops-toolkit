# OP Delivery Workflow -- Reference

Reusable GitHub Actions workflow that delivers source code to the OP CITnet Bitbucket repository.

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

The OP CI/CD pipeline requires source code to be pushed to a CITnet Bitbucket repository with a specific directory structure. This workflow automates that delivery so developers don't have to manually clone, copy, and push.

**Key design decisions:**

- **Selective copy**: Only `src/`, `test/`, `docs/` are copied by default (the three OP-mandatory directories). Additional root-level files can be included via `include_extra_paths`.
- **Develop-only push**: Per OP doc section 5.4, developers only have write access to `develop`. The workflow hardcodes pushing to `develop`.
- **No tagging**: OPS handles release branches, RC tags, and final release tags on CITnet.
- **Dev responsibility**: The workflow does NOT transform anything. Developers are responsible for OP-compliant naming, version strings, and directory layout.
- **SSH auth**: CITnet push uses SSH deploy keys (one per target repo).
- **Full overwrite**: `rsync --delete` ensures the CITnet `develop` branch exactly mirrors the deliverable. Files not included in the delivery are removed from CITnet.

## How It Works

```
Source repo (GitHub)          Deliverable tree (assembled)         CITnet (Bitbucket)
======================        ============================         ==================

src/  ─────────────────────>  src/                    ───────────> develop branch
test/ ─────────────────────>  test/                   ───────────>
docs/ ─────────────────────>  docs/                   ───────────>
VERSION ───(copy)──────────>  src/VERSION             ───────────>
(workflow generates)────────> src/filters/*.properties ──────────>
requirements.txt ──(extra)──> requirements.txt         ──────────>
README.md ─────────(extra)──> README.md                ──────────>
```

Steps executed by the workflow:

1. **Checkout** the source repo at the specified `source_ref`
2. **Copy** `src/`, `test/`, `docs/` into a staging directory
3. **Copy extra paths** listed in `include_extra_paths` (root-level files, additional dirs)
4. **Place VERSION** at `src/VERSION` (OP requirement 5.2.3)
5. **Generate** `src/filters/fortify-exclusion.properties` and `src/filters/odc-exclusion.properties` from the provided patterns
6. **Validate** that `src/`, `test/`, `docs/` all exist in the deliverable
7. **Dry run**: Upload the deliverable as a GitHub Actions artifact for inspection
8. **Real run**: Clone CITnet `develop`, rsync the deliverable over it, commit, and push

## Prerequisites

- The calling repo must be **public** (or in the same org with workflow sharing enabled), because GitHub does not allow public repos to call reusable workflows from private repos.
- `devops-toolkit` must have **Actions sharing** enabled ("Accessible from repositories in the organization").
- `devops-toolkit` must have `allowed_actions` set to `all` (not `local_only`), so it can use `actions/checkout` and `actions/upload-artifact`.

## Setup Guide

### 1. Create a CITnet deploy key

Generate an SSH keypair dedicated to the CITnet Bitbucket repo:

```bash
ssh-keygen -t ed25519 -C "op-delivery-<project-name>" -f citnet-deploy-key -N ""
```

- Add the **public key** (`citnet-deploy-key.pub`) as a deploy key with **write access** on the CITnet Bitbucket repo.
- Add the **private key** (`citnet-deploy-key`) as a GitHub Actions secret named `CITNET_DEPLOY_KEY` on your source repo.
- Delete the local key files after adding them.

### 2. Create the caller workflow

Add `.github/workflows/op-deliver.yml` to your project (see [examples](#caller-workflow-examples) below).

### 3. Test with dry run

Set `dry_run: true` in your caller workflow. Push to trigger it. Check the uploaded artifact in the GitHub Actions run to verify the deliverable structure.

### 4. Test with a throwaway repo

Before pointing at the real CITnet repo, create a disposable test repo and use it as the `citnet_repo_url`. This lets you verify the full push flow without risk.

### 5. Go live

Once verified:
- Set `dry_run: false`
- Set `citnet_repo_url` to the real CITnet Bitbucket SSH URL
- Replace the test deploy key secret with the real CITnet deploy key
- Change the trigger to `workflow_dispatch` (requires the workflow to exist on the default branch)

## Inputs Reference

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `project_name` | Yes | -- | Project name for artifact naming and logs |
| `source_ref` | Yes | -- | Git ref to checkout (branch, tag, SHA) |
| `deliverable_path` | No | `.` | Root directory containing `src/`, `test/`, `docs/` |
| `version_file` | No | `VERSION` | Path to the VERSION file in the source repo |
| `include_extra_paths` | No | `''` | Additional files/dirs to include (one per line) |
| `fortify_exclusions` | No | `''` | Fortify scan exclusion patterns (one per line) |
| `odc_exclusions` | No | `''` | OWASP Dependency Check exclusion patterns (one per line) |
| `dry_run` | No | `false` | If true, uploads artifact instead of pushing |
| `git_author_name` | No | `Meaningfy CI` | Git author name for CITnet commits |
| `git_author_email` | No | `ci@meaningfy.ws` | Git author email for CITnet commits |
| `commit_message` | No | `''` | Multi-line commit body appended after the subject line (see below) |
| `citnet_repo_url` | No | `''` | SSH URL of the CITnet Bitbucket repo |

### Commit message

The CITnet commit subject is always `delivery: <version>`. If you provide `commit_message`, it becomes the commit body (separated by a blank line).

**From YAML** (hardcoded in caller) — use block scalar for multi-line:

```yaml
commit_message: |
  - Fixed airflow Dockerfile base image
  - Updated DAG retry config
  - Added new mapping suite processor
```

**From workflow_dispatch UI** — use pipe (`|`) as a line separator:

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

`include_extra_paths`, `fortify_exclusions`, and `odc_exclusions` accept one entry per line using YAML block scalar syntax:

```yaml
include_extra_paths: |
  requirements.txt
  README.md
  LICENSE
```

Exclusion patterns are joined with commas in the generated `.properties` files:
```
excludePatterns=**/docs/**/*,**/test/**/*
```

## Secrets Reference

| Secret | Required | Description |
|--------|----------|-------------|
| `CITNET_DEPLOY_KEY` | For real runs | SSH private key for pushing to CITnet. Not needed for dry runs. |

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
      project_name: ted-rdf-conversion-pipeline
      source_ref: feature/my-delivery-branch
      dry_run: true
      include_extra_paths: |
        requirements.txt
        README.md
        LICENSE
      fortify_exclusions: |
        **/docs/**/*
        **/test/**/*
      odc_exclusions: |
        **/docs/**/*
        **/test/**/*
```

### Production (manual dispatch)

```yaml
name: Deliver to OP

on:
  workflow_dispatch:
    inputs:
      source_ref:
        description: 'Branch or tag to deliver'
        required: true
        default: 'develop'
      dry_run:
        description: 'Dry run (artifact only, no push)'
        required: false
        type: boolean
        default: false
      commit_message:
        description: 'Delivery description (use | to separate lines)'
        required: false
        default: ''

jobs:
  deliver:
    uses: meaningfy-ws/devops-toolkit/.github/workflows/op-delivery.yml@main
    with:
      project_name: ted-rdf-conversion-pipeline
      source_ref: ${{ github.event.inputs.source_ref }}
      dry_run: ${{ github.event.inputs.dry_run == 'true' }}
      commit_message: ${{ github.event.inputs.commit_message }}
      citnet_repo_url: ssh://git@citnet-bitbucket.example.com:7999/project/repo.git
      include_extra_paths: |
        requirements.txt
        README.md
        LICENSE
        tox.ini
        .gitignore
        .gitattributes
      fortify_exclusions: |
        **/docs/**/*
        **/test/**/*
      odc_exclusions: |
        **/docs/**/*
        **/test/**/*
    secrets:
      CITNET_DEPLOY_KEY: ${{ secrets.CITNET_DEPLOY_KEY }}
```

> **Note:** `workflow_dispatch` only works when the workflow file exists on the repo's default branch. You must merge the caller workflow to the default branch before the "Run workflow" button appears in the GitHub UI.

## Deliverable Structure

After the workflow assembles the deliverable, the tree looks like this (using ted-rdf-conversion-pipeline as an example):

```
deliverable/
  .gitattributes
  .gitignore
  LICENSE
  README.md
  requirements.txt
  tox.ini
  docs/
    antora-playbook.yml
    antora/
      ...
  src/
    VERSION                              # copied from root VERSION
    dags/
      ...
    filters/
      fortify-exclusion.properties       # generated by workflow
      odc-exclusion.properties           # generated by workflow
    infra/
      airflow/Dockerfile
      digest-api/Dockerfile
      scripts/create-and-deploy-images.sh
      scripts/upload-env.sh
      env.template
    notebooks/
      ...
    ted_sws/
      ...
  test/
    conftest.py
    e2e/
    features/
    mocks/
    fakes/
    test_data/
    unit/
      ...
```

### What is NOT delivered

The workflow only copies what you explicitly include. Typically excluded from delivery:

- `infra/` (repo root) -- Meaningfy-internal local dev stack (docker-compose files)
- `libraries/` -- Java JARs for local dev; OP operators download from Nexus
- `.github/` -- CI workflows for the source repo (not relevant to CITnet)
- `Makefile`, `setup.py`, `pyproject.toml` -- unless added to `include_extra_paths`

### Full overwrite behavior

The `rsync --delete` flag means anything on CITnet's `develop` branch that is NOT in the deliverable gets deleted. This ensures CITnet always exactly mirrors what you deliver. If you need to preserve files that OP maintains on their side, add them to `include_extra_paths` in your caller workflow.

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
- Verify the `CITNET_DEPLOY_KEY` secret contains the **private** key (not the public key)
- Check the key format: should start with `-----BEGIN OPENSSH PRIVATE KEY-----`

### "No changes to deliver"

The workflow detects when the deliverable is identical to what's already on CITnet `develop`. This is normal if you trigger a delivery without changing any delivered files. The workflow exits successfully with this message.

### rsync deleted files I need

`rsync --delete` removes anything on CITnet that isn't in the deliverable. If OP-maintained files were deleted, add them to `include_extra_paths` or reconsider the delivery scope.

### Workflow not triggering from reusable call

- Ensure `devops-toolkit` is **public** or has Actions sharing enabled for the org
- Ensure `devops-toolkit` has `allowed_actions: all` (not `local_only`)
- Check the `@ref` in the `uses:` line matches an existing branch or tag on devops-toolkit
