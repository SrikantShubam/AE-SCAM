# Execution Status

## Active Focus

The current execution priority is intentionally narrow. Before building more of
the app, we are focusing on the three foundation objectives:

1. procure or build the image-first scam dataset
2. test the OCR options we may ship
3. test the classification stack on the resulting benchmark

These three objectives are the current crux of the project. Everything else is
downstream of them.

## Subplan Status

- ~~Product Definition~~
  - ~~final user promise~~
  - ~~result-state contract~~
  - ~~explanation style~~
  - ~~next-action rules at planning level~~
  - ~~v1 vs v2 boundary at planning level~~

- UX and Screens
  - ~~screen/state map exists in the Claude final paper~~
  - senior-friendly visual rules
  - OCR failure flow implementation planning
  - result screen implementation planning
  - guest-to-account flow validation
  - copy testing with real users

- OCR
  - ~~local OCR direction chosen: ML Kit first~~
  - benchmark ML Kit vs alternatives
  - define OCR quality gate numerically
  - define OCR failure handling in product spec
  - decide whether cloud OCR is premium-only later

- Classification
  - ~~architecture chosen: cheap hosted first pass + stronger hosted second pass~~
  - provider shortlist
  - structured output contract
  - threshold calibration with benchmark
  - actual model selection

- Policy Layer
  - ~~high-level policy direction defined~~
  - exact implementation spec
  - exact `not_scam` gate in code terms
  - exact `unclear` triggers in code terms
  - category mapping implementation

- Benchmark and Evaluation
  - ~~benchmark structure defined~~
  - ~~procure initial public datasets~~
  - ~~build first synthetic screenshot batch~~
  - build internal screenshot benchmark
  - build hard-case set
  - run OCR eval
  - run model eval

- Monetization
  - ~~direction chosen: freemium + ads after threshold + premium advanced features~~
  - exact free limits
  - exact ad logic
  - exact premium boundaries
  - market-by-market cost model

- Legal / Privacy
  - ~~high-level legal/privacy concerns identified~~
  - counsel review
  - final disclosure copy
  - consent flow design
  - reporting/data-retention implementation decisions

- App Foundation
  - clean Flutter scaffold
  - architecture modules
  - environment config
  - CI and testing setup
  - event taxonomy implementation

- Release
  - ~~launch-gate framework exists in the Claude final paper~~
  - private beta preparation
  - limited public launch prep
  - Play Store assets
  - support and review ops

## Current Order of Work

1. image-first dataset
2. OCR bake-off
3. classification evaluation
4. only then continue with broader implementation work

## Current checkpoint

- dataset phase has started
- UCI SMS Spam Collection has been downloaded, extracted, and normalized
- Mendeley SMS phishing dataset has been extracted and normalized
- CIRCL OCR-stress dataset is partially downloaded and usable
- Phish-IRIS OCR-stress dataset has been added and pruned to a curated subset
- Sting9 has been explicitly excluded from the active dataset path
- combined seed pool `seed_pool_v0_1.csv` has been created
- first synthetic batch manifest `synthetic_batch_v0_1.csv` has been created
- first synthetic screenshot batch has been rendered:
  - `80` images written under `data/synthetic/renders/v0_1/`
  - `data/interim/manifests/synthetic_render_manifest.csv` written with render metadata
- `20` manifest rows remain `manual_curate` placeholders for later `unclear` authoring
- OCR benchmark inventory has been assembled:
  - `data/benchmark/v0.1/metadata/ocr_eval_manifest.csv`
  - `626` rows total across synthetic and stress sources
- first OCR baseline has been run with `rapidocr_onnxruntime`:
  - `80` scored synthetic samples
  - `20` stress-smoke samples
  - report note in `data/benchmark/v0.1/reports/rapidocr_baseline_v0_1.md`
- reference transcript pipeline is now defined:
  - `REFERENCE_TRANSCRIPT_PIPELINE.md`
  - `data/benchmark/v0.1/metadata/reference_transcript_manifest.csv`
  - three-engine synthetic consensus has now been run:
    - `65` `auto_accept`
    - `13` `llm_resolved` with Gemini
    - `2` `manual_review`
    - `546` `needs_more_ocr`
  - status note in `data/benchmark/v0.1/reports/reference_transcript_status_v0_1.md`
- next concrete step is generating additional OCR outputs for the `546` stress or
  real images so the same consensus pipeline can start resolving them too
- India-specific benchmark planning has been added and must be reflected in the
  first benchmark iterations
