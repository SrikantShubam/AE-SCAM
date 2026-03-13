import argparse
import csv
from pathlib import Path
from time import perf_counter


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "rapidocr_predictions.csv"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run RapidOCR on the OCR eval manifest.")
    parser.add_argument("--eval-manifest", default=str(DEFAULT_EVAL_MANIFEST))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--source-group", default="synthetic", choices=["synthetic", "stress", "all"])
    parser.add_argument("--append", action="store_true")
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def main() -> None:
    try:
        from rapidocr_onnxruntime import RapidOCR
    except ImportError as exc:
        raise SystemExit("rapidocr_onnxruntime is not installed. Install it before running this script.") from exc

    args = parse_args()
    eval_manifest = Path(args.eval_manifest)
    output = Path(args.output)
    ensure_dir(output.parent)

    with eval_manifest.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    if args.source_group != "all":
        rows = [row for row in rows if row["source_group"] == args.source_group]
    if args.offset:
        rows = rows[args.offset :]
    if args.limit is not None:
        rows = rows[: args.limit]

    engine = RapidOCR()
    output_rows = []
    for row in rows:
        image_path = ROOT / row["image_path"]
        start = perf_counter()
        result, _ = engine(str(image_path))
        elapsed_ms = (perf_counter() - start) * 1000.0
        predicted_text = " ".join(item[1] for item in result) if result else ""
        output_rows.append(
            {
                "engine_name": "rapidocr_onnxruntime",
                "sample_id": row["sample_id"],
                "image_path": row["image_path"],
                "predicted_text": predicted_text,
                "latency_ms": f"{elapsed_ms:.2f}",
            }
        )

    mode = "a" if args.append and output.exists() else "w"
    with output.open(mode, encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["engine_name", "sample_id", "image_path", "predicted_text", "latency_ms"]
        )
        if mode == "w":
            writer.writeheader()
        writer.writerows(output_rows)
    print(f"Wrote {len(output_rows)} predictions to {output}")


if __name__ == "__main__":
    main()
