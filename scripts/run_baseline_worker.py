import json
import os
import subprocess
import sys
import time
import csv
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
SCRIPTS_DIR = ROOT / "scripts"
REPORTS_DIR = ROOT / "data" / "benchmark" / "v0.1" / "reports"
METADATA_DIR = ROOT / "data" / "benchmark" / "v0.1" / "metadata"
DASHBOARD_DIR = ROOT / "dashboard"
STATE_PATH = DASHBOARD_DIR / "baseline_worker_state.json"
LOG_PATH = DASHBOARD_DIR / "baseline_worker.log"
LOCK_PATH = DASHBOARD_DIR / "baseline_worker.lock"
STOP_FLAG = DASHBOARD_DIR / "stop_baseline_worker.flag"
STRESS_TARGET = 546
EVAL_MANIFEST = METADATA_DIR / "ocr_eval_manifest.csv"
LLM_BATCH = METADATA_DIR / "llm_reconciliation_batch.jsonl"


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


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def log(message: str) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"[{utc_now()}] {message}\n")


def write_state(**updates) -> None:
    state = {}
    if STATE_PATH.exists():
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    state.update(updates)
    state["updated_at_utc"] = utc_now()
    STATE_PATH.write_text(json.dumps(state, indent=2), encoding="utf-8")


def count_csv_rows(path: Path) -> int:
    if not path.exists():
        return 0
    with path.open("r", encoding="utf-8") as handle:
        return max(sum(1 for _ in handle) - 1, 0)


def count_jsonl_rows(path: Path) -> int:
    if not path.exists():
        return 0
    with path.open("r", encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())


def count_reference_status(status_name: str) -> int:
    manifest = METADATA_DIR / "reference_transcript_manifest.csv"
    if not manifest.exists():
        return 0
    with manifest.open("r", encoding="utf-8", newline="") as handle:
        return sum(1 for row in csv.DictReader(handle) if row.get("reference_status") == status_name)


