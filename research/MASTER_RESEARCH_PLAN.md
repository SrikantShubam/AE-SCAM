# Master Research Plan

## Objective

This document merges the current research threads into one decision-oriented
plan for the v1 scam-message checker app.

The product goal is narrow:

- help seniors and caregivers check suspicious messages
- primary input: screenshot
- secondary input: pasted text
- output: simple risk categorization, short explanation, clear next step

## Locked Architecture Direction

The current default architecture is:

- local OCR on-device
- cheap hosted first-pass classification
- stronger hosted second-pass reasoning for ambiguous cases
- policy layer for final output

We are not currently planning to ship a large local classifier in v1 because
binary size and install friction matter for the target audience.

## Product Semantics

### Core result states

Working internal states:

- `scam`
- `not_scam`
- `unclear`

Working user-facing labels to test:

- `Likely scam`
- `Be careful`
- `Looks safe for now`

These are placeholders, not final copy. They should be tested for clarity with
older adults because seniors often prefer directness over vague language.

### What each state means

- `Scam`
  - strong evidence of deception, impersonation, credential theft, payment
    extraction, remote-access coercion, or similar malicious intent
- `Not scam`
  - no strong scam signals found and no material evidence of impersonation,
    coercion, or unsafe information/payment request
- `Unclear`
  - evidence is mixed, incomplete, or too weak for a safe conclusion

### Explanation quality bar

The explanation should:

- identify the reason, not model mechanics
- stay simple and non-technical
- fit in roughly 120 characters for the main summary
- avoid fake certainty

Good explanation examples:

- `It asks for urgent payment and pretends to be your bank.`
- `This message asks for your password or code. That is a scam sign.`

### Next action

The result should always include one concrete instruction:

- `Do not reply. Call your bank using the number on your card.`
- `Do not click the link. Delete the message if you do not know the sender.`
- `Paste the text instead so we can check it again.`

This is necessary because a user in a panic moment needs an immediate safe move,
not only a label.

### Accounts

Recommended v1 policy:

- allow guest checks
- ask for email account creation only when needed for premium, history sync, or
  recovery

Do not force sign-up before first value is delivered.

## Scam Taxonomy for v1

Recommended top-level categories:

1. `Impersonation`
2. `Credential theft`
3. `Payment extraction`
4. `Tech support / device compromise`
5. `Emotion / pressure fraud`

Why this set:

- it aligns better with common elder-fraud and phishing patterns
- it maps well to screenshot-based and text-based analysis
- it is simpler and more actionable than broad buckets like `selling` or
  generic `fraud`

## Dataset Strategy

No single public dataset will be enough. Use three layers.

### Layer A: Public seed datasets

Use public datasets to bootstrap taxonomy and early evaluation:

- UCI SMS Spam Collection
- Mendeley SMS phishing dataset
- Sting9-style scam/phishing datasets

### Layer B: Internal benchmark

Build an internal benchmark focused on real product conditions:

- SMS screenshots
- WhatsApp screenshots
- email screenshots
- fake bank / telecom / delivery alerts
- varying image quality: clean, medium, hard

### Layer C: Hard-case set

Keep a separate regression set for:

- ambiguous legitimate financial alerts
- OTP messages
- courier or delivery notifications
- support follow-ups
- gray-area solicitation or reminders

## Benchmark Structure

Each benchmark item should include:

- `sample_id`
- `market`
- `channel`
- `input_type`
- `ground_truth_label`
- `category`
- `message_text_gold`
- `image_quality`
- `ocr_output`
- `ocr_edit_distance`
- `model_output`
- `final_policy_output`
- `human_explanation`
- `recommended_action`

The benchmark should separate OCR evaluation from classification evaluation.

## OCR Research Plan

### Goal

Pick the best lightweight OCR for mobile screenshots.

### Starting candidate

- Google ML Kit Text Recognition v2

### Alternatives to benchmark

- Tesseract
- PaddleOCR mobile-friendly variants

### Evaluation rubric

Measure:

- extraction accuracy on scam-relevant spans
- latency on low-end Android devices
- app-size impact
- memory / initialization cost
- failure behavior on blurry or compressed screenshots

### OCR failure policy

If local OCR fails:

1. show a calm failure state
2. offer `Paste text instead`
3. offer `Try another screenshot`

