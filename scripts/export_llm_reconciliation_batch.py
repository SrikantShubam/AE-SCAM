import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "reference_transcript_manifest.csv"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "llm_reconciliation_batch.jsonl"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export OCR disagreement cases for LLM reconciliation.")
    parser.add_argument("--reference-manifest", default=str(DEFAULT_REFERENCE_MANIFEST))
    parser.add_argument("--prediction-files", nargs="+", required=True)
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def load_predictions(paths: List[Path]) -> Dict[str, List[Dict[str, str]]]:
    grouped: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    for path in paths:
        with path.open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                grouped[row["sample_id"]].append(
                    {
                        "engine_name": row["engine_name"],
                        "predicted_text": row.get("predicted_text", ""),
                        "source_file": path.name,
                    }
                )
    return grouped


def main() -> None:
    args = parse_args()
    reference_manifest = Path(args.reference_manifest)
    predictions = load_predictions([Path(item) for item in args.prediction_files])
    output = Path(args.output)
    ensure_dir(output.parent)

    with reference_manifest.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    export_rows = []
    for row in rows:
        if row["reference_status"] != "llm_reconcile":
            continue
        export_rows.append(
            {
                "sample_id": row["sample_id"],
                "image_path": row["image_path"],
                "evaluation_slice": row["evaluation_slice"],
                "ocr_predictions": predictions.get(row["sample_id"], []),
                "instruction": (
                    "Reconcile these OCR outputs into one best-effort transcript. "
                    "Preserve visible scam-relevant spans such as URLs, phone numbers, "
                    "amounts, OTP-like codes, and email addresses whenever supported by the evidence. "
                    "If the evidence is too conflicting, mark manual_review as true."
                ),
            }
        )

    with output.open("w", encoding="utf-8") as handle:
        for row in export_rows:
            handle.write(json.dumps(row, ensure_ascii=True) + "\n")
    print(f"Wrote {len(export_rows)} LLM reconciliation rows to {output}")


if __name__ == "__main__":
    main()
