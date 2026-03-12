import argparse
import csv
from pathlib import Path
from time import perf_counter

import easyocr


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "easyocr_predictions.csv"
DEFAULT_MODEL_DIR = ROOT / "data" / "models" / "easyocr"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run EasyOCR on the OCR eval manifest.")
    parser.add_argument("--eval-manifest", default=str(DEFAULT_EVAL_MANIFEST))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--source-group", default="synthetic", choices=["synthetic", "stress", "all"])
    parser.add_argument("--model-dir", default=str(DEFAULT_MODEL_DIR))
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def main() -> None:
    args = parse_args()
    eval_manifest = Path(args.eval_manifest)
    output = Path(args.output)
    model_dir = Path(args.model_dir)
    ensure_dir(output.parent)
    ensure_dir(model_dir)

    with eval_manifest.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    if args.source_group != "all":
        rows = [row for row in rows if row["source_group"] == args.source_group]
    if args.limit is not None:
        rows = rows[: args.limit]

    reader = easyocr.Reader(["en"], gpu=False, model_storage_directory=str(model_dir), verbose=False)
    output_rows = []
    for row in rows:
        image_path = ROOT / row["image_path"]
        start = perf_counter()
        result = reader.readtext(str(image_path), detail=0, paragraph=True)
        elapsed_ms = (perf_counter() - start) * 1000.0
        predicted_text = " ".join(result) if result else ""
        output_rows.append(
            {
                "engine_name": "easyocr",
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