Premium fallback can optionally use cloud OCR or vision extraction, but that
must be explicit because it changes cost, privacy, and latency.

## Model Routing Research Plan

### Current architecture

1. local OCR
2. cheap hosted first-pass classifier
3. if score is high enough, return `scam`
4. if score is low enough, return `not_scam`
5. if score falls in the middle band, run a stronger hosted second pass

This is a valid v1 design.

### Thresholds

Current values like `>85`, `<45`, `45-84` are placeholders only.

Final thresholds must be calibrated using:

- benchmark confusion matrices
- per-category performance
- OCR quality interactions
- cost of second-pass routing
- tolerance for false reassurance vs false alarms

### Decision stack

Recommended stack:

1. OCR text quality gate
2. deterministic scam-signal rules
3. cheap hosted primary classifier
4. stronger hosted fallback reasoning model
5. policy layer for user-facing output

### Why this is the current default

- it keeps the app smaller than shipping a large local classifier
- it keeps OCR local, which is the biggest on-device cost saver
- it allows fast model iteration as scam patterns evolve
- it supports stronger handling of novel scam types through escalation to the
  second pass

### Monetization implications

This architecture fits a freemium model well:

- cheap hosted first pass keeps standard-path cost low
- ads can be shown only after free-usage thresholds, not during active result
  flow
- premium can unlock more second-pass coverage, cloud OCR fallback, and history
  or caregiver features

## Evaluation Priorities

### Highest-risk product failures

- false reassurance on obvious scams
- poor OCR on real screenshots
- explanations users do not understand
- too many false alarms on legitimate bank / account messages

### Acceptance principles

- optimize for high recall on obvious scams
- keep false positives controlled on legitimate transactional messages
- use `unclear` as a safety buffer when evidence is weak

Do not lock exact false-positive targets before the first benchmark is built.

## Open Questions Requiring More Research

- Which user-facing label set is clearest for seniors?
- What exact next actions should map to each result state and category?
- Which OCR engine wins on the real screenshot benchmark?
- Which low-cost primary model and stronger fallback model provide the best
  cost-accuracy tradeoff?
- What second-pass trigger band minimizes cost without weakening safety?
- When should guest usage convert to account creation?
- What premium features help without diluting the core message-checker product?

## Recommended Immediate Outputs

1. one canonical PRD
2. one benchmark schema
3. one OCR comparison matrix
4. one model-comparison scorecard
5. one copy-testing plan for result labels and explanations

## Open Decisions

These decisions are not final yet and should be resolved with evidence, not
intuition.

### Product decisions

- final user-facing result labels
- final result-state contract
- exact role of the category label in the UI
- whether the main screen should show `Scam / Not scam / Unclear` internally and
  friendlier copy externally

### Growth and monetization decisions

- guest mode limits before sign-up or premium prompts
- account gating policy
- free daily check allowance
- premium feature scope for v1 or shortly after v1
- whether ads should exist in v1 or be deferred until trust is proven
- whether second-pass usage should differ between free and premium users

### Launch decisions

- exact India and US rollout sequence
- whether India and US should share the same initial thresholds
- whether market-specific copy variants are needed from day one

## Known Assumptions

These are current planning assumptions and should remain explicit until changed.

- v1 is English only
- v1 supports India and US only
- primary input is screenshot
- secondary input is pasted text
- OCR is local first
- model input is extracted text, not screenshots, for the normal path
- second-pass model runs only on ambiguous cases
- first-pass classification is hosted by default for v1
- the app is a message checker, not a general anti-scam assistant
- calls are out of scope for v1
- multi-agent orchestration is out of scope for v1
- senior-friendly UX matters more than model novelty

## What Needs Evidence

These are the questions that need benchmark data, user testing, or direct
evaluation before locking product decisions.

- which OCR engine performs best on real screenshot inputs
- which first-pass model gives the best speed-cost-accuracy tradeoff
- which fallback model is worth its added cost
- what threshold band gives the safest routing policy
- which result labels seniors understand most clearly
- which explanations seniors trust and act on correctly
- how often guest mode should be allowed before upgrade pressure appears
- what false-positive rate is acceptable on legitimate transactional messages
- what false-negative rate is acceptable on obvious scam messages
- whether cloud OCR fallback is worth the cost and privacy complexity
- what ad policy preserves trust while keeping the free tier viable

## Hard Constraints

