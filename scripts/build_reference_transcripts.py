import argparse
import csv
import difflib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "reference_transcript_manifest.csv"
DEFAULT_SUMMARY = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "reference_transcript_summary.csv"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build reference transcript candidates from multiple OCR outputs.")
    parser.add_argument("--eval-manifest", default=str(DEFAULT_EVAL_MANIFEST))
    parser.add_argument("--prediction-files", nargs="+", required=True)
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--summary-output", default=str(DEFAULT_SUMMARY))
    parser.add_argument("--auto-accept-min-similarity", type=float, default=0.90)
    parser.add_argument("--llm-min-similarity", type=float, default=0.60)
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def normalize_text(text: str) -> str:
    text = text or ""
    text = text.replace("\r", " ").replace("\n", " ").strip().lower()
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"[“”]", '"', text)
    text = re.sub(r"[‘’]", "'", text)
    text = re.sub(r"\s([?.!,])", r"\1", text)
    return text


def token_set(text: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9]+", text.lower()) if token}


def pairwise_metrics(texts: List[str]) -> Tuple[float, float]:
    if len(texts) < 2:
        return 0.0, 0.0
    char_scores: List[float] = []
    token_scores: List[float] = []
    for index in range(len(texts)):
        for offset in range(index + 1, len(texts)):
            left = texts[index]
            right = texts[offset]
            char_scores.append(difflib.SequenceMatcher(a=left, b=right).ratio())
            left_tokens = token_set(left)
            right_tokens = token_set(right)
            union = left_tokens | right_tokens
            token_scores.append(len(left_tokens & right_tokens) / len(union) if union else 1.0)
    return sum(char_scores) / len(char_scores), sum(token_scores) / len(token_scores)


def extract_spans(text: str) -> Dict[str, List[str]]:
    patterns = {
        "url": [r"https?://\S+", r"www\.\S+"],
        "phone": [r"\b\d{10,12}\b"],
        "otp": [r"\b\d{4,8}\b"],
        "amount": [r"(?:rs\.?|inr|\$|usd|eur|gbp|₹)\s?\d+(?:[.,]\d+)?", r"\b\d+[.,]?\d*\s?(?:rs|inr|usd|eur|gbp)\b"],
        "email": [r"\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b"],
    }
    text = text.lower()
    spans: Dict[str, List[str]] = {}
    for key, variants in patterns.items():
        values = []
        for pattern in variants:
            values.extend(match.group(0) for match in re.finditer(pattern, text))
        spans[key] = sorted(set(values))
    return spans


def span_consensus(normalized_texts: List[str]) -> Tuple[bool, str]:
    if not normalized_texts:
        return False, "no_predictions"
    per_engine = [extract_spans(text) for text in normalized_texts]
    any_spans = any(any(values for values in spans.values()) for spans in per_engine)
    if not any_spans:
        return True, "no_critical_spans_present"
    keys = per_engine[0].keys()
    for key in keys:
        non_empty = [tuple(spans[key]) for spans in per_engine if spans[key]]
        if len(non_empty) > 1 and len(set(non_empty)) > 1:
            return False, f"{key}_conflict"
    return True, "span_match_or_single_source"


def choose_reference_text(normalized_texts: List[str]) -> str:
    if not normalized_texts:
        return ""
    counts = Counter(normalized_texts)
    ranked = sorted(counts.items(), key=lambda item: (item[1], len(item[0])), reverse=True)
    return ranked[0][0]


def load_eval_manifest(path: Path) -> Dict[str, Dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return {row["sample_id"]: row for row in csv.DictReader(handle)}


def load_predictions(paths: Iterable[Path]) -> Dict[str, List[Dict[str, str]]]:
    grouped: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    for path in paths:
        with path.open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                grouped[row["sample_id"]].append(
                    {
                        "engine_name": row["engine_name"],
                        "predicted_text": normalize_text(row.get("predicted_text", "")),
                        "source_file": path.name,
                    }
                )
    return grouped


def write_csv(path: Path, rows: List[Dict[str, str]], fieldnames: List[str]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    eval_manifest = load_eval_manifest(Path(args.eval_manifest))
    predictions = load_predictions(Path(item) for item in args.prediction_files)

    output_rows: List[Dict[str, str]] = []
    summary_counter: Counter[str] = Counter()

    for sample_id, sample in eval_manifest.items():
        sample_predictions = predictions.get(sample_id, [])
        normalized_texts = [item["predicted_text"] for item in sample_predictions if item["predicted_text"]]
        engine_names = sorted({item["engine_name"] for item in sample_predictions})
        avg_char_similarity, avg_token_jaccard = pairwise_metrics(normalized_texts)
        spans_agree, span_reason = span_consensus(normalized_texts)
        reference_text = choose_reference_text(normalized_texts)

        if len(engine_names) < 2:
            status = "needs_more_ocr"
        elif avg_char_similarity >= args.auto_accept_min_similarity and spans_agree:
            status = "auto_accept"
        elif avg_char_similarity >= args.llm_min_similarity:
            status = "llm_reconcile"
        else:
            status = "manual_review"

        summary_counter[status] += 1
        output_rows.append(
            {
                "sample_id": sample_id,
                "source_group": sample["source_group"],
                "source_name": sample["source_name"],
                "image_path": sample["image_path"],
                "evaluation_slice": sample["evaluation_slice"],
                "engine_count": str(len(engine_names)),
                "engine_names": "|".join(engine_names),
                "avg_pairwise_similarity": f"{avg_char_similarity:.6f}",
                "avg_pairwise_token_jaccard": f"{avg_token_jaccard:.6f}",
                "critical_span_consensus": "true" if spans_agree else "false",
                "critical_span_note": span_reason,
                "reference_status": status,
                "reference_text_candidate": reference_text,
                "has_gold_text": sample["has_gold_text"],
                "gold_text": sample["gold_text"],
            }
        )

    write_csv(
        Path(args.output),
        output_rows,
        [
            "sample_id",
            "source_group",
            "source_name",
            "image_path",
            "evaluation_slice",
            "engine_count",
            "engine_names",
            "avg_pairwise_similarity",
            "avg_pairwise_token_jaccard",
            "critical_span_consensus",
            "critical_span_note",
            "reference_status",
            "reference_text_candidate",
            "has_gold_text",
            "gold_text",
        ],
    )

    summary_rows = [{"reference_status": key, "sample_count": str(value)} for key, value in sorted(summary_counter.items())]
    write_csv(Path(args.summary_output), summary_rows, ["reference_status", "sample_count"])
    print(f"Wrote reference manifest to {args.output}")
    print(f"Wrote reference summary to {args.summary_output}")


if __name__ == "__main__":
    main()
