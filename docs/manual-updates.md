# TED-SWS Installation Manual — Required Updates

These changes need to be made to the installation manual before real OP delivery.
This file is gitignored and will NOT be pushed.

Sources:
- Main manual: "TED-SWS Installation manual" (doc version 2.8.0, SWS version 2.3.0-rc.5)
- Updates manual: "TED-SWS installation manual updates" (doc version 3.3.2, SWS version 2.3.0-rc.4)

## 1. Path changes (ted_sws/ and dags/)

The manual (page 9, "Initial code deployment to EFS") says:

> Copy the ted_sws and dags folders from the TED-SWS pipeline source code

**Old paths:** `ted_sws/` and `dags/` at repo root
**New paths:** `src/ted_sws/` and `src/dags/`

Update the EFS deployment instructions accordingly.

## 2. infra/ directory structure

The manual references `infra/airflow/` and `infra/digest_api/` as flat paths.
The `src/infra/` directory has been flattened — the old `aws/` nesting is removed.

**Old paths (manual):**
- `infra/airflow/Dockerfile`
- `infra/digest_api/Dockerfile`

**New paths (repo):**
- `src/infra/airflow/Dockerfile`
- `src/infra/digest-api/Dockerfile` (note: hyphen, not underscore)
- `src/infra/scripts/create-and-deploy-images.sh`
- `src/infra/scripts/upload-env.sh`
- `src/infra/env.template`

The root `infra/` directory is now Meaningfy-internal (local dev stack).
`src/infra/` is the OP-facing infrastructure directory.
CloudFormation templates have been removed (OP manages infrastructure separately).

## 3. Build script

The main manual (page 7, "Building images", Method 1) says:

> In the source code, go to infra/aws folder
> Run build-images-with-podman.sh script

**This script does not exist.** The actual script is:
`src/infra/scripts/create-and-deploy-images.sh`

Update the manual to reference the correct path and filename.

## 4. Airflow image build instructions

The updates manual (page 2, "Airflow image") says:

> 1. In the source code, copy ./src/requirements.txt to infra/airflow folder
> 2. In the source code, create ./libraries in infra/airflow folder
> 3. Create .limes .rmlmapper .saxon folders in infra/airflow/libraries
> 4. Take the rml-mapper (6.2.2), saxon (saxon-he-10.9) and limes (1.7.9) libraries from Nexus

**Updated instructions:**
- `requirements.txt` is at repo root (delivered via include_extra_paths)
- Libraries are NOT in the repo — operator downloads from Nexus (unchanged)
- Dockerfile is at `src/infra/airflow/Dockerfile`
- The operator copies `requirements.txt` into the Docker build context alongside the Dockerfile

Note: The Dockerfile does `COPY requirements.txt` and `COPY libraries /home/airflow`,
so both must be present in the build context directory when running `podman build`.

## 5. Digest-api image build instructions

The main manual (page 8) says:

> 1. Copy ./requirements.txt from source code root to infra/digest_api/digest_service/project_requirements.txt
> 2. Copy ted_sws folder from source code to the infra/digest_api folder

**Updated instructions:**
- requirements.txt is at repo root (delivered via include_extra_paths)
- ted_sws is at `src/ted_sws/`
- Dockerfile is at `src/infra/digest-api/Dockerfile` (hyphen, not underscore)

## 6. PDFs in docs/

OP CI/CD Pipeline Definition forbids PDFs in the delivered repo. The following PDFs
must be removed from `docs/` before delivery:

- `docs/antora/modules/ROOT/attachments/aws-infra-docs/TED-SWS-Installation-manual-v2.5.0.pdf`
- `docs/antora/modules/ROOT/attachments/aws-infra-docs/TED-SWS-Installation-manual-v2.0.2.pdf`
- `docs/antora/modules/ROOT/attachments/aws-infra-docs/TED-SWS-AWS-Installation-manual-v0.9.pdf`
- `docs/antora/modules/ROOT/attachments/aws-infra-docs/TED-SWS-AWS-Infrastructure-architecture-overview-v0.9.pdf`

**Dev responsibility:** Remove before real delivery.

## 7. VERSION format

The VERSION file currently says `2.3.0-rc.4` (lowercase rc).
OP requires `X.Y.Z-RC.N` format (uppercase RC, dot before count).

**Dev responsibility:** Update to `2.3.0-RC.4` (or whatever the current RC number is) before delivery.

## Summary of repo changes needed (ted-rdf-conversion-pipeline)

| Change | Where | Status |
|--------|-------|--------|
| Deliver requirements.txt at repo root via include_extra_paths | caller workflow | DONE |
| ~~Copy libraries/ into src/infra/~~ | ~~ted repo~~ | CANCELLED (libraries come from Nexus) |
| Remove 4 PDFs from docs/ | ted repo | TODO (before real delivery) |
| Fix VERSION to uppercase RC | ted repo | TODO (before real delivery) |
| Update installation manual with new paths | manual document | TODO |
