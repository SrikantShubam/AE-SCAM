import argparse
import base64
import csv
import mimetypes
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, List, Tuple

import requests


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
EVAL_MANIFEST = ROOT / "data" / "benchmark" / "v0.1" / "metadata" / "ocr_eval_manifest.csv"
REPORTS_DIR = ROOT / "data" / "benchmark" / "v0.1" / "reports"
NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1/chat/completions"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and value and key not in os.environ:
            os.environ[key] = value


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run NVIDIA-hosted multimodal extraction over the OCR eval manifest.")
    parser.add_argument("--model", required=True)
    parser.add_argument("--source-group", choices=["synthetic", "stress", "all"], default="all")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--append", action="store_true")
    parser.add_argument("--max-tokens", type=int, default=1200)
    parser.add_argument("--temperature", type=float, default=0.1)
    parser.add_argument("--base-url", default=NVIDIA_BASE_URL)
    parser.add_argument("--output", default=None)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--max-retries", type=int, default=5)
    parser.add_argument("--manifest", default=str(EVAL_MANIFEST))
    parser.add_argument("--sample-ids-file", default=None)
    parser.add_argument("--api-key-env", default=None)
    return parser.parse_args()


def slugify_model(model: str) -> str:
    return model.replace("/", "__").replace("-", "_").replace(".", "_")


def default_output_for_model(model: str) -> Path:
    return REPORTS_DIR / f"{slugify_model(model)}_predictions_v0_1.csv"


def api_key_for_model(model: str) -> str | None:
    if model == "microsoft/phi-4-multimodal-instruct":
        return (
            os.environ.get("NVIDIA_API_KEY_PHI4")
            or os.environ.get("NVIDIA_API_KEY")
            or os.environ.get("OPENAI_COMPAT_API_KEY")
        )
    if model == "meta/llama-4-scout-17b-16e-instruct":
        return (
            os.environ.get("NVIDIA_API_KEY_SCOUT")
            or os.environ.get("NVIDIA_API_KEY")
            or os.environ.get("OPENAI_COMPAT_API_KEY")
        )
    return os.environ.get("NVIDIA_API_KEY") or os.environ.get("OPENAI_COMPAT_API_KEY")


def api_key_from_env_name(env_name: str | None) -> str | None:
    if not env_name:
        return None
    return os.environ.get(env_name)


def read_manifest(manifest_path: Path, source_group: str) -> List[Dict[str, str]]:
    with manifest_path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if source_group == "all":
        return rows
    return [row for row in rows if row["source_group"] == source_group]


def image_to_data_url(image_path: Path) -> str:
    mime_type, _ = mimetypes.guess_type(str(image_path))
    mime_type = mime_type or "image/png"
    encoded = base64.b64encode(image_path.read_bytes()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def ensure_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def call_nvidia(
    api_key: str,
    base_url: str,
    model: str,
    image_path: Path,
    max_tokens: int,
    temperature: float,
    max_retries: int,
) -> str:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    prompt = (
        "Extract the visible message text from this screenshot as faithfully as possible. "
        "Preserve URLs, phone numbers, OTP codes, money amounts, email addresses, and sender IDs. "
        "Return plain text only. Do not summarize."
    )
    payload = {
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": image_to_data_url(image_path)}},
                ],
            }
        ],
    }
    last_error = None
    for attempt in range(max_retries):
        response = requests.post(base_url, headers=headers, json=payload, timeout=300)
        if response.status_code in (429,) or response.status_code >= 500:
            if attempt == max_retries - 1:
                last_error = f"{response.status_code} {response.text[:500]}"
                response.raise_for_status()
            time.sleep(min(2 ** attempt, 20))
            continue
        try:
            response.raise_for_status()
        except requests.HTTPError:
            body = response.text[:1000]
            raise requests.HTTPError(f"{response.status_code} Client Error for {image_path.name}: {body}", response=response)
        data = response.json()
        content = data["choices"][0]["message"]["content"]
        if isinstance(content, list):
            return "\n".join(part.get("text", "") for part in content if isinstance(part, dict)).strip()
        return str(content).strip()
    raise RuntimeError("NVIDIA vision call failed after retries.")


def process_row(
    row: Dict[str, str],
    api_key: str,
    base_url: str,
    model: str,
    max_tokens: int,
    temperature: float,
    max_retries: int,
) -> Tuple[str, Dict[str, str]]:
    image_path = ROOT / row["image_path"]
    start = time.perf_counter()
    try:
        predicted_text = call_nvidia(
            api_key=api_key,
            base_url=base_url,
            model=model,
            image_path=image_path,
            max_tokens=max_tokens,
            temperature=temperature,
            max_retries=max_retries,
        )
        error = ""
    except Exception as exc:
        predicted_text = ""
        error = str(exc)
    latency_ms = (time.perf_counter() - start) * 1000
    output_row = {
        "sample_id": row["sample_id"],
        "engine_name": "NVIDIAVision",
        "model_name": model,
        "source_group": row["source_group"],
        "source_name": row["source_name"],
        "image_path": row["image_path"],
        "predicted_text": predicted_text,
        "latency_ms": f"{latency_ms:.2f}",
        "error": error,
    }
    return row["sample_id"], output_row


def main() -> None:
    load_env_file(ENV_PATH)
    args = parse_args()
    api_key = api_key_from_env_name(args.api_key_env) or api_key_for_model(args.model)
    if not api_key:
        raise RuntimeError(
            "Set a model-specific NVIDIA key or fallback NVIDIA_API_KEY/OPENAI_COMPAT_API_KEY before using NVIDIA vision extraction."
        )

    rows = read_manifest(Path(args.manifest), args.source_group)
    if args.sample_ids_file:
        wanted = {
            line.strip()
            for line in Path(args.sample_ids_file).read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
        rows = [row for row in rows if row["sample_id"] in wanted]
    if args.offset:
        rows = rows[args.offset:]
    if args.limit is not None:
        rows = rows[: args.limit]

    output_path = Path(args.output) if args.output else default_output_for_model(args.model)
    ensure_dir(output_path)
    mode = "a" if args.append and output_path.exists() else "w"

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
    completed_rows: List[Tuple[int, Dict[str, str]]] = []
    index_map = {row["sample_id"]: index for index, row in enumerate(rows)}
    worker_count = max(1, args.workers)

    with ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = {
            executor.submit(
                process_row,
                row,
                api_key,
                args.base_url,
                args.model,
                args.max_tokens,
                args.temperature,
                args.max_retries,
            ): row["sample_id"]
            for row in rows
        }
        for future in as_completed(futures):
            sample_id, output_row = future.result()
            completed_rows.append((index_map[sample_id], output_row))

    completed_rows.sort(key=lambda item: item[0])
    with output_path.open(mode, encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        if mode == "w":
            writer.writeheader()
        for _, output_row in completed_rows:
            writer.writerow(output_row)
        handle.flush()
    print(f"Wrote {len(rows)} NVIDIA vision predictions to {output_path}")


if __name__ == "__main__":
    main()
