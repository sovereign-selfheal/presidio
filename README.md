# presidio: NER image for the privacy gate

Container image of the Presidio analyzer with an English and an Italian NER model. The router of the
demo *The Sovereign, Self-Healing Platform* calls it to find names, places and other personal data
before it decides where a prompt goes. Read [`AGENTS.md`](AGENTS.md) before changing anything.

> **Support status:** Presidio and the spaCy models are community open source, **not** supported by
> Red Hat. This is a custom image, operated by the customer.

## Image

`quay.io/sovereign-selfheal/presidio:<version>` (public).

| Part | Version | Source |
|---|---|---|
| Base image | presidio-analyzer 2.2.364 (Python 3.12, spaCy 3.8) | `ghcr.io/data-privacy-stack/presidio-analyzer`, pinned by digest |
| English model | `en_core_web_lg` 3.8.0 | included in the base image |
| Italian model | `it_core_news_md` 3.8.0 | wheel from `explosion/spacy-models`, pinned by sha256 |
| NLP configuration | `nlp-config.yaml` | copied to `/opt/presidio/nlp-config.yaml`, read through `NLP_CONF_FILE` |

The models are added at build time. At runtime the pod needs no network access: in the cluster a
NetworkPolicy blocks all its egress.

The API is the standard Presidio one, on port 3000: `POST /analyze` (`text`, `language` `en` or `it`,
optional `entities`) and `GET /health`. The Italian model is `md`, not `lg`: see
[`docs/italian-ner-md-vs-lg.md`](docs/italian-ner-md-vs-lg.md).

## Release

Quay builds the image. A build trigger on the Quay repository follows the git tags of this repo:

1. Merge the change on `main`. The CI must be green.
2. Create and push a tag `vX.Y.Z` (for example `git tag v0.3.1 && git push origin v0.3.1`).
3. Quay builds `Containerfile` and publishes `quay.io/sovereign-selfheal/presidio:vX.Y.Z`.
4. In the `gitops` repo, pin the new image **by digest** in `components/presidio/values.yaml`, with the
   comment `# tag vX.Y.Z, resolved on quay.io on <date>`. Open a PR.

Never move or reuse a tag. To read the digest of a tag:

```bash
curl -fsS "https://quay.io/api/v1/repository/sovereign-selfheal/presidio/tag/?specificTag=vX.Y.Z" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["tags"][0]["manifest_digest"])'
```

Quay setup (once): public repository `sovereign-selfheal/presidio`, build trigger on the GitHub repo
`sovereign-selfheal/presidio`, only for refs that match `tags/v.*`, Dockerfile `/Containerfile`, context
`/`, image tag = git tag name (`${parsed_ref.tag}`), no `latest`.

## Check your changes (also run by CI)

```bash
uvx yamllint .
shellcheck tests/*.sh
hadolint Containerfile
podman build -f Containerfile -t localhost/presidio:dev .
tests/smoke.sh localhost/presidio:dev     # /health, then PERSON and LOCATION in English and Italian
```

## License

Apache License 2.0, see [LICENSE](LICENSE).
