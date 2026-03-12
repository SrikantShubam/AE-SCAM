# OCR Docker Runners

These containers exist only for reference-transcript generation and OCR research.
They are not the mobile shipping path.

## Planned engines

- `rapidocr`
- `tesseract`
- `easyocr`

## Typical usage

Build images from the repo root:

```powershell
docker build -t elderly-scam-rapidocr -f docker/ocr/rapidocr/Dockerfile .
docker build -t elderly-scam-tesseract -f docker/ocr/tesseract/Dockerfile .
docker build -t elderly-scam-easyocr -f docker/ocr/easyocr/Dockerfile .
```

Run synthetic batch predictions:

```powershell
docker run --rm -v ${PWD}:/workspace elderly-scam-rapidocr --source-group synthetic
docker run --rm -v ${PWD}:/workspace elderly-scam-tesseract --source-group synthetic
docker run --rm -v ${PWD}:/workspace elderly-scam-easyocr --source-group synthetic
```

## Why containers

- easy cleanup after research
- repeatable baseline generation
- no pollution of the main workstation environment
- easier to delete once the OCR decision is made
