# V1 Plan

## Product Thesis

Build a calm, fast, elderly-friendly mobile app that helps a user check whether
a suspicious message is likely a scam and tells them the next safe action.

## Primary User

- Older adults who receive suspicious texts, WhatsApp messages, emails, or popups
- Family members or caregivers who help them verify suspicious content

## Core Outcome

In under 60 seconds, the user should be able to:

1. add a screenshot or paste text
2. get a clear risk assessment
3. see a recommended next action
4. avoid false reassurance

## Locked Technical Direction

The current architecture decision is:

- local OCR on-device
- cheap hosted first-pass classifier for normal checks
- stronger hosted second-pass reasoning model for ambiguous cases
- policy layer decides final user-facing result

We are explicitly not planning to ship a large local classifier in v1. The app
must stay lightweight for lower-end Android devices used by seniors.

## Non-Negotiables

- Large touch targets and plain-language copy
- Offline-capable first step whenever practical
- Deterministic failure states
- No hidden model confidence theater
- No fake certainty when evidence is weak

## Non-Goals for V1

- Full multi-agent orchestration platform
- Generic chatbot persona layer
- Camera capture as a dependency for first release
- Complex user accounts or social features
- Browser automation or desktop control
- Large on-device classification models that materially bloat the app

## V1 Product Slice

The first real version should do exactly this:

- Import screenshot from gallery or file picker
- Extract text from image using on-device OCR
- Allow manual text paste as fallback
- Run a two-tier hosted scam-check pipeline against extracted or pasted text
- Return a result with:
  - result state
  - short explanation
  - next safe action
  - category detail when relevant
- Keep guest mode available for first use
- Add lightweight result history only after the core flow is proven

## Output Contract

Every analysis result should return:

- `result_state`: `scam`, `unclear`, `not_scam`
- `short_explanation`: user-facing reason capped to roughly 120 characters
- `recommended_action`: exact next step
- `category`: top-level scam category when applicable

Raw confidence scores are internal only. They should not be shown to the user.

## Architecture Direction

Base the rebuild on a simple pipeline, not an agent swarm:

1. `InputCapture`
2. `TextExtraction`
3. `OcrQualityGate`
4. `PrimaryClassifierAdapter`
5. `SecondPassReasoningAdapter`
6. `PolicyDecisionLayer`
7. `SafetyCopyRenderer`
8. `LocalHistory`

Experimental or agentic behavior can sit behind adapters later, but the v1
path should remain testable without any multi-agent runtime.

### Intended inference flow

1. user uploads screenshot or pastes text
2. OCR runs locally
3. if OCR quality is too low:
   - prompt for paste text or clearer screenshot
4. cheap hosted first-pass model classifies normal cases
5. ambiguous or novel cases route to stronger hosted reasoning model
6. policy layer maps output to:
   - `scam`
   - `unclear`
   - `not_scam`
7. UI shows explanation plus pre-written next action

## Phase Plan

### Phase 0: Reset and Design Freeze

Goals:

- freeze the actual v1 use case
- define the result contract
- define safety language rules
- decide whether the app is mobile-only for v1

Exit criteria:

- one approved PRD
- one approved domain glossary
- one approved UX copy baseline

### Phase 1: Foundation Rebuild

Goals:

- create a clean Flutter project from scratch
- establish feature-first app structure
- add linting, formatting, test harness, and CI
- add environment and feature-flag wiring
- keep the mobile binary lightweight

Deliverables:

- new Flutter shell
- app theme and accessibility baseline
- testable domain module boundaries

Exit criteria:

- app boots
- CI passes
- smoke widget tests exist

### Phase 2: OCR and Input

Goals:

- implement screenshot/file import
- implement on-device OCR behind an interface
- add confidence heuristics and failure states
- support manual text paste as a first-class fallback

Dependencies:

- reuse `salvageable/architecture/ocr-flutter-android-v1.md`

Exit criteria:

- OCR success path works on target Android devices
- no-text and low-confidence states are explicit
- tests cover result mapping

### Phase 3: Scam Intelligence Engine

Goals:

- build the hosted two-tier classification path
- keep first-pass cheap and conservative
- keep second-pass stronger and reasoning-oriented
- create a stable analysis schema independent of the model vendor

Recommended order:

