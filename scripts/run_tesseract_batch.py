import argparse
import csv
from pathlib import Path
from time import perf_counter

import cv2
import pytesseract


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "tesseract_predictions.csv"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Tesseract OCR on the OCR eval manifest.")
    parser.add_argument("--eval-manifest", default=str(DEFAULT_EVAL_MANIFEST))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--source-group", default="synthetic", choices=["synthetic", "stress", "all"])
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def preprocess(image_path: Path):
    image = cv2.imread(str(image_path))
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]


def main() -> None:
    args = parse_args()
    eval_manifest = Path(args.eval_manifest)
    output = Path(args.output)
    ensure_dir(output.parent)

    with eval_manifest.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    if args.source_group != "all":
        rows = [row for row in rows if row["source_group"] == args.source_group]
    if args.limit is not None:
        rows = rows[: args.limit]

    output_rows = []
    for row in rows:
        image_path = ROOT / row["image_path"]
        processed = preprocess(image_path)
        start = perf_counter()
        predicted_text = pytesseract.image_to_string(processed, config="--oem 3 --psm 6")
        elapsed_ms = (perf_counter() - start) * 1000.0
        output_rows.append(
            {
                "engine_name": "tesseract",
                "sample_id": row["sample_id"],
                "image_path": row["image_path"],
                "predicted_text": " ".join(predicted_text.split()),
                "latency_ms": f"{elapsed_ms:.2f}",
            }
        )

    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["engine_name", "sample_id", "image_path", "predicted_text", "latency_ms"])
        writer.writeheader()
        writer.writerows(output_rows)
    print(f"Wrote {len(output_rows)} predictions to {output}")


if __name__ == "__main__":
    main()
