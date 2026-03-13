import argparse
import csv
from pathlib import Path
from typing import Dict, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
REPORTS_DIR = ROOT / "data" / "benchmark" / "v0.1" / "reports"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Merge model output chunk CSVs into one canonical predictions file.")
    parser.add_argument("--model-name", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def read_rows(path: Path) -> List[Dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def write_rows(path: Path, rows: List[Dict[str, str]], fieldnames: List[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    candidates: List[Tuple[float, Path]] = []
    for path in REPORTS_DIR.glob("*.csv"):
        if path.resolve() == output_path.resolve():
            continue
        try:
            rows = read_rows(path)
        except Exception:
            continue
        if not rows or "model_name" not in rows[0]:
            continue
        if any(row.get("model_name") == args.model_name for row in rows):
            candidates.append((path.stat().st_mtime, path))

    candidates.sort(key=lambda item: item[0])
    merged: Dict[str, Dict[str, str]] = {}
    fieldnames: List[str] = []
    for _, path in candidates:
        rows = read_rows(path)
        if rows:
            for key in rows[0].keys():
                if key not in fieldnames:
                    fieldnames.append(key)
        for row in rows:
            if row.get("model_name") != args.model_name:
                continue
            sample_id = row.get("sample_id")
            if not sample_id:
                continue
            merged[sample_id] = row

    ordered_rows = [merged[sample_id] for sample_id in sorted(merged)]
    if not fieldnames:
        fieldnames = [
            "sample_id",
            "engine_name",
            "model_name",
            "source_group",
            "source_name",
            "image_path",
            "predicted_text",
            "latency_ms",
            "error",
        ]
    write_rows(output_path, ordered_rows, fieldnames)
    print(f"Merged {len(ordered_rows)} rows for {args.model_name} into {output_path}")


if __name__ == "__main__":
    main()
