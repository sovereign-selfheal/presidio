# Italian NER model: `md` or `lg`

The image adds an Italian spaCy model next to the English `en_core_web_lg` of the base image.
Today it uses **`it_core_news_md`**. `it_core_news_lg` finds more names, but it needs more memory.

## The difference

Both models use the same NER architecture. The only real difference is the table of word vectors:

| | `it_core_news_md` | `it_core_news_lg` |
|---|---|---|
| Size on disk | about 43 MB | about 540-740 MB |
| Word vectors | reduced (about 20k vectors for about 500k words) | full (about 500k vectors) |
| NER accuracy | good | a few F1 points higher, mostly on rare names |
| Memory in the pod | low | the full table stays in memory: about +0.5-1 GB |

Word vectors help the model with words and names that it did not see in training. On general
NER tasks, the gain from `md` to `lg` is a few F1 points.

## Why `md`

The Presidio pod already loads `en_core_web_lg` (about 560 MB). A second full table of vectors
would take the pod close to its memory limit. For the demo, the small gain in recall does not justify
this cost. The decision was taken on 2026-07-09.

## How to switch to `lg`

1. In `Containerfile`, install the `lg` wheel instead of the `md` wheel. Pin the version and the
   sha256 in the URL, like today.
2. In `nlp-config.yaml`, set `model_name: it_core_news_lg`.
3. Release a new version (see [README](../README.md#release)).
4. In the `gitops` repo (`components/presidio/values.yaml`), pin the new digest and raise the memory:
   request `3Gi`, limit `5Gi` or more. A bigger model also starts more slowly: check the startup probe.
5. `lg` changes the confidence scores. Run the evaluation of the `router` repo again and check
   `ner.min_confidence` and `ner.entity_weights` in the `gitops` policy `privacy-plus.yaml`.

## When `lg` is worth it

Switch to `lg` when the router misses Italian names or places that matter for the privacy
decision, and the cluster has enough memory. Otherwise keep `md`.
