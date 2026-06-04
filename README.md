# devops-toolkit

Reusable GitHub Actions workflows and developer tools for Meaningfy projects.

## Tools

### WorkSpaces PCoIP Client (`tools/workspaces-pcoip/`)

Runs the Amazon WorkSpaces PCoIP client via a headless QEMU/KVM VM with X11
forwarding. Needed because the native Ubuntu 22/24 client only supports DCV,
and the Ubuntu 20.04 PCoIP client crashes on kernel 6.17+.

See [tools/workspaces-pcoip/README.md](tools/workspaces-pcoip/README.md) for setup and usage.

## Workflows

### OP Delivery (`op-delivery.yml`)

Delivers source code from a Meaningfy GitHub repo to a target Git repository (typically the OP CITnet Bitbucket). Designed to be called from any Meaningfy project that participates in the OP CI/CD pipeline.

**What it does:**

1. Checks out the source repo at the triggering ref
2. Assembles a deliverable tree (`src/`, `test/`, `docs/`)
3. Places `VERSION` at `src/VERSION` and generates security exclusion files
4. Validates the OP-mandatory directory structure
5. Either uploads an artifact for inspection (dry run) or pushes to the target branch via SSH
6. Optionally tags the delivery on the target repo

**Quick start** -- add this to your project's `.github/workflows/op-deliver.yml`:

```yaml
name: Deliver to OP

on:
  workflow_dispatch:

jobs:
  deliver:
    uses: meaningfy-ws/devops-toolkit/.github/workflows/op-delivery.yml@main
    with:
      target_repo_url: git@bitbucket.org:your-org/your-repo.git
      commit_author_name: Your Name
      commit_author_email: plumber@meaningfy.ws
      dry_run: true
    secrets:
      SSH_DEPLOY_KEY: ${{ secrets.MY_DEPLOY_KEY }}
```

See [docs/op-delivery.md](docs/op-delivery.md) for the full reference.
