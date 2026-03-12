import argparse
import csv
import json
from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "reference_transcript_manifest.csv"
DEFAULT_LLM_RESULTS = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "llm_reconciliation_gemini.jsonl"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "reference_transcript_manifest_resolved.csv"
DEFAULT_SUMMARY = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "reference_transcript_resolved_summary.csv"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Merge LLM reconciliation outputs into the reference manifest.")
    parser.add_argument("--reference-manifest", default=str(DEFAULT_REFERENCE_MANIFEST))
    parser.add_argument("--llm-results", default=str(DEFAULT_LLM_RESULTS))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--summary-output", default=str(DEFAULT_SUMMARY))
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def load_jsonl(path: Path) -> Dict[str, Dict[str, str]]:
    rows: Dict[str, Dict[str, str]] = {}
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            payload = json.loads(line)
            result = payload["result"]
            rows[result["sample_id"]] = {
                "provider": payload["provider"],
                "model": payload["model"],
                "reference_text": result.get("reference_text", ""),
                "manual_review": "true" if result.get("manual_review", False) else "false",
                "reason": result.get("reason", ""),
            }
    return rows


def write_csv(path: Path, rows: List[Dict[str, str]], fieldnames: List[str]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    llm_results = load_jsonl(Path(args.llm_results))

    with Path(args.reference_manifest).open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    resolved_rows: List[Dict[str, str]] = []
    summary: Dict[str, int] = {}
    for row in rows:
        merged = dict(row)
        llm = llm_results.get(row["sample_id"])
        if llm and row["reference_status"] == "llm_reconcile":
            merged["llm_provider"] = llm["provider"]
            merged["llm_model"] = llm["model"]
            merged["llm_reason"] = llm["reason"]
            if llm["manual_review"] == "false":
                merged["reference_status"] = "llm_resolved"
                merged["reference_text_candidate"] = llm["reference_text"]
            else:
                merged["reference_status"] = "manual_review"
        else:
            merged.setdefault("llm_provider", "")
            merged.setdefault("llm_model", "")
            merged.setdefault("llm_reason", "")
        summary[merged["reference_status"]] = summary.get(merged["reference_status"], 0) + 1
        resolved_rows.append(merged)

    fieldnames = list(resolved_rows[0].keys()) if resolved_rows else []
    write_csv(Path(args.output), resolved_rows, fieldnames)
    summary_rows = [{"reference_status": key, "sample_count": str(value)} for key, value in sorted(summary.items())]
    write_csv(Path(args.summary_output), summary_rows, ["reference_status", "sample_count"])
    print(f"Wrote resolved reference manifest to {args.output}")
    print(f"Wrote resolved summary to {args.summary_output}")


if __name__ == "__main__":
    main()
