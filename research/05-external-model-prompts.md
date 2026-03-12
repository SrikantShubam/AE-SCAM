# External Model Prompts

## Note

I cannot directly call Grok, Gemini, or Claude from this repo session. These
prompts are designed so you can use those models deliberately instead of asking
vague research questions.

## 1. Prompt: result-state copy testing

```text
You are helping define user-facing result labels for a senior-friendly scam
message checker app.

Context:
- Audience: adults 60+, plus caregivers
- Input: screenshot of a suspicious message or pasted text
- Output must be simple, respectful, non-technical
- We need 3 result states:
  1) likely scam
  2) uncertain / caution
  3) looks safe for now
- We must avoid fake certainty, but older adults may dislike vague labels

Task:
1. Propose 12 sets of 3 labels each.
2. Rank them for senior comprehension, low ambiguity, and low panic.
3. For the top 5 sets, explain tradeoffs.
4. For each top set, propose a matching one-line CTA for each state.
5. Reject any labels that sound patronizing, legalistic, or overly technical.

Output as a table.
```

## 2. Prompt: scam taxonomy for seniors

```text
You are designing the first category taxonomy for a scam-detection app aimed at
older adults in India and the US.

Task:
1. Propose the best top-level category set for v1.
2. Optimize for message-based scams, not all cybercrime.
3. Map each category to common examples seen by older adults.
4. Explain which categories should be merged for product simplicity.
5. Produce:
   - 5-category v1 taxonomy
   - 8-category internal taxonomy
   - examples
   - risks of confusion between categories
```

## 3. Prompt: dataset benchmark design

```text
You are helping build a benchmark dataset for a mobile app that detects scam
messages from screenshots or pasted text.

Constraints:
- markets: India and US
- language: English only in v1
- two inputs: screenshot and pasted text
- output labels: scam, not_scam, unclear
- we need to evaluate OCR and classification separately

Task:
1. Propose a benchmark schema.
2. Define required columns for screenshot and text items.
3. Define train / validation / hard-case / regression splits.
4. Define how to measure OCR quality and model quality separately.
5. Suggest minimum sample counts per category for an MVP benchmark.
6. Suggest how to avoid leakage and overfitting.
```

## 4. Prompt: OCR selection framework

```text
You are comparing local OCR engines for an Android app that extracts text from
suspicious screenshots.

Candidates may include ML Kit, Tesseract, PaddleOCR, or other mobile-usable OCR.

Task:
1. Produce a decision matrix for OCR selection.
2. Rank candidates by:
   - on-device latency
   - text accuracy on screenshots
   - low-end Android suitability
   - app-size impact
   - implementation complexity
3. Recommend a benchmark methodology.
4. Explain failure modes specific to scam screenshots.
5. Recommend what should be logged when OCR fails.
```

## 5. Prompt: threshold calibration

```text
You are calibrating a 2-pass classifier for a scam detection app.

Current placeholder logic:
- if scam score > 85, return likely scam
- if scam score < 45, return looks safe for now
- if score is 45-84, run a stronger second-pass model

Task:
1. Critique this routing design.
2. Propose a calibration methodology using a labeled benchmark.
3. Explain how to optimize for low false reassurance without destroying trust
   via false alarms.
4. Define what metrics should decide threshold placement.
5. Define when the final output should be `unclear` even after second pass.
```