def count_model_progress(model_name: str) -> int:
    sample_ids = set()
    for path in REPORTS_DIR.glob("*.csv"):
        with path.open("r", encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows or "model_name" not in rows[0]:
            continue
        for row in rows:
            if row.get("model_name") == model_name and row.get("sample_id") and row.get("source_group") == "stress":
                sample_ids.add(row["sample_id"])
    return len(sample_ids)


def processed_sample_ids_for_model(model_name: str) -> set[str]:
    sample_ids = set()
    for path in REPORTS_DIR.glob("*.csv"):
        with path.open("r", encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows or "model_name" not in rows[0]:
            continue
        for row in rows:
            if row.get("model_name") == model_name and row.get("sample_id") and row.get("source_group") == "stress":
                sample_ids.add(row["sample_id"])
    return sample_ids


def next_missing_stress_ids(model_name: str, limit: int) -> list[str]:
    processed = processed_sample_ids_for_model(model_name)
    with EVAL_MANIFEST.open("r", encoding="utf-8", newline="") as handle:
        pending = []
        for row in csv.DictReader(handle):
            if row.get("source_group") != "stress":
                continue
            sample_id = row["sample_id"]
            if sample_id not in processed:
                pending.append(sample_id)
            if len(pending) >= limit:
                break
    return pending


def write_sample_ids_file(path: Path, sample_ids: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(sample_ids), encoding="utf-8")


def reconciled_sample_ids() -> set[str]:
    path = REPORTS_DIR / "llm_reconciliation_gemini.jsonl"
    if not path.exists():
        return set()
    done = set()
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            payload = json.loads(line)
            sample_id = payload.get("result", {}).get("sample_id")
            if sample_id:
                done.add(sample_id)
    return done


def next_pending_llm_ids(limit: int) -> list[str]:
    done = reconciled_sample_ids()
    pending = []
    if not LLM_BATCH.exists():
        return pending
    with LLM_BATCH.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            payload = json.loads(line)
            sample_id = payload.get("sample_id")
            if sample_id and sample_id not in done:
                pending.append(sample_id)
            if len(pending) >= limit:
                break
    return pending


def slugify_model(model_name: str) -> str:
    return model_name.replace("/", "__").replace("-", "_").replace(".", "_")


def canonical_model_output(model_name: str) -> str:
    return str(REPORTS_DIR / f"{slugify_model(model_name)}_predictions_v0_1.csv")


def chunk_model_output(model_name: str, offset: int, limit: int) -> str:
    return str(REPORTS_DIR / f"{slugify_model(model_name)}__chunk_{offset}_{limit}.csv")


def run_command(command: list[str], step: str) -> None:
    log(f"START {step}: {' '.join(command)}")
    subprocess.run(command, cwd=ROOT, check=True, env=os.environ.copy())
    log(f"DONE {step}")


def refresh_dashboard() -> None:
    run_command([sys.executable, str(SCRIPTS_DIR / "generate_benchmark_dashboard.py")], "dashboard_refresh")


def rebuild_reference_state() -> None:
    prediction_files = [
        REPORTS_DIR / "rapidocr_predictions_v0_1.csv",
        REPORTS_DIR / "tesseract_predictions_v0_1.csv",
        REPORTS_DIR / "rapidocr_predictions_stress_v0_1.csv",
        REPORTS_DIR / "tesseract_predictions_stress_v0_1.csv",
    ]
    existing = [str(path) for path in prediction_files if path.exists()]
    if len(existing) >= 2:
        run_command(
            [sys.executable, str(SCRIPTS_DIR / "build_reference_transcripts.py"), "--prediction-files", *existing],
            "build_reference_transcripts",
        )
        run_command(
            [sys.executable, str(SCRIPTS_DIR / "export_llm_reconciliation_batch.py"), "--prediction-files", *existing],
            "export_llm_reconciliation_batch",
        )
    llm_results = REPORTS_DIR / "llm_reconciliation_gemini.jsonl"
    if llm_results.exists() and count_jsonl_rows(llm_results) > 0:
        run_command([sys.executable, str(SCRIPTS_DIR / "apply_llm_reconciliation.py")], "apply_llm_reconciliation")


def current_counts() -> dict:
    phi4_model = "microsoft/phi-4-multimodal-instruct"
    llm_total = count_reference_status("llm_reconcile")
    return {
        "rapidocr_stress_done": count_csv_rows(REPORTS_DIR / "rapidocr_predictions_stress_v0_1.csv"),
        "tesseract_stress_done": count_csv_rows(REPORTS_DIR / "tesseract_predictions_stress_v0_1.csv"),
        "phi4_done": count_model_progress(phi4_model),
        "phi4_total": STRESS_TARGET,
        "llm_done": count_jsonl_rows(REPORTS_DIR / "llm_reconciliation_gemini.jsonl"),
        "llm_total": llm_total,
    }


def all_done(counts: dict) -> bool:
    return (
        counts["rapidocr_stress_done"] >= STRESS_TARGET
        and counts["tesseract_stress_done"] >= STRESS_TARGET
        and counts["phi4_done"] >= STRESS_TARGET
        and counts["llm_done"] >= counts["llm_total"]
    )


def acquire_lock() -> None:
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    if LOCK_PATH.exists():
        raise RuntimeError(f"Worker lock exists at {LOCK_PATH}. Stop the old worker first.")
    LOCK_PATH.write_text(str(os.getpid()), encoding="utf-8")


def release_lock() -> None:
    if LOCK_PATH.exists():
        LOCK_PATH.unlink()


def main() -> None:
    load_env_file(ENV_PATH)
    acquire_lock()
    loop_count = 0
    backoff_seconds = 15
    write_state(
        running=True,
        health="starting",
        current_step="starting",
        last_error="",
        started_at_utc=utc_now(),
        last_heartbeat_at_utc=utc_now(),
        last_progress_at_utc=utc_now(),
        stagnant_loops=0,
        consecutive_errors=0,
        log_path=str(LOG_PATH.relative_to(ROOT)),
        note="Read-only dashboard; worker is the only controller.",
    )
    try:
        refresh_dashboard()
        while True:
            write_state(last_heartbeat_at_utc=utc_now())
            if STOP_FLAG.exists():
                log("STOP flag detected; exiting worker.")
                write_state(running=False, health="stopped", current_step="stopped_by_flag")
                STOP_FLAG.unlink()
                break

            loop_count += 1
            counts_before = current_counts()
            state_before = read_json(STATE_PATH)
            stagnant_loops = int(state_before.get("stagnant_loops", 0))
            consecutive_errors = int(state_before.get("consecutive_errors", 0))
            write_state(current_step="loop_start", health="running", loop_count=loop_count, **counts_before)

            try:
                if counts_before["rapidocr_stress_done"] < STRESS_TARGET:
                    write_state(current_step="rapidocr_stress", **counts_before)
                    run_command(
                        [
                            "powershell",
                            "-ExecutionPolicy",
                            "Bypass",
                            "-File",
                            str(SCRIPTS_DIR / "run_ocr_chunks.ps1"),
                            "-Engine",
                            "rapidocr",
                            "-SourceGroup",
                            "stress",
                            "-ChunkSize",
                            "50",
                        ],
                        "rapidocr_stress",
                    )

                counts_before = current_counts()
                if counts_before["tesseract_stress_done"] < STRESS_TARGET:
                    write_state(current_step="tesseract_stress", **counts_before)
                    run_command(
                        [
                            "powershell",
                            "-ExecutionPolicy",
                            "Bypass",
                            "-File",
                            str(SCRIPTS_DIR / "run_ocr_chunks.ps1"),
                            "-Engine",
                            "tesseract",
                            "-SourceGroup",
                            "stress",
                            "-ChunkSize",
                            "25",
                        ],
                        "tesseract_stress",
                    )

                counts_before = current_counts()
                if counts_before["phi4_done"] < STRESS_TARGET:
                    phi4_ids = next_missing_stress_ids("microsoft/phi-4-multimodal-instruct", 5)
                    if not phi4_ids:
                        write_state(current_step="phi4_no_pending_ids", health="stalled", last_error="No pending Phi-4 IDs found, but target not reached.", **counts_before)
                    else:
                        phi4_ids_file = DASHBOARD_DIR / "phi4_pending_ids.txt"
                        write_sample_ids_file(phi4_ids_file, phi4_ids)
                        write_state(current_step="nvidia_phi4_chunk", pending_sample_ids=phi4_ids, **counts_before)
                        run_command(
                            [
                                sys.executable,
                                str(SCRIPTS_DIR / "run_nvidia_vision_batch.py"),
                                "--model",
                                "microsoft/phi-4-multimodal-instruct",
                                "--source-group",
                                "stress",
                                "--sample-ids-file",
                                str(phi4_ids_file),
                                "--limit",
                                str(len(phi4_ids)),
                                "--output",
                                chunk_model_output("microsoft/phi-4-multimodal-instruct", counts_before["phi4_done"], len(phi4_ids)),
                                "--workers",
                                "2",
                            ],
                            "nvidia_phi4_chunk",
                        )
                        run_command(
                            [
                                sys.executable,
                                str(SCRIPTS_DIR / "merge_model_outputs.py"),
                                "--model-name",
                                "microsoft/phi-4-multimodal-instruct",
                                "--output",
                                canonical_model_output("microsoft/phi-4-multimodal-instruct"),
                            ],
                            "merge_phi4",
                        )

                counts_before = current_counts()
                if counts_before["phi4_done"] < STRESS_TARGET:
                    phi4_secondary_ids = next_missing_stress_ids("microsoft/phi-4-multimodal-instruct", 5)
                    if not phi4_secondary_ids:
                        write_state(current_step="phi4_secondary_no_pending_ids", health="stalled", last_error="No pending Phi-4 secondary IDs found, but target not reached.", **counts_before)
                    else:
                        phi4_secondary_ids_file = DASHBOARD_DIR / "phi4_secondary_pending_ids.txt"
                        write_sample_ids_file(phi4_secondary_ids_file, phi4_secondary_ids)
                        write_state(current_step="nvidia_phi4_secondary_chunk", pending_sample_ids=phi4_secondary_ids, **counts_before)
                        run_command(
                            [
                                sys.executable,
                                str(SCRIPTS_DIR / "run_nvidia_vision_batch.py"),
                                "--model",
                                "microsoft/phi-4-multimodal-instruct",
                                "--api-key-env",
                                "NVIDIA_API_KEY_SCOUT",
                                "--source-group",
                                "stress",
                                "--sample-ids-file",
                                str(phi4_secondary_ids_file),
                                "--limit",
                                str(len(phi4_secondary_ids)),
                                "--output",
                                chunk_model_output("microsoft/phi-4-multimodal-instruct", counts_before["phi4_done"], len(phi4_secondary_ids)),
                                "--workers",
                                "4",
                            ],
                            "nvidia_phi4_secondary_chunk",
                        )
                        run_command(
                            [
                                sys.executable,
                                str(SCRIPTS_DIR / "merge_model_outputs.py"),
                                "--model-name",
                                "microsoft/phi-4-multimodal-instruct",
                                "--output",
                                canonical_model_output("microsoft/phi-4-multimodal-instruct"),
                            ],
                            "merge_phi4_secondary",
                        )

                write_state(current_step="rebuild_reference_state")
                rebuild_reference_state()

                counts_before = current_counts()
                if counts_before["llm_done"] < counts_before["llm_total"]:
                    llm_ids = next_pending_llm_ids(5)
                    if not llm_ids:
                        write_state(current_step="gemini_no_pending_ids", health="stalled", last_error="No pending Gemini IDs found, but unresolved queue remains.", **counts_before)
                    else:
                        llm_ids_file = DASHBOARD_DIR / "gemini_pending_ids.txt"
                        write_sample_ids_file(llm_ids_file, llm_ids)
                        write_state(current_step="gemini_reconciliation", pending_sample_ids=llm_ids, **counts_before)
                        run_command(
                            [
                                sys.executable,
                                str(SCRIPTS_DIR / "run_llm_reconciliation.py"),
                                "--provider",
                                "gemini",
                                "--model",
                                "gemini-2.5-flash",
                                "--batch",
                                str(METADATA_DIR / "llm_reconciliation_batch.jsonl"),
                                "--sample-ids-file",
                                str(llm_ids_file),
                                "--output",
                                str(REPORTS_DIR / "llm_reconciliation_gemini.jsonl"),
                                "--append",
                                "--max-retries",
                                "6",
                            ],
                            "gemini_reconciliation",
                        )
                        run_command([sys.executable, str(SCRIPTS_DIR / "apply_llm_reconciliation.py")], "apply_llm_reconciliation")

                refresh_dashboard()
                counts_after = current_counts()
                progressed = any(counts_after[key] > counts_before.get(key, -1) for key in counts_after.keys())
                stagnant_loops = 0 if progressed else stagnant_loops + 1
                health = "progressing" if progressed else ("stalled" if stagnant_loops >= 3 else "waiting")
                write_state(
                    current_step="sleeping_after_progress" if progressed else "sleeping_no_progress",
                    health=health,
                    last_error="",
                    consecutive_errors=0,
                    last_progress_at_utc=utc_now() if progressed else json.loads(STATE_PATH.read_text(encoding="utf-8")).get("last_progress_at_utc", utc_now()),
                    last_heartbeat_at_utc=utc_now(),
                    stagnant_loops=stagnant_loops,
                    loop_count=loop_count,
                    **counts_after,
                )
                if all_done(counts_after):
                    log("Automatic queue empty; worker finished.")
                    write_state(running=False, health="finished", current_step="finished", **counts_after)
                    break
                time.sleep(3 if progressed else backoff_seconds)
            except Exception as exc:
                log(f"ERROR: {exc}")
                refresh_dashboard()
                consecutive_errors += 1
                write_state(
                    current_step="retrying_after_error",
                    health="error_retrying",
                    last_error=str(exc),
                    consecutive_errors=consecutive_errors,
                    last_heartbeat_at_utc=utc_now(),
                    loop_count=loop_count,
                    **current_counts(),
                )
                time.sleep(backoff_seconds)
    finally:
        release_lock()


if __name__ == "__main__":
    main()
