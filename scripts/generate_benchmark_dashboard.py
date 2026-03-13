import csv
import html
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "data" / "benchmark" / "v0.1" / "reports"
METADATA = ROOT / "data" / "benchmark" / "v0.1" / "metadata"
DASHBOARD_DIR = ROOT / "dashboard"
HTML_OUT = DASHBOARD_DIR / "ocr_benchmark_dashboard.html"
JSON_OUT = DASHBOARD_DIR / "ocr_benchmark_dashboard.json"
WORKER_STATE = DASHBOARD_DIR / "baseline_worker_state.json"
STRESS_TOTAL = 546


def read_csv(path: Path) -> List[Dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def read_json(path: Path) -> Dict[str, object]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def sample_id_set(filename: str) -> set[str]:
    return {row["sample_id"] for row in read_csv(REPORTS / filename) if row.get("sample_id")}


def sample_id_set_by_model(model_name: str) -> set[str]:
    sample_ids: set[str] = set()
    for path in REPORTS.glob("*.csv"):
        rows = read_csv(path)
        if not rows or "model_name" not in rows[0]:
            continue
        for row in rows:
            if row.get("model_name") == model_name and row.get("sample_id") and row.get("source_group") == "stress":
                sample_ids.add(row["sample_id"])
    return sample_ids


def read_jsonl_count(path: Path) -> int:
    if not path.exists():
        return 0
    with path.open("r", encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())


def rank_engine(engine_name: str, avg_span: float, avg_body: float, avg_latency: float | None) -> str:
    if engine_name == "EasyOCR":
        return "legacy"
    if avg_latency is None:
        return "pending"
    if avg_span >= 0.97 and avg_body >= 0.97 and avg_latency < 1000:
        return "promote"
    if avg_span >= 0.90:
        return "keep-testing"
    return "demote"


def load_engine_summary(report_name: str, engine_name: str) -> Dict[str, object]:
    summary_path = REPORTS / report_name
    prediction_path = REPORTS / report_name.replace("_ocr_summary", "").replace("_detail", "")
    rows = read_csv(summary_path)
    if not rows:
        return {"engine_name": engine_name, "available": False}
    total = sum(int(row["sample_count"]) for row in rows)
    avg_cer = sum(float(row["avg_cer"]) * int(row["sample_count"]) for row in rows) / total
    avg_body = sum(float(row["avg_body_token_recall"]) * int(row["sample_count"]) for row in rows) / total
    avg_span = sum(float(row["avg_scam_span_recall"]) * int(row["sample_count"]) for row in rows) / total
    pred_rows = read_csv(prediction_path.with_suffix(".csv"))
    latencies = [float(row["latency_ms"]) for row in pred_rows if row.get("latency_ms")]
    avg_latency = sum(latencies) / len(latencies) if latencies else None
    return {
        "engine_name": engine_name,
        "available": True,
        "sample_count": total,
        "avg_cer": round(avg_cer, 6),
        "avg_body_token_recall": round(avg_body, 6),
        "avg_scam_span_recall": round(avg_span, 6),
        "avg_latency_ms": round(avg_latency, 2) if avg_latency is not None else None,
        "status": rank_engine(engine_name, avg_span, avg_body, avg_latency),
    }


def progress_block(done: int, total: int) -> Dict[str, object]:
    pct = round((done / total) * 100, 2) if total else 0.0
    return {"done": done, "total": total, "pct": pct}


def build_data() -> Dict[str, object]:
    ocr_eval_rows = read_csv(METADATA / "ocr_eval_manifest.csv")
    reference_rows = read_csv(METADATA / "reference_transcript_manifest.csv")
    resolved_rows = read_csv(METADATA / "reference_transcript_manifest_resolved.csv")
    synthetic_batch = read_csv(ROOT / "data" / "interim" / "manifests" / "synthetic_batch_v0_1.csv")
    synthetic_render = read_csv(ROOT / "data" / "interim" / "manifests" / "synthetic_render_manifest.csv")
    worker = read_json(WORKER_STATE)

    status_counts: Dict[str, int] = {}
    for row in reference_rows:
        status_counts[row["reference_status"]] = status_counts.get(row["reference_status"], 0) + 1

    resolved_status_counts: Dict[str, int] = {}
    for row in resolved_rows:
        resolved_status_counts[row["reference_status"]] = resolved_status_counts.get(row["reference_status"], 0) + 1

    rapid_ids = sample_id_set("rapidocr_predictions_v0_1.csv") | sample_id_set("rapidocr_predictions_stress_v0_1.csv")
    tesseract_ids = sample_id_set("tesseract_predictions_v0_1.csv") | sample_id_set("tesseract_predictions_stress_v0_1.csv")
    nvidia_phi4_ids = sample_id_set_by_model("microsoft/phi-4-multimodal-instruct")
    total_eval = len(ocr_eval_rows)
    llm_total = status_counts.get("llm_reconcile", 0)
    llm_done = read_jsonl_count(REPORTS / "llm_reconciliation_gemini.jsonl")

    return {
        "last_updated_utc": datetime.now(timezone.utc).isoformat(),
        "overview": {
            "fully_ocr_processed": len(rapid_ids & tesseract_ids),
            "ocr_remaining": max(total_eval - len(rapid_ids & tesseract_ids), 0),
            "llm_total": llm_total,
            "llm_done": llm_done,
            "llm_remaining": max(llm_total - llm_done, 0),
            "automatic_remaining": max(STRESS_TOTAL - len(nvidia_phi4_ids), 0) + max(llm_total - llm_done, 0),
        },
        "coverage": {
            "ocr_eval_total": total_eval,
            "synthetic_total": sum(1 for row in ocr_eval_rows if row["source_group"] == "synthetic"),
            "stress_total": sum(1 for row in ocr_eval_rows if row["source_group"] == "stress"),
            "synthetic_batch_total": len(synthetic_batch),
            "synthetic_rendered": len(synthetic_render),
            "synthetic_manual_placeholders": sum(1 for row in synthetic_batch if row["curation_status"] != "ready_for_render"),
        },
        "reference_status": status_counts,
        "resolved_reference_status": resolved_status_counts,
        "engines": [
            load_engine_summary("rapidocr_predictions_v0_1_ocr_summary.csv", "RapidOCR"),
            load_engine_summary("tesseract_predictions_v0_1_ocr_summary.csv", "Tesseract"),
            load_engine_summary("microsoft__phi_4_multimodal_instruct_predictions_v0_1_ocr_summary.csv", "NVIDIA Phi-4 Multimodal"),
            load_engine_summary("easyocr_predictions_v0_1_ocr_summary.csv", "EasyOCR"),
        ],
        "engine_progress": {
            "RapidOCR": {
                "synthetic": progress_block(len(sample_id_set("rapidocr_predictions_v0_1.csv")), 80),
                "stress": progress_block(len(sample_id_set("rapidocr_predictions_stress_v0_1.csv")), STRESS_TOTAL),
            },
            "Tesseract": {
                "synthetic": progress_block(len(sample_id_set("tesseract_predictions_v0_1.csv")), 80),
                "stress": progress_block(len(sample_id_set("tesseract_predictions_stress_v0_1.csv")), STRESS_TOTAL),
            },
        },
        "method_progress": {
            "RapidOCR": progress_block(len(rapid_ids), total_eval),
            "Tesseract": progress_block(len(tesseract_ids), total_eval),
            "NVIDIA Phi-4 Multimodal": progress_block(len(nvidia_phi4_ids), STRESS_TOTAL),
            "Gemini Reconciliation": progress_block(llm_done, llm_total),
        },
        "stress_outputs": {
            "rapidocr_stress_predictions": len(read_csv(REPORTS / "rapidocr_predictions_stress_v0_1.csv")),
            "tesseract_stress_predictions": len(read_csv(REPORTS / "tesseract_predictions_stress_v0_1.csv")),
        },
        "llm": {"gemini_reconciled": llm_done},
        "worker": worker,
    }


def write_json(path: Path, data: Dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def write_html(path: Path, data: Dict[str, object]) -> None:
    data_json = json.dumps(data)
    html_text = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OCR Benchmark Dashboard</title>
  <meta http-equiv="refresh" content="5">
  <style>
    :root {{
      --bg: #0b1020; --surface: #141b2d; --surface-2: #1a243b; --ink: #e6edf7;
      --muted: #9aa7bd; --line: #29344d; --good: #86efac; --warn: #fdba74; --bad: #fca5a5;
    }}
    body {{ margin: 0; font-family: Georgia, 'Times New Roman', serif; background: radial-gradient(circle at top, #18233a 0%, #0b1020 60%); color: var(--ink); }}
    .wrap {{ max-width: 1180px; margin: 0 auto; padding: 32px 20px 56px; }}
    h1, h2 {{ margin: 0 0 12px; }} p {{ color: var(--muted); }}
    .hero, .section {{ background: linear-gradient(180deg, var(--surface), var(--surface-2)); border: 1px solid var(--line); border-radius: 24px; padding: 24px; box-shadow: 0 18px 40px rgba(0,0,0,.24); }}
    .section {{ margin-top: 22px; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 14px; margin-top: 18px; }}
    .card {{ background: linear-gradient(180deg, #18223a, #121a2b); border: 1px solid var(--line); border-radius: 18px; padding: 18px; }}
    .label {{ font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }}
    .value {{ font-size: 34px; margin-top: 6px; }}
    table {{ width: 100%; border-collapse: collapse; font-family: 'Segoe UI', sans-serif; font-size: 14px; }}
    th, td {{ padding: 10px 8px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }}
    th {{ font-size: 12px; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); }}
    .stamp {{ margin-top: 10px; font-size: 12px; color: var(--muted); font-family: 'Segoe UI', sans-serif; }}
    .pill {{ display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-family: 'Segoe UI', sans-serif; }}
    .promote {{ background: #dcfce7; color: #166534; }} .legacy {{ background: #fef3c7; color: #92400e; }}
    .demote {{ background: #fee2e2; color: #991b1b; }} .keep-testing {{ background: #e0f2fe; color: #075985; }} .pending {{ background: #e5e7eb; color: #374151; }}
    code {{ font-family: Consolas, monospace; }}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <h1>OCR Benchmark Dashboard</h1>
      <p>Read-only monitor for OCR benchmark progress and baseline reference generation.</p>
      <div class="stamp">Updated: <span id="updated-at">loading</span></div>
      <div class="stamp">Worker running: <strong id="worker-running">unknown</strong></div>
      <div class="stamp">Worker health: <strong id="worker-health">unknown</strong></div>
      <div class="stamp">Worker step: <strong id="worker-step">unknown</strong></div>
      <div class="stamp">Last heartbeat: <strong id="worker-heartbeat">unknown</strong></div>
      <div class="stamp">Last progress: <strong id="worker-progress">unknown</strong></div>
      <div class="stamp">Last error: <strong id="worker-error">none</strong></div>
      <div class="stamp">Read-only dashboard. Start the worker separately. This page only reflects disk state.</div>
      <div class="grid" id="overview-grid"></div>
      <div class="grid" id="coverage-grid"></div>
    </div>
    <div class="section">
      <h2>Worker Status</h2>
      <table><thead><tr><th>Field</th><th>Value</th></tr></thead><tbody id="worker-rows"></tbody></table>
    </div>
    <div class="section">
      <h2>Live OCR Processing Progress</h2>
      <table><thead><tr><th>Engine</th><th>Synthetic</th><th>Stress</th></tr></thead><tbody id="progress-rows"></tbody></table>
    </div>
    <div class="section">
      <h2>Processed vs Remaining by Method</h2>
      <table><thead><tr><th>Method</th><th>Processed</th><th>Remaining</th><th>Total</th><th>Progress</th></tr></thead><tbody id="method-progress-rows"></tbody></table>
    </div>
    <div class="section">
      <h2>Reference Resolution Status</h2>
      <div class="grid" id="reference-status-grid"></div>
    </div>
    <div class="section">
      <h2>Synthetic Resolved Snapshot</h2>
      <div class="grid" id="resolved-status-grid"></div>
    </div>
    <div class="section">
      <h2>Synthetic OCR Comparison</h2>
      <table><thead><tr><th>Engine</th><th>Samples</th><th>Avg CER</th><th>Body Recall</th><th>Span Recall</th><th>Avg Latency ms</th><th>Rank</th></tr></thead><tbody id="engine-rows"></tbody></table>
    </div>
  </div>
  <script>
    const API_STATUS = "/api/status";
    const JSON_PATH = "./ocr_benchmark_dashboard.json";
    const INITIAL_DATA = {data_json};

    function card(label, value) {{ return `<div class="card"><div class="label">${{label}}</div><div class="value">${{value}}</div></div>`; }}
    function renderCards(counts, order) {{ return order.map((key) => card(key, counts[key] || 0)).join(""); }}
    function coverageCards(coverage) {{ return [["Total Eval Images", coverage.ocr_eval_total], ["Synthetic", coverage.synthetic_total], ["Stress / Real", coverage.stress_total], ["Rendered Synthetic", coverage.synthetic_rendered], ["Manual Placeholder Rows", coverage.synthetic_manual_placeholders]].map(([l,v]) => card(l, v)).join(""); }}
    function overviewCards(overview) {{ return [["OCR Processed", overview.fully_ocr_processed], ["OCR Remaining", overview.ocr_remaining], ["Gemini Done", `${{overview.llm_done}} / ${{overview.llm_total}}`], ["Auto Work Left", overview.automatic_remaining]].map(([l,v]) => card(l, v)).join(""); }}
    function renderProgressRows(progress) {{ return Object.entries(progress).map(([name, data]) => `<tr><td>${{name}}</td><td>${{data.synthetic.done}} / ${{data.synthetic.total}} (${{data.synthetic.pct}}%)</td><td>${{data.stress.done}} / ${{data.stress.total}} (${{data.stress.pct}}%)</td></tr>`).join(""); }}
    function renderMethodRows(progress) {{ return Object.entries(progress).map(([name, data]) => `<tr><td>${{name}}</td><td>${{data.done}}</td><td>${{Math.max(data.total-data.done,0)}}</td><td>${{data.total}}</td><td>${{data.pct}}%</td></tr>`).join(""); }}
    function enginePill(status) {{ const css = ["promote","legacy","demote","keep-testing","pending"].includes(status) ? status : "pending"; return `<span class="pill ${{css}}">${{status}}</span>`; }}
    function renderEngineRows(engines) {{ return engines.map((engine) => engine.available ? `<tr><td>${{engine.engine_name}}</td><td>${{engine.sample_count}}</td><td>${{engine.avg_cer}}</td><td>${{engine.avg_body_token_recall}}</td><td>${{engine.avg_scam_span_recall}}</td><td>${{engine.avg_latency_ms}}</td><td>${{enginePill(engine.status)}}</td></tr>` : `<tr><td>${{engine.engine_name}}</td><td colspan="6">pending</td></tr>`).join(""); }}
    function renderWorkerRows(worker) {{
      const rows = [["Running", worker.running ? "yes" : "no"], ["Health", worker.health || "unknown"], ["Current step", worker.current_step || "unknown"], ["Loop count", worker.loop_count ?? "-"], ["Stagnant loops", worker.stagnant_loops ?? "-"], ["Consecutive errors", worker.consecutive_errors ?? "-"], ["Started at", worker.started_at_utc || "-"], ["Last heartbeat", worker.last_heartbeat_at_utc || "-"], ["Last progress", worker.last_progress_at_utc || "-"], ["Last error", worker.last_error || "-"], ["Log path", worker.log_path || "-"], ["RapidOCR stress", `${{worker.rapidocr_stress_done ?? 0}} / 546`], ["Tesseract stress", `${{worker.tesseract_stress_done ?? 0}} / 546`], ["Phi-4 stress", `${{worker.phi4_done ?? 0}} / ${{worker.phi4_total ?? 546}}`], ["Gemini", `${{worker.llm_done ?? 0}} / ${{worker.llm_total ?? 0}}`]];
      return rows.map(([l,v]) => `<tr><td>${{l}}</td><td>${{v}}</td></tr>`).join("");
    }}
    function applyDashboardData(data) {{
      document.getElementById("updated-at").textContent = data.last_updated_utc || "unknown";
      document.getElementById("overview-grid").innerHTML = overviewCards(data.overview);
      document.getElementById("coverage-grid").innerHTML = coverageCards(data.coverage);
      document.getElementById("progress-rows").innerHTML = renderProgressRows(data.engine_progress);
      document.getElementById("method-progress-rows").innerHTML = renderMethodRows(data.method_progress);
      document.getElementById("reference-status-grid").innerHTML = renderCards(data.reference_status, ["auto_accept","llm_reconcile","manual_review","needs_more_ocr"]);
      document.getElementById("resolved-status-grid").innerHTML = renderCards(data.resolved_reference_status, ["auto_accept","llm_resolved","manual_review","llm_reconcile"]);
      document.getElementById("engine-rows").innerHTML = renderEngineRows(data.engines);
    }}
    function applyWorkerState(worker) {{
      document.getElementById("worker-running").textContent = worker && worker.running ? "yes" : "no";
      document.getElementById("worker-health").textContent = worker && worker.health ? worker.health : "unknown";
      document.getElementById("worker-step").textContent = worker && worker.current_step ? worker.current_step : "unknown";
      document.getElementById("worker-heartbeat").textContent = worker && worker.last_heartbeat_at_utc ? worker.last_heartbeat_at_utc : "unknown";
      document.getElementById("worker-progress").textContent = worker && worker.last_progress_at_utc ? worker.last_progress_at_utc : "unknown";
      document.getElementById("worker-error").textContent = worker && worker.last_error ? worker.last_error : "none";
      document.getElementById("worker-rows").innerHTML = renderWorkerRows(worker || {{}});
    }}
    async function refreshDashboard() {{
      try {{
        const response = await fetch(`${{API_STATUS}}?ts=${{Date.now()}}`, {{ cache: "no-store" }});
        if (!response.ok) throw new Error("status api unavailable");
        const payload = await response.json();
        applyDashboardData(payload.dashboard);
        applyWorkerState(payload.worker || {{}});
      }} catch (error) {{
        try {{
          const response = await fetch(`${{JSON_PATH}}?ts=${{Date.now()}}`, {{ cache: "no-store" }});
          applyDashboardData(await response.json());
        }} catch (innerError) {{
          applyDashboardData(INITIAL_DATA);
        }}
        applyWorkerState({{ running: false, current_step: "server-offline", last_error: "server offline" }});
      }}
    }}
    applyDashboardData(INITIAL_DATA);
    applyWorkerState(INITIAL_DATA.worker || {{}});
    refreshDashboard();
    setInterval(refreshDashboard, 5000);
  </script>
</body>
</html>
"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html_text, encoding="utf-8")


def main() -> None:
    data = build_data()
    write_json(JSON_OUT, data)
    write_html(HTML_OUT, data)
    print(f"Wrote dashboard JSON to {JSON_OUT}")
    print(f"Wrote dashboard HTML to {HTML_OUT}")


if __name__ == "__main__":
    main()
