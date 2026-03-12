# Scam App Planning

Date: 2026-03-08

## Core Product
- The app is a scam message checker for seniors and families.
- Users either paste suspicious text or upload a screenshot of a suspicious message.
- The app returns a simple result:
  - Red
  - Yellow
  - Green
- It also gives a short explanation of about 120 characters in simple language.
- The product should feel practical and reassuring, not like a generic AI assistant.

## Scope
- Do not handle calls in v1.
- Focus only on suspicious messages.
- Do not build a broad security suite in v1.
- English first.
- Hindi and other Indian languages later if the product shows traction or reaches break-even after roughly a quarter.

## User Experience
- Seniors should be able to use it without needing ChatGPT or technical knowledge.
- The UI should be calm, simple, and trust-first.
- Labels should avoid false certainty.
- Safer phrasing:
  - Likely scam
  - Be careful
  - Looks safe for now
- Avoid saying 100% scam unless there is deterministic evidence.

## Detection Flow
- OCR should happen locally first.
- The model should receive extracted text, not screenshots, for normal checks.
- Primary text model runs first.
- If confidence is below threshold, a stronger fallback model runs.
- Borderline cases should be logged for later review and workflow improvement.
- Logging should capture:
  - extracted text
  - model scores
  - explanation shown
  - final label
  - whether fallback/escalation happened
- LangSmith or equivalent can be used for analysis, but do not overbuild observability before v1 proves itself.

## Monetization
- Free tier: 3 to 5 checks per day.
- On the 4th check or after the free limit, show one interstitial ad before allowing extra checks.
- Premium pricing is TBD.
- Future premium feature idea:
  - family or loved-one alerts about scams the app blocked or flagged for the user
  - this is work in progress and should not delay v1

## Ads
- Do not interrupt an active panic moment mid-check.
- If using an interstitial, show it before an additional check, not during the result flow.
- Goal: better economics without making the product feel exploitative.

## Market Rollout
- Rollout order:
  1. India
  2. US
  3. LATAM
- Expansion should depend on actual user results, not assumptions.
- India is likely the strongest problem-market fit.
- US may have better monetization.
- LATAM is attractive because OCR is easier than Hindi and monetization may be better than India.

## Regional Configuration
Use Remote Config, not hard-coded values.

Per region, keep only these controls in v1:
- primary model
- fallback model
- free usage limit
- premium price

Recommended region buckets:
- India
- US
- LATAM
- ROW (Rest of World)

Do not overcomplicate beyond this early on.

## Business Logic Notes
- One interstitial paying for 10 searches may be possible in the US.
- That is probably too optimistic for India unless per-check model cost is extremely low.
- Local OCR plus text-only inference is what makes the freemium math viable.
- Keep fallback usage low so costs stay controlled.

## Product Principles
- Narrow product is a strength.
- The app is not a general anti-scam assistant.
- The app is a message checker with simple risk output.
- Trust matters more than model complexity.
- Explanation quality, OCR reliability, and calm UX are the main risks.

## Future Ideas
- Children/loved ones alerts in premium.
- SynthID detection later.
- Fake video or media authenticity checks much later.
- Do not let future ideas bloat v1.

## Competitor / Category Notes
- Recommended Play Store category: Tools.
- The gap is not generic security.
- The gap is a simple scam-message checker for non-technical users, especially seniors and families.

## Current Strategic Context
- Saraswati was the niche test.
- Hanuman Chalisa is the broad devotional test in an established market.
- This scam checker is the next major focus once Hanuman results are clearer.

## Reminder
- Buddies/testers are for smoke testing, clarity, and bug-finding.
- They are not market validation.
