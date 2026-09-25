# =============================================================================
# Presidio analyzer with English and Italian NER (image quay.io/sovereign-selfheal/presidio).
# -----------------------------------------------------------------------------
# Adds the Italian spaCy model to the community analyzer, so the privacy gate of the
# router scores Italian text with an Italian model. The English-only stock image
# gives false positives on Italian text (for example "ciao" -> PERSON@0.85).
#
# SUPPORT STATUS: Presidio and the spaCy models are community open source, NOT
# supported by Red Hat. Custom, customer-operated image. The models are added at
# build time: no download and no egress at runtime.
#
# Quay builds this file on every git tag v* (build trigger): see README.md.
# =============================================================================
# presidio-analyzer 2.2.364 (multi-arch index), resolved on ghcr.io on 2026-09-25
FROM ghcr.io/data-privacy-stack/presidio-analyzer:2.2.364@sha256:ae8f6f111ac2f04e3fec552f7f80edd0dcbfa2dd69ee1b9e030475be31669885

USER 0

# Italian NER model, next to the English en_core_web_lg of the base image. The wheel
# is pinned by version and sha256 (pip checks the hash in the URL). Version 3.8.0
# matches spaCy 3.8.x of the base image.
# it_core_news_md 3.8.0, resolved on github.com/explosion/spacy-models on 2026-09-25
RUN python -m pip install --no-cache-dir \
    "https://github.com/explosion/spacy-models/releases/download/it_core_news_md-3.8.0/it_core_news_md-3.8.0-py3-none-any.whl#sha256=a731d2d8e7c5a7093ac42f88774ea2a2ad3d5809959eedee65632b3533f804ec"

# NLP engine configuration with both languages. app.py reads NLP_CONF_FILE at start-up
# and builds the AnalyzerEngine with supported_languages = [en, it].
COPY nlp-config.yaml /opt/presidio/nlp-config.yaml
ENV NLP_CONF_FILE=/opt/presidio/nlp-config.yaml

# Back to non-root. On OpenShift the SCC assigns an arbitrary UID; the spaCy models
# are installed world-readable, so any UID can read them.
USER 1000
