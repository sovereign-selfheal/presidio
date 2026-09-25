# AGENTS.md: `presidio` repository

Guidance for AI coding agents and humans working in this repo. Read it fully before you change anything.

## 1. Purpose

This repository builds **one container image**: the Presidio analyzer with an English and an Italian NER
model, `quay.io/sovereign-selfheal/presidio`. The privacy gate of the router (`router` repo) sends it the
prompts and gets back the entities it finds (names, places, card numbers and so on). The `gitops` repo
deploys the image. This repo contains no Kubernetes manifests.

## 2. Contract with the `router` and `gitops` repos

**Ownership. Each item has one owner.**

| Owner | Items |
|---|---|
| `presidio` (this repo) | `Containerfile`, `nlp-config.yaml`, the NER models and their versions, the image tags |
| `router` | The code that calls the analyzer (`privacy_scoring.py`) and the evaluation data |
| `gitops` | Deployment, Service, NetworkPolicy, replicas and resources of the analyzer; the image digest in use; the policy `privacy-plus.yaml` (entity weights, `min_confidence`) |

The image offers this interface. Do not change it without a new **minor** version and a note in the
README. Update the other repos in the same change set.

- **API**: Presidio analyzer on port **3000**. `POST /analyze` with `text`, `language` and an optional
  `entities` list; `GET /health`.
- **Languages**: `en` and `it`. `privacy-plus.yaml` in `gitops` lists them in `ner.supported_languages`.
- **Entity types** the router reads: `PERSON`, `LOCATION`, `NRP`, `IBAN_CODE`, `CREDIT_CARD`, `US_SSN`,
  `PHONE_NUMBER`, `IP_ADDRESS`, `MEDICAL_LICENSE`. They must stay available in both languages where
  Presidio supports them.
- **Configuration**: `NLP_CONF_FILE=/opt/presidio/nlp-config.yaml`.
- **Runtime**: any UID (OpenShift `restricted` SCC), no network access. The pod has **no egress** at all
  (NetworkPolicy in `gitops`), so nothing can be downloaded at runtime.
- **Command**: the `gitops` Deployment starts gunicorn with its own arguments (1 worker, 4 threads). The
  image must keep `gunicorn` and `app:create_app()` of the base image.

A new model or a new base version changes the scores. Before a release that changes a model, run the
evaluation of the `router` repo against the new image. Report the changes in accuracy and leaks in the PR.

## 3. Layout

```
Containerfile        # base image pinned by digest + Italian model + NLP configuration
nlp-config.yaml      # spaCy models per language
tests/smoke.sh       # runs the built image: /health, PERSON and LOCATION in en and it
docs/                # notes (Italian model md or lg)
.github/workflows/   # CI: lint, build without push, smoke test
```

## 4. Conventions

- **Pins**: the base image is pinned by digest, and every model or wheel by version and sha256. A comment
  says where and when it was resolved (`# ..., resolved on ghcr.io on 2026-09-25`).
- **Build-time downloads only**: models and packages are added in the `Containerfile`, with a checked hash.
- **Support status**: Presidio and spaCy are community open source, not supported by Red Hat. Say so in
  every document that describes the image.
- **Non-root**: the image ends with a non-root `USER`. Files must be readable by any UID.
- Comments, docs and commit messages in **English**, level B2/C1: short, clear sentences, no idioms.
- **Python tools with uv** (`uvx`, `uv run --with`), never pip on the host. `pip` inside the
  `Containerfile` is fine: it is the tool of the base image.

## 5. Release

Quay builds and publishes the image. This repo pushes nothing.

1. Merge on `main` with a green CI.
2. Tag `vX.Y.Z` and push the tag. Quay's build trigger builds the tag and publishes
   `quay.io/sovereign-selfheal/presidio:vX.Y.Z`.
3. PR on `gitops`: pin the new digest in `components/presidio/values.yaml`, with
   `# tag vX.Y.Z, resolved on quay.io on <date>`.

- Semantic versions: **patch** for rebuilds and fixes with the same interface; **minor** for a new model or
  base version, or a change of the interface in §2; **major** for a breaking change.
- Never move, delete or reuse a tag. `gitops` never follows a tag automatically.

## 6. Before you open a PR

```bash
uvx yamllint .
shellcheck tests/*.sh
hadolint Containerfile
podman build -f Containerfile -t localhost/presidio:dev .
tests/smoke.sh localhost/presidio:dev
```

## 7. Out of scope

- Kubernetes manifests, replicas, resources, NetworkPolicy → `gitops` repo.
- Router code, policies and scoring → `router` repo (code) and `gitops` repo (policies).
- Cluster preparation and operators → `ansible` repo.

## 8. When in doubt

- Prefer the smallest change that keeps the interface in §2 valid.
- Ask before changing a model, the base image version, or the interface in §2.
