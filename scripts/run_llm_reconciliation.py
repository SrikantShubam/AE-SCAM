import argparse
import base64
import json
import os
from pathlib import Path
from typing import Any, Dict, List

import requests


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BATCH = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "llm_reconciliation_batch.jsonl"
DEFAULT_OUTPUT = ROOT / "data" / "benchmark" / "v0.1" / "reports" / "llm_reconciliation_results.jsonl"


SYSTEM_PROMPT = """You are reconciling OCR outputs for scam-message benchmarking.

Produce one best-effort reference transcript from multiple OCR outputs of the same screenshot.

Rules:
1. Preserve visible message content as faithfully as possible.
2. Preserve scam-relevant spans whenever supported by the evidence:
   - URLs
   - phone numbers
   - OTP or short numeric codes
   - money amounts
   - email addresses
3. Do not invent content not supported by the OCR evidence.
4. Prefer cross-engine agreement over any one engine's longer text.
5. If the evidence is too conflicting or unreliable, set manual_review to true.
6. Return JSON only with keys: sample_id, reference_text, manual_review, reason.
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run LLM transcript reconciliation on OCR disagreement cases.")
    parser.add_argument("--provider", choices=["gemini", "openai_compat"], required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--batch", default=str(DEFAULT_BATCH))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--include-image", action="store_true")
    parser.add_argument("--base-url", default=None)
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_jsonl(path: Path) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def image_part(path_str: str) -> Dict[str, Any]:
    image_path = ROOT / path_str
    mime = "image/png" if image_path.suffix.lower() == ".png" else "image/jpeg"
    data = base64.b64encode(image_path.read_bytes()).decode("ascii")
    return {"inline_data": {"mime_type": mime, "data": data}}


def ocr_text_block(predictions: List[Dict[str, str]]) -> str:
    lines = []
    for item in predictions:
        lines.append(f"Engine: {item['engine_name']}\nOutput: {item['predicted_text']}")
    return "\n\n".join(lines)


def build_user_prompt(row: Dict[str, Any]) -> str:
    return (
        f"Reconcile these OCR outputs into one best-effort transcript.\n\n"
        f"Sample ID: {row['sample_id']}\n"
        f"Image path: {row['image_path']}\n"
        f"Evaluation slice: {row['evaluation_slice']}\n\n"
        f"OCR outputs:\n{ocr_text_block(row['ocr_predictions'])}\n\n"
        f"Return JSON with this exact shape:\n"
        "{\n"
        '  "sample_id": "...",\n'
        '  "reference_text": "...",\n'
        '  "manual_review": true,\n'
        '  "reason": "short explanation"\n'
        "}\n"
    )


def call_gemini(model: str, row: Dict[str, Any], include_image: bool) -> Dict[str, Any]:
    api_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("Set GOOGLE_API_KEY or GEMINI_API_KEY before using provider=gemini.")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    parts: List[Dict[str, Any]] = [{"text": SYSTEM_PROMPT}, {"text": build_user_prompt(row)}]
    if include_image:
        parts.append(image_part(row["image_path"]))
    payload = {
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.1},
        "contents": [{"role": "user", "parts": parts}],
    }
    response = requests.post(url, json=payload, timeout=180)
    response.raise_for_status()
    data = response.json()
    text = data["candidates"][0]["content"]["parts"][0]["text"]
    return json.loads(text)


def call_openai_compat(model: str, row: Dict[str, Any], base_url: str) -> Dict[str, Any]:
    api_key = (
        os.environ.get("OPENAI_COMPAT_API_KEY")
        or os.environ.get("NVIDIA_API_KEY")
        or os.environ.get("OPENROUTER_API_KEY")
        or os.environ.get("GROQ_API_KEY")
    )
    if not api_key:
        raise RuntimeError(
            "Set OPENAI_COMPAT_API_KEY, NVIDIA_API_KEY, OPENROUTER_API_KEY, or GROQ_API_KEY before using provider=openai_compat."
        )
    if not base_url:
        raise RuntimeError("Provide --base-url for provider=openai_compat.")
    payload = {
        "model": model,
        "temperature": 0.1,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": build_user_prompt(row)},
        ],
    }
    response = requests.post(
        f"{base_url.rstrip('/')}/chat/completions",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json=payload,
        timeout=180,
    )
    response.raise_for_status()
    data = response.json()
    content = data["choices"][0]["message"]["content"]
    return json.loads(content)


def main() -> None:
    args = parse_args()
    rows = read_jsonl(Path(args.batch))
    if args.limit is not None:
        rows = rows[: args.limit]
    output_path = Path(args.output)
    ensure_dir(output_path.parent)

    with output_path.open("w", encoding="utf-8") as handle:
        for row in rows:
            if args.provider == "gemini":
                result = call_gemini(args.model, row, args.include_image)
            else:
                result = call_openai_compat(args.model, row, args.base_url)
            record = {
                "sample_id": row["sample_id"],
                "provider": args.provider,
                "model": args.model,
                "result": result,
            }
            handle.write(json.dumps(record, ensure_ascii=True) + "\n")
    print(f"Wrote {len(rows)} LLM reconciliation results to {output_path}")


if __name__ == "__main__":
    main()
