# RapidOCR Baseline v0.1

## Scope

- Engine: `rapidocr_onnxruntime`
- Synthetic scored set: `80` rendered screenshots
- Stress smoke set: `20` images from Phish-IRIS subset

## Main output files

- `rapidocr_predictions_v0_1.csv`
- `rapidocr_predictions_v0_1_ocr_detail.csv`
- `rapidocr_predictions_v0_1_ocr_summary.csv`
- `rapidocr_stress_smoke.csv`

## Baseline observations

- The engine is usable as a local OCR baseline in this environment.
- It reads both message body text and surrounding UI chrome.
- Raw CER and WER against body-only gold are pessimistic because the rendered
  screenshots include sender names, timestamps, and app headers.
- Body token recall and scam-span recall are the more useful first-pass metrics
  for this benchmark shape.

## Synthetic summary

| Slice | Count | Avg CER | Avg Body Token Recall | Avg Scam Span Recall |
| --- | ---: | ---: | ---: | ---: |
| india_sms_clean | 30 | 0.401988 | 0.973094 | 0.861111 |
| india_sms_medium | 5 | 0.332983 | 0.961039 | 0.966667 |
| india_whatsapp_medium | 5 | 0.591286 | 1.000000 | 1.000000 |
| us_email_hard | 10 | 0.775090 | 0.913842 | 0.850000 |
| us_whatsapp_hard | 10 | 0.305815 | 0.888761 | 0.850000 |
| us_whatsapp_medium | 20 | 0.498241 | 0.906959 | 0.925000 |

## Latency

- Synthetic batch average latency: `5104.19 ms`
- Synthetic batch min latency: `2968.16 ms`
- Synthetic batch max latency: `10050.22 ms`

This is too slow to treat as a shipping target, but acceptable as a local
desktop benchmark baseline.

## Failure patterns seen in worst samples

- long promotional scam messages with dense numeric spans
- email-style hard screenshots with more chrome and more layout noise
- headers and timestamps included in output
- some critical spans lost or reformatted, especially phone numbers and money
  amounts

## Practical interpretation

- RapidOCR is good enough to validate the benchmark harness.
- RapidOCR is not good enough on its own to decide the mobile OCR path.
- ML Kit still needs to be tested because shipping performance and integration
  constraints matter more than this desktop baseline.
- Span-level evaluation should remain a primary metric because overall string
  similarity underestimates usable OCR on these screenshots.
