# Dataset Tasks

## Active objective

Build the first usable image-first benchmark.

## Task list

### Phase A: Source intake

- create `data/` workspace structure
- place public datasets into `data/raw/public/`
- place OCR stress datasets into `data/raw/stress/`
- record each source in an ingestion manifest

### Phase B: Normalization

- normalize public text seeds into one common schema
- tag each item by:
  - market
  - channel
  - label
  - category
- identify which samples are usable for synthetic rendering

### Phase C: Synthetic benchmark creation

- define screenshot templates
- render the first 100 synthetic screenshots
- assign quality tiers
- attach gold text and scam spans

### Phase D: Real benchmark intake

- define real-screenshot redaction rules
- define annotation workflow
- start collecting curated real screenshots in parallel

### Phase E: Benchmark packaging

- assemble benchmark `v0.1`
- create manifest and metadata files
- verify benchmark coverage across:
  - markets
  - channels
  - categories
  - quality tiers

## Minimum success criteria for dataset phase

- at least 200 benchmark-ready samples planned
- at least 100 synthetic screenshot samples rendered
- benchmark schema in use
- ingestion/source manifest in use
- enough samples to begin OCR bake-off

## Immediate next tasks

1. ~~render the first synthetic screenshot batch from `synthetic_batch_v0_1.csv`~~
2. ~~create screenshot templates for India and US SMS / WhatsApp / email~~
3. ~~attach render outputs back to the manifest~~
4. begin the OCR bake-off on the rendered batch
