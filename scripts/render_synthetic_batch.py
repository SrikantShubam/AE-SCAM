import argparse
import csv
import random
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BATCH_MANIFEST = ROOT / "data" / "interim" / "manifests" / "synthetic_batch_v0_1.csv"
DEFAULT_SEED_POOL = ROOT / "data" / "interim" / "normalized" / "seed_pool_v0_1.csv"
DEFAULT_OUTPUT_DIR = ROOT / "data" / "synthetic" / "renders" / "v0_1"
DEFAULT_RENDER_MANIFEST = ROOT / "data" / "interim" / "manifests" / "synthetic_render_manifest.csv"

CANVAS_BY_CHANNEL: Dict[str, Tuple[int, int]] = {
    "sms": (1080, 1920),
    "whatsapp": (1080, 1920),
    "email": (1440, 2160),
}

BACKGROUND_BY_CHANNEL: Dict[str, Tuple[int, int, int]] = {
    "sms": (247, 247, 247),
    "whatsapp": (230, 238, 230),
    "email": (245, 247, 251),
}

BUBBLE_BY_LABEL: Dict[str, Tuple[int, int, int]] = {
    "scam": (230, 243, 255),
    "not_scam": (236, 236, 236),
    "unclear": (252, 245, 226),
}

TEXT_BY_CHANNEL: Dict[str, Tuple[int, int, int]] = {
    "sms": (18, 18, 18),
    "whatsapp": (18, 18, 18),
    "email": (32, 42, 59),
}

HEADER_BY_MARKET: Dict[str, List[str]] = {
    "india": [
        "HDFCBK",
        "ICICIB",
        "AXISBK",
        "VM-JIOTEL",
        "VK-AMAZON",
        "AD-AIRTEL",
        "BZ-PAYTM",
        "VM-SBIUPI",
    ],
    "us": [
        "Chase Alerts",
        "Amazon Support",
        "Apple Security",
        "FedEx Notice",
        "Bank of America",
        "USPS Delivery",
        "Medicare Desk",
        "Wells Fargo",
    ],
    "unknown": [
        "Service Alert",
        "Account Support",
        "Delivery Team",
    ],
}

SUBJECT_BY_LABEL = {
    "scam": "Urgent action required on your account",
    "not_scam": "Account activity summary",
    "unclear": "Important service message",
}


@dataclass
class SeedRow:
    seed_id: str
    source_name: str
    ground_truth_label: str
    message_text_gold: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render synthetic message screenshots for OCR benchmarking.")
    parser.add_argument("--batch-manifest", default=str(DEFAULT_BATCH_MANIFEST))
    parser.add_argument("--seed-pool", default=str(DEFAULT_SEED_POOL))
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--render-manifest", default=str(DEFAULT_RENDER_MANIFEST))
    parser.add_argument("--limit", type=int, default=None, help="Optional cap on rendered rows.")
    return parser.parse_args()


