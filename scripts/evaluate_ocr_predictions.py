import argparse
import csv
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
DEFAULT_REPORT_DIR = ROOT / "data" / "benchmark" / "v0.1" / "reports"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Score OCR predictions against gold text.")
    parser.add_argument("--predictions", required=True, help="CSV with sample_id,predicted_text,engine_name")
    parser.add_argument("--eval-manifest", default=str(DEFAULT_EVAL_MANIFEST))
    parser.add_argument("--report-dir", default=str(DEFAULT_REPORT_DIR))
    return parser.parse_args()


def normalize_text(text: str) -> str:
    return " ".join(text.replace("\r", " ").replace("\n", " ").split()).strip()


def levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    previous = list(range(len(b) + 1))
    for i, char_a in enumerate(a, start=1):
        current = [i]
        for j, char_b in enumerate(b, start=1):
            insert_cost = current[j - 1] + 1
            delete_cost = previous[j] + 1
            replace_cost = previous[j - 1] + (0 if char_a == char_b else 1)
            current.append(min(insert_cost, delete_cost, replace_cost))
        previous = current
    return previous[-1]


def cer(gold: str, predicted: str) -> float:
    if not gold and not predicted:
        return 0.0
    return levenshtein(gold, predicted) / max(len(gold), 1)


def wer(gold: str, predicted: str) -> float:
    gold_words = gold.split()
    predicted_words = predicted.split()
    if not gold_words and not predicted_words:
        return 0.0
    return levenshtein(" ".join(gold_words), " ".join(predicted_words)) / max(len(" ".join(gold_words)), 1)


def token_set(text: str) -> Set[str]:
    return {token for token in re.findall(r"[a-z0-9]+", text.lower()) if token}


def token_recall(gold: str, predicted: str) -> float:
    gold_tokens = token_set(gold)
    if not gold_tokens:
        return 1.0
    predicted_tokens = token_set(predicted)
    matched = len(gold_tokens & predicted_tokens)
    return matched / len(gold_tokens)


def extract_scam_spans(text: str) -> Set[str]:
    patterns = [
        r"https?://\S+",
        r"www\.\S+",
        r"\b\d{4,8}\b",
        r"\b\d{10,12}\b",
        r"(?:rs\.?|inr|\$)\s?\d+(?:[.,]\d+)?",
        r"\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b",
    ]
    lowered = text.lower()
    spans: Set[str] = set()
    for pattern in patterns:
        spans.update(match.group(0) for match in re.finditer(pattern, lowered))
    return spans


def scam_span_recall(gold: str, predicted: str) -> float:
    gold_spans = extract_scam_spans(gold)
    if not gold_spans:
        return 1.0
    predicted_spans = extract_scam_spans(predicted)
    matched = len(gold_spans & predicted_spans)
    return matched / len(gold_spans)


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def load_eval_manifest(path: Path) -> Dict[str, Dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return {row["sample_id"]: row for row in csv.DictReader(handle)}


def write_csv(path: Path, rows: List[Dict[str, str]], fieldnames: List[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    predictions_path = Path(args.predictions)
    eval_manifest = load_eval_manifest(Path(args.eval_manifest))
    report_dir = Path(args.report_dir)
    ensure_dir(report_dir)

    with predictions_path.open("r", encoding="utf-8", newline="") as handle:
        predictions = list(csv.DictReader(handle))

    detail_rows: List[Dict[str, str]] = []
    slice_metrics: Dict[Tuple[str, str], Dict[str, float]] = {}

    for row in predictions:
        sample = eval_manifest.get(row["sample_id"])
        if sample is None or sample["has_gold_text"] != "true":
            continue
        gold = normalize_text(sample["gold_text"])
        predicted = normalize_text(row.get("predicted_text", ""))
        char_error = cer(gold, predicted)
        word_error = wer(gold, predicted)
        body_token_recall = token_recall(gold, predicted)
        span_recall = scam_span_recall(gold, predicted)
        key = (row["engine_name"], sample["evaluation_slice"])
        metrics = slice_metrics.setdefault(
            key,
            {"count": 0.0, "cer_sum": 0.0, "wer_sum": 0.0, "token_recall_sum": 0.0, "span_recall_sum": 0.0},
        )
        metrics["count"] += 1
        metrics["cer_sum"] += char_error
        metrics["wer_sum"] += word_error
        metrics["token_recall_sum"] += body_token_recall
        metrics["span_recall_sum"] += span_recall
        detail_rows.append(
            {
                "engine_name": row["engine_name"],
                "sample_id": row["sample_id"],
                "evaluation_slice": sample["evaluation_slice"],
                "gold_text_normalized": gold,
                "predicted_text_normalized": predicted,
                "cer": f"{char_error:.6f}",
                "wer": f"{word_error:.6f}",
                "body_token_recall": f"{body_token_recall:.6f}",
                "scam_span_recall": f"{span_recall:.6f}",
            }
        )

    summary_rows: List[Dict[str, str]] = []
    for (engine_name, evaluation_slice), metrics in sorted(slice_metrics.items()):
        count = metrics["count"] or 1.0
        summary_rows.append(
            {
                "engine_name": engine_name,
                "evaluation_slice": evaluation_slice,
                "sample_count": str(int(metrics["count"])),
                "avg_cer": f"{metrics['cer_sum'] / count:.6f}",
                "avg_wer": f"{metrics['wer_sum'] / count:.6f}",
                "avg_body_token_recall": f"{metrics['token_recall_sum'] / count:.6f}",
                "avg_scam_span_recall": f"{metrics['span_recall_sum'] / count:.6f}",
            }
        )

    stem = predictions_path.stem
    detail_path = report_dir / f"{stem}_ocr_detail.csv"
    summary_path = report_dir / f"{stem}_ocr_summary.csv"
    write_csv(
        detail_path,
        detail_rows,
        [
            "engine_name",
            "sample_id",
            "evaluation_slice",
            "gold_text_normalized",
            "predicted_text_normalized",
            "cer",
            "wer",
            "body_token_recall",
            "scam_span_recall",
        ],
    )
    write_csv(
        summary_path,
        summary_rows,
        [
            "engine_name",
            "evaluation_slice",
            "sample_count",
            "avg_cer",
            "avg_wer",
            "avg_body_token_recall",
            "avg_scam_span_recall",
        ],
    )
    print(f"Wrote OCR detail report to {detail_path}")
    print(f"Wrote OCR summary report to {summary_path}")


if __name__ == "__main__":
    main()