1. heuristic signals
2. hosted first-pass classifier adapter
3. hosted second-pass reasoning adapter
4. policy decision layer

Exit criteria:

- first-pass handles obvious cases cheaply
- second-pass handles ambiguous cases safely
- model path can be disabled without breaking the app
- result quality is reviewable from saved fixtures

### Phase 4: Safety UX

Goals:

- design elderly-friendly flows
- express risk and uncertainty clearly
- provide plain-language next steps
- add safe OCR-failure recovery paths
- define when save/history prompts appear without harming trust

Exit criteria:

- one-tap actions for common safe steps
- no copy that sounds blaming or patronizing
- all major error states have humane UX

### Phase 5: Human Validation

Goals:

- test with real scam examples
- test with caregivers and older users
- review false positive and false negative cases
- tune thresholds and copy

Exit criteria:

- benchmark set with labeled examples
- failure taxonomy documented
- top confusion cases have mitigation plans

### Phase 6: Release Readiness

Goals:

- harden analytics, privacy, crash reporting, and settings
- create release checklist
- prepare Play Store assets and support docs
- finalize freemium, ad, and premium gating without harming core trust

Exit criteria:

- v1 launch checklist complete
- rollback and feature-flag plan exists
- app can ship without experimental systems enabled

## Workstreams

### Product

- PRD
- user journeys
- trust language
- abuse and misuse cases

### App

- Flutter shell
- state management
- navigation
- local storage

### Intelligence

- OCR adapter
- scam heuristics
- hosted first-pass model provider abstraction
- hosted second-pass reasoning provider abstraction
- evaluation fixtures

### Safety

- calm UX copy
- deterministic failures
- escalation guidance
- family/caregiver handoff

### Ops

- provider config
- secret handling
- CI
- release checklist
- cost monitoring
- market-specific monetization controls

### Monetization

- free usage policy
- ad gating after free usage threshold
- premium capabilities
- per-market economics review

## Loose Cannons

These are worth exploring, but must stay outside the critical path until the
core app works.

### Experiment A: LiteLLM-backed model routing

Why:

- useful if we want vendor flexibility
- useful for evaluating multiple hosted classifiers and reasoning models

Source to reuse:

- `salvageable/infra/`

Do not allow this to block:

- OCR
- rules engine
- base UX

### Experiment B: Family mode

Idea:

- a caregiver receives a summary or suggested next steps after a check

Risk:

- privacy complexity
- account complexity

Gate:

- only after solo-user flow is solid

### Experiment C: Call-time assist

Idea:

- real-time prompts during a suspicious phone call

Risk:

- much larger technical and permissions surface

Gate:

- not before v2

### Experiment D: Agentic decomposition

Idea:

- separate OCR, signal detection, explanation, and advice into specialized agents

Risk:

- more moving parts than value at v1 stage

Gate:

- only after we have a stable single-pipeline baseline to compare against

## Kill Criteria

If any of these remain unresolved, do not ship v1:

- OCR fails too often on normal screenshots
- explanations are not understandable to older adults
- results overstate certainty
- hosted model path cannot be tested reproducibly
- caregivers cannot understand recommended next steps
- app size or performance makes install/use painful on target devices
- free-tier economics collapse without intrusive ads

## Suggested Build Order

1. write PRD and copy rules
2. rebuild clean Flutter app
3. implement input + OCR + manual paste
4. implement hosted first-pass classification
5. implement hosted second-pass reasoning for ambiguous cases
6. implement result screen and safe next actions
7. run validation set and tune thresholds
8. define freemium, ad, and premium controls
9. prepare release checklist

## First Concrete Milestones

### Milestone 1: Skeleton

- clean Flutter app
- route structure
- theme and accessibility baseline

### Milestone 2: OCR

- screenshot import
- on-device extraction
- no-text handling

### Milestone 3: Analysis

- scam signal rules
- cheap hosted first-pass
- stronger hosted second-pass
- explanation rendering
- recommended actions

### Milestone 4: Trust

- review with real examples
- copy revisions
- false-confidence reduction

### Milestone 5: Ship Candidate

- settings
- local history
- ad and premium gating
- release hardening

## Repo Rules for the Rebuild

- keep product code out of `salvageable/`
- only move a salvageable asset back into the main build if it is actively used
- prefer simple, testable modules over orchestration frameworks
- every experimental feature must have a disable path