def load_seed_pool(path: Path) -> Dict[str, SeedRow]:
    seeds: Dict[str, SeedRow] = {}
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            seeds[row["seed_id"]] = SeedRow(
                seed_id=row["seed_id"],
                source_name=row["source_name"],
                ground_truth_label=row["ground_truth_label"],
                message_text_gold=row["message_text_gold"],
            )
    return seeds


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_candidates = [
        "arial.ttf",
        "segoeui.ttf",
        "calibri.ttf",
        "DejaVuSans.ttf",
    ]
    for candidate in font_candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def choose_sender(market: str, channel: str, rng: random.Random) -> str:
    pool = HEADER_BY_MARKET.get(market, HEADER_BY_MARKET["unknown"])
    sender = rng.choice(pool)
    if channel == "email" and "@" not in sender:
        local = sender.lower().replace(" ", ".")
        domain = "mail.example.com" if market == "us" else "alerts.example.in"
        return f"{local}@{domain}"
    return sender


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> List[str]:
    words = text.replace("\r", " ").replace("\n", " ").split()
    if not words:
        return [""]

    lines: List[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        box = draw.textbbox((0, 0), candidate, font=font)
        if box[2] - box[0] <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def bubble_rect(channel: str, image_size: Tuple[int, int], line_count: int) -> Tuple[int, int, int, int]:
    width, height = image_size
    if channel == "email":
        left = int(width * 0.08)
        right = int(width * 0.92)
        top = 300
        bottom = min(height - 180, top + 220 + line_count * 58)
        return left, top, right, bottom

    left = int(width * 0.08)
    right = int(width * 0.86)
    top = 340
    bottom = min(height - 220, top + 150 + line_count * 56)
    return left, top, right, bottom


def apply_quality(image: Image.Image, quality_tier: str, rng: random.Random) -> Tuple[Image.Image, str]:
    if quality_tier == "clean":
        return image, "none"

    operations: List[str] = []
    processed = image
    if quality_tier in {"medium", "hard"}:
        processed = processed.filter(ImageFilter.GaussianBlur(radius=0.6 if quality_tier == "medium" else 1.2))
        operations.append("gaussian_blur")

        brightness = 1.03 if quality_tier == "medium" else 0.96
        processed = processed.point(lambda p: max(0, min(255, int(p * brightness))))
        operations.append("brightness_shift")

    if quality_tier == "hard":
        rotated = processed.rotate(rng.uniform(-1.5, 1.5), expand=False, fillcolor=BACKGROUND_BY_CHANNEL["sms"])
        processed = rotated
        operations.append("minor_rotation")

        overlay = Image.new("RGBA", processed.size, (255, 255, 255, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        for _ in range(140):
            x = rng.randint(0, processed.size[0] - 1)
            y = rng.randint(0, processed.size[1] - 1)
            shade = rng.randint(220, 245)
            overlay_draw.point((x, y), fill=(shade, shade, shade, 50))
        processed = Image.alpha_composite(processed.convert("RGBA"), overlay).convert("RGB")
        operations.append("speckle_noise")

    return processed, ",".join(operations)


def render_row(row: Dict[str, str], seed: SeedRow, output_dir: Path) -> Dict[str, str]:
    render_id = row["render_id"]
    market = row["market"]
    channel = row["channel"]
    quality_tier = row["quality_tier"]
    label = row["ground_truth_label"]
    width, height = CANVAS_BY_CHANNEL[channel]
    rng = random.Random(render_id)

    image = Image.new("RGB", (width, height), BACKGROUND_BY_CHANNEL[channel])
    draw = ImageDraw.Draw(image)
    title_font = load_font(44 if channel != "email" else 40)
    body_font = load_font(38 if channel != "email" else 34)
    meta_font = load_font(26)
    small_font = load_font(22)

    sender = choose_sender(market, channel, rng)
    message = seed.message_text_gold.strip()
    if channel == "email":
        draw.rectangle([(0, 0), (width, 112)], fill=(255, 255, 255))
        draw.text((70, 40), "Inbox", fill=(20, 20, 20), font=title_font)
        draw.text((100, 170), SUBJECT_BY_LABEL[label], fill=(32, 42, 59), font=title_font)
        draw.text((100, 228), f"From: {sender}", fill=(80, 92, 112), font=meta_font)
    elif channel == "whatsapp":
        draw.rectangle([(0, 0), (width, 150)], fill=(18, 140, 126))
        draw.text((90, 48), sender, fill=(255, 255, 255), font=title_font)
        draw.text((90, 98), "online", fill=(230, 255, 246), font=small_font)
    else:
        draw.rectangle([(0, 0), (width, 154)], fill=(255, 255, 255))
        draw.text((70, 56), sender, fill=(22, 22, 22), font=title_font)
        draw.text((70, 108), "Today 10:14 AM", fill=(102, 102, 102), font=small_font)

    max_text_width = int(width * 0.68) if channel != "email" else int(width * 0.76)
    lines = wrap_text(draw, message, body_font, max_text_width)
    left, top, right, bottom = bubble_rect(channel, (width, height), len(lines))
    draw.rounded_rectangle((left, top, right, bottom), radius=36, fill=BUBBLE_BY_LABEL[label])

    y = top + 34
    for line in lines:
        draw.text((left + 28, y), line, fill=TEXT_BY_CHANNEL[channel], font=body_font)
        y += 50

    draw.text((right - 140, bottom - 46), "10:14", fill=(111, 111, 111), font=small_font)

    processed, quality_ops = apply_quality(image, quality_tier, rng)

    channel_dir = output_dir / channel / market / quality_tier
    ensure_dir(channel_dir)
    relative_path = Path("data") / "synthetic" / "renders" / "v0_1" / channel / market / quality_tier / f"{render_id}.png"
    output_path = ROOT / relative_path
    processed.save(output_path, format="PNG")

    return {
        "render_id": render_id,
        "source_name": row["source_name"],
        "source_sample_id": row["source_sample_id"],
        "seed_id": seed.seed_id,
        "ground_truth_label": label,
        "market": market,
        "channel": channel,
        "quality_tier": quality_tier,
        "template_family": row["template_family"],
        "curation_status": row["curation_status"],
        "output_path": str(relative_path).replace("\\", "/"),
        "image_width": str(width),
        "image_height": str(height),
        "sender_display": sender,
        "quality_operations": quality_ops,
    }


def write_manifest(rows: List[Dict[str, str]], output_path: Path) -> None:
    ensure_dir(output_path.parent)
    fieldnames = [
        "render_id",
        "source_name",
        "source_sample_id",
        "seed_id",
        "ground_truth_label",
        "market",
        "channel",
        "quality_tier",
        "template_family",
        "curation_status",
        "output_path",
        "image_width",
        "image_height",
        "sender_display",
        "quality_operations",
    ]
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    batch_manifest = Path(args.batch_manifest)
    seed_pool = Path(args.seed_pool)
    output_dir = Path(args.output_dir)
    render_manifest = Path(args.render_manifest)

    ensure_dir(output_dir)
    seeds = load_seed_pool(seed_pool)
    rendered_rows: List[Dict[str, str]] = []

    with batch_manifest.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    ready_rows = [row for row in rows if row["curation_status"] == "ready_for_render"]
    if args.limit is not None:
        ready_rows = ready_rows[: args.limit]

    for row in ready_rows:
        seed = seeds.get(row["source_sample_id"])
        if seed is None:
            raise KeyError(f"Seed row not found for {row['source_sample_id']}")
        rendered_rows.append(render_row(row, seed, output_dir))

    write_manifest(rendered_rows, render_manifest)
    print(f"Rendered {len(rendered_rows)} images to {output_dir}")
    print(f"Render manifest written to {render_manifest}")


if __name__ == "__main__":
    main()
