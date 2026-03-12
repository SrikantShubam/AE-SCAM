# Architecture Decision

## Locked Direction

The v1 app will use:

- local OCR on-device
- cheap hosted first-pass classifier
- stronger hosted second-pass reasoning model for ambiguous cases
- policy layer for final user-facing output

## Explicitly Not Chosen

We are not choosing a large local classifier such as MobileBERT for shipped v1.

## Why

- target users are seniors, often on lower-end Android devices
- keeping app size small matters more than saving fractions of a cent on the
  first-pass classification path
- hosted first-pass models are cheap enough for freemium economics
- hosted models are easier to update as scam patterns evolve
- a stronger second-pass model gives better handling of novel or ambiguous scams

## Intended Free Flow

1. screenshot upload or pasted text
2. local OCR
3. OCR quality gate
4. cheap hosted first-pass model
5. if ambiguous, stronger hosted second-pass model
6. policy layer maps to:
   - `scam`
   - `unclear`
   - `not_scam`
7. UI shows short explanation and one pre-written next action

## Monetization Direction

- free core flow first
- ads only after free-usage threshold
- no ads inside active result flow
- premium for advanced capability, not basic safety

Likely premium features:

- more second-pass coverage
- cloud OCR fallback
- saved history
- caregiver/family features later

## Tradeoff Summary

### Pros

- smaller app
- easier model iteration
- better adaptation to new scam patterns
- lower engineering complexity than local classifier deployment

### Cons

- classification text may leave device when hosted
- network required for classification
- per-check inference cost exists

## Decision Status

Locked for current v1 planning unless benchmark data or economics prove this
direction wrong.
