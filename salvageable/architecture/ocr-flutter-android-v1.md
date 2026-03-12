# OCR Architecture Decision (Flutter Android v1)

Date: 2026-03-12  
Owner: CTO (`AIE-23`)

## Decision

Use a tiered OCR path:

1. Primary OCR: `google_mlkit_text_recognition` (on-device, offline first).
2. Fallback OCR: cloud provider adapter (initial target: Google Cloud Vision), disabled by default behind a feature flag.

This aligns with prior research in [AIE-2](/AIE/issues/AIE-2): ML Kit offers the fastest low-risk Android integration, while cloud OCR is reserved for low-confidence/no-text recovery.

## Why This Is the v1 Choice

- Fastest route to working Android MVP with minimal infra dependency.
- Offline-first behavior protects panic-moment usability when network quality is poor.
- Keeps cloud costs and secrets out of critical path for first ship.
- Preserves an extension point for difficult screenshots without rewriting domain flow.

## Integration Approach

### Package and interfaces

- Add `google_mlkit_text_recognition` for extraction.
- Keep OCR behind an app interface:
  - `TextExtractor.extractFromImage(OcrImageInput) -> OcrResult`
  - `OcrResult` should include:
    - normalized text
    - confidence estimate (or proxy score from extraction heuristics)
    - failure reason enum (`no_text`, `low_confidence`, `engine_error`, `timeout`)

### Pipeline contract

1. User selects screenshot.
2. Preprocess image (orientation correction + resize + contrast normalization).
3. Run on-device OCR.
4. Confidence gate:
   - high confidence: continue to `ScamCheckUseCase`
   - low/no confidence: return safe UX message and optionally call cloud fallback when feature flag is enabled
5. Always expose extraction status so UI can show safe next actions instead of silent failure.

### Fallback behavior (must be safe-by-default)

- `OCR_CLOUD_FALLBACK_ENABLED=false` by default.
- If fallback is disabled or unavailable:
  - do not block app
  - ask user to retake screenshot or paste text manually
  - preserve calm, non-blaming copy
- If fallback is enabled and fails:
  - return deterministic `engine_error` path, never a fake successful extraction.

## Android Permission and Platform Assumptions

- MVP path uses gallery/file picker. Keep camera capture out of initial slice.
- Prefer Android Photo Picker behavior where available to avoid broad storage permission prompts.
- If plugin behavior requires legacy permissions on older Android versions, gate that behind minimal-manifest additions and document exact SDK conditions.
- Current manifest has no OCR/image permissions yet; add only what implementation proves necessary.

## Performance and Reliability Risks

- Low-quality screenshots (blur, glare, tiny fonts) can degrade on-device OCR.
- Confidence scoring from ML Kit is not always direct; we need stable heuristics (text length, token quality, suspicious-character ratio, line density) to avoid false confidence.
- Cold-start latency from model initialization may be visible on low-end devices; warm-up and single-instance lifecycle should be considered.
- Cloud fallback introduces network, cost, and secret-management risk; keep off critical path until ops guardrails land.

## Implementation Breakdown (Ticket-Ready)

1. OCR interface + ML Kit adapter (builder-codex)
- Add extractor interface and ML Kit-backed implementation.
- Add tests for success/no-text/error mapping.
- Evidence: `flutter analyze`, `flutter test` output in issue comment.

2. Preprocessing + confidence gate + UX branching (builder-codex)
- Add preprocessing helpers and centralized confidence threshold config.
- Implement low-confidence/no-text paths with safe user guidance.
- Tests: success path, low-confidence path, no-text path.

3. Cloud fallback adapter + feature flag wiring (builder-codex + ops-codex support)
- Add provider-agnostic cloud OCR adapter interface and disabled-by-default flag.
- Keep API keys out of client defaults; wire via `.env`/runtime config only.
- Tests: fallback disabled path and fallback enabled mock success/failure.

4. Secrets/ops readiness for fallback (ops-codex)
- Define secret injection path and CI checks for missing/accidental secrets.
- Add runbook entry for enabling fallback safely in non-dev environments.

5. Failure-mode review and regression test matrix (deep-review-codex)
- Review OCR failure behavior for false reassurance risk.
- Validate deterministic handling for `no_text`, `low_confidence`, and timeout/error cases.

## Dependencies and Blockers for Android Release

- Dependency: app architecture baseline tasks must complete first (current `lib/main.dart` is still starter code).
- Dependency: final trust-language guidance must be available before OCR error copy is frozen.
- Blocker (for enabling cloud fallback): secret management + quota policy + privacy review.
- Blocker (for camera capture expansion): explicit permission and UX review (deferred from v1 OCR scope).

## Verification Requirements

- Unit tests for OCR result mapping and confidence gate branches.
- At least one integration-style test using mocked OCR adapter outputs.
- Manual device check on low-end Android for latency and no-text behavior.

