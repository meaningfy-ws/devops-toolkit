# devops-toolkit

Reusable GitHub Actions workflows for Meaningfy projects.

## Workflows

### OP Delivery (`op-delivery.yml`)

Delivers source code from a Meaningfy GitHub repo to the OP (Publications Office) CITnet Bitbucket repository. Designed to be called from any Meaningfy project that participates in the OP CI/CD pipeline.

**What it does:**

1. Checks out the source repo at a given ref
2. Assembles a deliverable tree (`src/`, `test/`, `docs/` + optional extras)
3. Places `VERSION` at `src/VERSION` and generates security exclusion files
4. Validates the OP-mandatory directory structure
5. Either uploads an artifact for inspection (dry run) or pushes to CITnet's `develop` branch via SSH

**Quick start** -- add this to your project's `.github/workflows/op-deliver.yml`:

```yaml
name: Deliver to OP

on:
  workflow_dispatch:

jobs:
  deliver:
    uses: meaningfy-ws/devops-toolkit/.github/workflows/op-delivery.yml@main
    with:
      project_name: my-project
      source_ref: develop
      dry_run: true
    secrets:
      CITNET_DEPLOY_KEY: ${{ secrets.CITNET_DEPLOY_KEY }}
```

See [docs/op-delivery.md](docs/op-delivery.md) for the full reference.
