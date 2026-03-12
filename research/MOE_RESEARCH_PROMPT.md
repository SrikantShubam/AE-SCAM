# MOE Research Prompt

Use this prompt with Gemini, Claude, Grok, or any other strong model. The goal
is to force a Mixture-of-Experts style answer instead of one generic opinion.

```text
Act as an MOE panel for a mobile scam-message checker app aimed at seniors and
caregivers.

MOE means you must answer as 6 expert roles, then produce one integrated final
recommendation:

1. Product strategist
2. Senior UX researcher
3. Mobile ML / OCR engineer
4. Trust and safety specialist
5. Growth / monetization analyst
6. Evaluation / benchmarking scientist

Context:
- The app helps users check suspicious messages.
- Primary input: screenshot.
- Secondary input: pasted text.
- V1 markets: India and US.
- V1 language: English only.
- The product should be extremely simple for seniors.
- Current output concept:
  - likely scam
  - be careful
  - looks safe for now
- The app should provide:
  - a category
  - a short explanation of about 120 characters
  - one clear next action
- OCR should be local first.
- Current model-routing idea:
  1. local OCR
  2. first-pass classifier
  3. if score is high enough => scam
  4. if score is low enough => not scam
  5. if score is in the middle => stronger second-pass model
- Current thresholds are placeholders only and must be calibrated later.
- We want a low-cost architecture.
- We may later add premium, family features, and fallback APIs, but v1 should
  remain narrow.

Your tasks:

Part A: Expert analysis
- Each expert must give:
  - top 5 recommendations
  - top 5 risks
  - what to keep
  - what to change

Part B: Resolve the following research questions
1. Are the 3 user-facing result labels good enough for seniors?
2. What alternative label sets should we test?
3. What exactly should count as scam, not scam, and unclear?
4. What are the top 5 scam categories for v1?
5. What should the benchmark dataset structure be?
6. How should OCR engines be evaluated?
7. How should model thresholds be calibrated?
8. What should happen when OCR fails?
9. Should first use require account creation or guest mode?
10. Which premium or extra features are worth researching without diluting the
    core?

Part C: Decision outputs
Produce these artifacts:
1. A recommended final v1 scope
2. A v1 vs v2 feature split
3. A benchmark schema table
4. An OCR evaluation scorecard template
5. A model evaluation scorecard template
6. A result-state copy-testing table with at least 10 candidate label sets
7. A threshold calibration methodology
8. A ranked list of research priorities for the next 2 weeks

Part D: Constraints
- Do not suggest a broad “AI assistant” product.
- Do not rely on vague advice.
- Do not assume raw confidence percentages should be shown to seniors.
- Avoid overbuilding infra before the core checker works.
- Highlight where more evidence is needed instead of pretending certainty.

Output format:
1. Executive summary
2. MOE expert sections
3. Final integrated recommendation
4. Tables for:
   - label-set testing
   - benchmark schema
   - OCR scorecard
   - model scorecard
   - v1 vs v2 split
5. Open questions

Be concrete, opinionated, and decision-oriented.
```

## Usage

Run this same prompt across multiple models, then compare:

- where they agree
- where they differ
- which recommendations are evidence-backed
- which suggestions are generic filler
