import csv
from pathlib import Path
from typing import Dict, Iterable, List


ROOT = Path(__file__).resolve().parents[1]
RENDER_MANIFEST = ROOT / "data" / "interim" / "manifests" / "synthetic_render_manifest.csv"
SEED_POOL = ROOT / "data" / "interim" / "normalized" / "seed_pool_v0_1.csv"
OCR_EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
OCR_EVAL_SUMMARY = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "ocr_eval_selection_summary.csv"
PHISH_IRIS_SUBSET = ROOT / "data" / "raw" / "stress" / "phish_iris" / "subset"
CIRCL_DIR = ROOT / "data" / "raw" / "stress" / "circl_phishing_dataset_01"


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def load_seed_pool() -> Dict[str, Dict[str, str]]:
    with SEED_POOL.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    return {row["seed_id"]: row for row in rows}


def synthetic_rows(seed_pool: Dict[str, Dict[str, str]]) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    with RENDER_MANIFEST.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            seed = seed_pool[row["seed_id"]]
            rows.append(
                {
                    "sample_id": row["render_id"],
                    "source_group": "synthetic",
                    "source_name": row["source_name"],
                    "image_path": row["output_path"],
                    "has_gold_text": "true",
                    "gold_text": seed["message_text_gold"],
                    "ground_truth_label": row["ground_truth_label"],
                    "market": row["market"],
                    "channel": row["channel"],
                    "quality_tier": row["quality_tier"],
                    "evaluation_slice": f"{row['market']}_{row['channel']}_{row['quality_tier']}",
                }
            )
    return rows


def relative_paths(base_dir: Path, glob_pattern: str) -> Iterable[Path]:
    for path in sorted(base_dir.rglob(glob_pattern)):
        if path.is_file():
            yield path.relative_to(ROOT)


def stress_rows() -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for path in relative_paths(PHISH_IRIS_SUBSET, "*.png"):
        rows.append(
            {
                "sample_id": f"phish_iris_{path.stem}",
                "source_group": "stress",
                "source_name": "phish_iris",
                "image_path": str(path).replace("\\", "/"),
                "has_gold_text": "false",
                "gold_text": "",
                "ground_truth_label": "",
                "market": "unknown",
                "channel": "unknown",
                "quality_tier": "stress",
                "evaluation_slice": "stress_phish_iris",
            }
        )
    for path in relative_paths(CIRCL_DIR, "*.png"):
        rows.append(
            {
                "sample_id": f"circl_{path.stem}",
                "source_group": "stress",
                "source_name": "circl",
                "image_path": str(path).replace("\\", "/"),
                "has_gold_text": "false",
                "gold_text": "",
                "ground_truth_label": "",
                "market": "unknown",
                "channel": "unknown",
                "quality_tier": "stress",
                "evaluation_slice": "stress_circl",
            }
        )
    return rows


def write_csv(path: Path, rows: List[Dict[str, str]], fieldnames: List[str]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_summary(path: Path, rows: List[Dict[str, str]]) -> None:
    counts: Dict[str, int] = {}
    for row in rows:
        key = row["evaluation_slice"]
        counts[key] = counts.get(key, 0) + 1
    summary_rows = [{"evaluation_slice": key, "sample_count": str(value)} for key, value in sorted(counts.items())]
    write_csv(path, summary_rows, ["evaluation_slice", "sample_count"])


def main() -> None:
    seed_pool = load_seed_pool()
    rows = synthetic_rows(seed_pool) + stress_rows()
    fieldnames = [
        "sample_id",
        "source_group",
        "source_name",
        "image_path",
        "has_gold_text",
        "gold_text",
        "ground_truth_label",
        "market",
        "channel",
        "quality_tier",
        "evaluation_slice",
    ]
    write_csv(OCR_EVAL_MANIFEST, rows, fieldnames)
    write_summary(OCR_EVAL_SUMMARY, rows)
    print(f"Wrote {len(rows)} OCR eval rows to {OCR_EVAL_MANIFEST}")
    print(f"Wrote slice summary to {OCR_EVAL_SUMMARY}")


if __name__ == "__main__":
    main()