These constraints should be treated as non-negotiable during research and build
planning.

- low latency on normal checks
- low cost per check
- low app size and install friction
- senior-friendly and low-friction UX
- no fake certainty
- strong protection against false reassurance
- simple architecture that can be tested end to end
- no infra sprawl before the core checker works
- no feature creep that dilutes the message-checking core

## Decision Templates

Use these tables while comparing options and recording research conclusions.

### OCR Comparison Template

| OCR option | On-device latency | Accuracy on clean screenshots | Accuracy on hard screenshots | App size impact | Implementation complexity | Failure behavior | Recommendation |
|---|---|---|---|---|---|---|---|
| ML Kit | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Tesseract | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| PaddleOCR | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

### Model Comparison Template

| Model | Role | Cost per check | Latency | Accuracy | Explanation quality | Determinism / consistency | Best use | Recommendation |
|---|---|---|---|---|---|---|---|---|
| Model A | cheap hosted primary | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Model B | stronger hosted fallback | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Model C | alternate hosted vendor | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

### Label Testing Template

| Label set | State 1 | State 2 | State 3 | Senior comprehension | Clarity under stress | Ambiguity risk | Tone quality | Recommendation |
|---|---|---|---|---|---|---|---|---|
| Set A | Likely scam | Be careful | Looks safe for now | TBD | TBD | TBD | TBD | TBD |
| Set B | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Set C | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

### Benchmark Schema Template

| Field | Required | Description |
|---|---|---|
| sample_id | yes | unique sample identifier |
| market | yes | india or us |
| channel | yes | sms, whatsapp, email, popup, other |
| input_type | yes | screenshot or text |
| ground_truth_label | yes | scam, not_scam, unclear |
| category | yes | top-level category |
| message_text_gold | yes for screenshots | human-corrected gold text |
| image_quality | for screenshots | clean, medium, hard |
| ocr_output | for screenshots | OCR extracted text |
| model_output | yes | model result details |
| final_policy_output | yes | final app decision |
| human_explanation | yes | approved short explanation |
| recommended_action | yes | concrete next action |

## Questions for External AIs

Use these questions to keep external-model output comparable.

1. What are the best 3-state result labels for seniors under stress?
2. What exact definitions should govern `scam`, `not_scam`, and `unclear`?
3. What are the best top-level scam categories for a message-checking app?
4. What should the benchmark dataset schema be?
5. How should OCR quality be evaluated separately from model quality?
6. Which OCR engines should be benchmarked first, and why?
7. How should threshold calibration be done for a 2-pass classifier?
8. What should the app do when OCR fails locally?
9. Should first-time use be guest-only or require lightweight account creation?
10. Which premium or secondary features are worth exploring without weakening
    the core product?

## Working Research Output Format

When collecting research from external models or manual review, normalize their
answers into this structure:

1. recommendation
2. evidence or reasoning
3. risks
4. what must be tested
5. final decision status

This prevents generic, unstructured AI output from muddying the plan.

## Source Notes

- FTC impersonation guidance: https://consumer.ftc.gov/articles/how-avoid-government-impersonation-scam
- FTC government impersonation data: https://www.ftc.gov/news-events/news/press-releases/2024/06/ftc-data-shows-major-increases-cash-payments-government-impersonation-scammers
- CISA phishing guidance: https://www.cisa.gov/secure-our-world/recognize-and-report-phishing
- FBI elder fraud overview: https://www.fbi.gov/news/stories/elder-fraud-in-focus
- FBI elder fraud report summary: https://www.fbi.gov/contact-us/field-offices/cincinnati/news/fbi-elder-fraud-report-highlights-frauds-and-scams-targeting-older-americans
- NIH plain language guidance: https://www.nih.gov/institutes-nih/nih-office-director/office-communications-public-liaison/clear-communication/plain-language-nih
- CDC plain language guidance: https://www.cdc.gov/health-literacy/php/develop-materials/plain-language.html
- ML Kit text recognition: https://developers.google.com/ml-kit/vision/text-recognition/
- ML Kit Android guide: https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- Tesseract repository: https://github.com/tesseract-ocr/tesseract
- UCI SMS Spam Collection: https://archive.ics.uci.edu/dataset/228
- Mendeley SMS phishing dataset: https://data.mendeley.com/datasets/f45bkkt8pr/1
- Sting9 dataset: https://sting9.org/dataset
