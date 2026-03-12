# Model Routing and Threshold Research

## Objective

Define how the first-pass / second-pass classifier should work without locking
premature thresholds.

## 1. Current routing idea

The current proposal is:

1. local OCR
2. first classifier pass
3. if score is high enough, return `Scam`
4. if score is low enough, return `Not scam`
5. if score is in the middle band, run a stronger second pass

This is a sound v1 architecture.

## 2. Threshold policy

The thresholds `>85`, `<45`, `45-84` are acceptable placeholders, but they are
not product truth yet.

### Calibration rule

Do not choose thresholds by intuition.

Choose them from:

- benchmark confusion matrix
- per-category performance
- cost per routed item
- tolerance for false reassurance

### What to calibrate

- first-pass scam threshold
- first-pass safe threshold
- second-pass trigger band
- when to route to `Unclear` even after second pass

## 3. Recommended output layers

Separate these clearly:

- internal model score
- policy score after rules
- user-facing label

This matters because the UI should not mirror raw model uncertainty 1:1.

## 4. Recommended decision stack

1. OCR text quality gate
2. deterministic rule signals
3. primary classifier
4. fallback classifier for ambiguous cases
5. policy layer that decides:
   - `Likely scam`
   - `Be careful`
   - `Looks safe for now`

## 5. Which models should be compared

For text-only classification, compare at least:

- one low-cost fast model
- one stronger fallback model
- one open or vendor-flexible candidate

The exact vendor should be chosen by benchmark, not brand preference.

## 6. What to optimize

Optimize for:

- accuracy on older-adult-targeted scam patterns
- low cost per successful check
- fast response on first pass
- controlled second-pass rate
- reproducible explanations and outputs

## 7. Recommendation

Keep the routing design. Delay final threshold lock until:

- OCR benchmark exists
- labeled message benchmark exists
- first-pass and second-pass models have been tested on the same set

This is an inference from product-risk management, not a rule from an external
source.
