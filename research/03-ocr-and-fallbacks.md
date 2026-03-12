# OCR and Fallback Research

## Objective

Choose an OCR path that is fast and cheap enough for v1, then define what
happens when OCR fails.

## 1. OCR direction

For v1, the current best default remains on-device OCR on Android.

### Best starting candidate

- Google ML Kit Text Recognition v2

### Why

- Android support is mature
- on-device flow aligns with the cost goal
- bundled vs unbundled tradeoff gives flexibility
- built for mobile inference, not server OCR

### Other candidates worth benchmarking

- Tesseract
- PaddleOCR mobile-oriented variants

### Recommendation

Do not debate OCR in the abstract. Benchmark all candidates on the same internal
dataset with the same scoring rubric.

## 2. OCR evaluation rubric

Measure:

- extraction accuracy against human-corrected gold text
- latency on target low-end Android devices
- app-size impact
- memory and initialization cost
- failure behavior on blurry, compressed, or noisy screenshots

### Primary decision metrics

1. character / word accuracy on scam-relevant spans
2. speed on low-end Android
3. reliability on messy screenshots
4. implementation complexity

## 3. OCR failure policy

### When OCR fails locally

If OCR returns no text or clearly low-quality text:

1. show a calm failure state
2. offer `Paste text instead`
3. offer `Try another screenshot`

### Premium fallback

Your idea is valid:

- premium users can optionally trigger a cloud OCR or vision fallback
- log why local OCR failed
- preserve the screenshot for evaluation if the user consents and privacy policy
  covers it

### Important constraint

Cloud OCR must not silently replace local OCR in v1. It should be an explicit
fallback path because it changes cost, privacy, and latency.

## 4. Logging on OCR failures

For evaluation, log:

- device class
- image dimensions
- image-quality bucket
- OCR engine name and version
- extracted text length
- quality heuristics
- whether cloud fallback was used
- whether the user switched to paste/manual input

Do not keep raw screenshots unless privacy, consent, retention, and security are
explicitly handled.

## 5. Recommendation

Use ML Kit as the first implementation target, but keep the benchmark open until
you compare it against at least one alternate OCR engine on your own dataset.

## Source Notes

- ML Kit text recognition v2 overview: https://developers.google.com/ml-kit/vision/text-recognition/
- ML Kit Android text recognition guide: https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- Tesseract repository: https://github.com/tesseract-ocr/tesseract
