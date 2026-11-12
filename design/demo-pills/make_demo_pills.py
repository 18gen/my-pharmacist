"""Makes demo-pills-letter.pdf (the debug demos' pills) and sample-list-pills-letter.pdf
(what "Load sample list" loads, for App Review): the app's sample tablets at actual size on one US Letter
page, for printing and cutting out as demo pills.

Each tablet is a fold pair: its front and its back side by side, mirrored about a dotted
fold line. Cut the pair out loosely, fold it on the line with the pictures outward (a
piece of card glued inside gives it some thickness), then cut along the tablet's edge
through both layers: the two sides line up. Folding turns the back half over rather than
mirroring it, so its imprint reads the right way round.

The pictures are the app's own reference photos of its sample list, from the ePillID
benchmark (NIH NLM images), so a printed pill looks like what the app compares against.

Run from the repository root:  python3 design/demo-pills/make_demo_pills.py
Needs Pillow and reportlab.
"""

from pathlib import Path

from PIL import Image
from reportlab.lib.colors import Color, black
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parents[2]
PILLS = ROOT / "MyPharmacist" / "Resources" / "Assets.xcassets" / "Pills"
HERE = Path(__file__).resolve().parent

# Longest side of each tablet, from its FDA label (SPL "size", via RxNav) by NDC. The
# pictures are ePillID's reference photos (NIH NLM), front and back; the ondansetron's
# are C3PI's (front, front, back, back).
TABLETS = [
    # (asset name, name, strength, when the sample patient takes it, size mm, front photo, back photo, rows)
    ("exemestane-25", "Exemestane", "25 mg", "8 AM", 6, 1, 2, 2),
    ("dexamethasone-1-5", "Dexamethasone", "1.5 mg", "8 AM", 6, 1, 2, 2),
    ("metoclopramide-10", "Metoclopramide", "10 mg", "8 AM and 8 PM", 8, 1, 2, 2),
    ("ondansetron-8", "Ondansetron", "8 mg", "only when feeling sick", 13, 1, 3, 2),
]

# What "Load sample list" loads, for App Review: its photos are from NLM C3PI (four
# per tablet; the front and back picked by eye). Xeloda's label gives 11 mm for both
# strengths, and that is what is printed.
SAMPLE_LIST = [
    ("capecitabine-500", "Capecitabine", "500 mg", "12:30 PM and 8 PM", 11, 1, 3, 2),
    ("dexamethasone-4", "Dexamethasone", "4 mg", "12:30 PM", 6, 1, 3, 2),
    ("allopurinol-300", "Allopurinol", "300 mg", "8 PM", 11, 1, 2, 2),
    ("ondansetron-8", "Ondansetron", "8 mg", "only when feeling sick", 13, 1, 3, 2),
]

SHEETS = [
    # (file, tablets, what the tablets are, where their photos come from)
    ("demo-pills-letter.pdf", TABLETS, "demo pills",
     "ePillID benchmark (NIH NLM Pillbox and Pill Image Recognition Challenge images)"),
    ("sample-list-pills-letter.pdf", SAMPLE_LIST, "sample list pills",
     "NIH NLM C3PI and ePillID images"),
]

FOLD_GAP = 2 * mm      # from the fold line to each side's tablet edge
PAIR_SPACING = 9 * mm  # between fold pairs in a row
ROW_SPACING = 10 * mm  # between rows of the same tablet, room for the front/back labels
MARGIN = 14 * mm
GREY = Color(0.45, 0.45, 0.45)
LIGHT = Color(0.7, 0.7, 0.7)


def tablet(asset: str, side: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """The photo (tablet on a transparent background) and the tablet's box in it."""
    image = Image.open(PILLS / f"{asset}-{side}.imageset" / f"{asset}-{side}.png").convert("RGBA")
    box = image.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    return image, box


def draw_side(c: canvas.Canvas, image: Image.Image, box, size_mm: float, centre_x: float, centre_y: float) -> None:
    """Draws one side so the tablet's longest side measures `size_mm`, centred on the point."""
    left, top, right, bottom = box
    points_per_pixel = size_mm * mm / max(right - left, bottom - top)
    width, height = image.width * points_per_pixel, image.height * points_per_pixel
    # The tablet's centre in the photo, measured from the photo's bottom-left (PDF origin).
    tablet_x = (left + right) / 2 * points_per_pixel
    tablet_y = (image.height - (top + bottom) / 2) * points_per_pixel
    c.drawImage(ImageReader(image), centre_x - tablet_x, centre_y - tablet_y, width, height, mask="auto")


def tablet_extent(box, size_mm: float) -> tuple[float, float]:
    """The tablet's width and height on paper, in points."""
    left, top, right, bottom = box
    longest = max(right - left, bottom - top)
    return (right - left) / longest * size_mm * mm, (bottom - top) / longest * size_mm * mm


def make_sheet(out: Path, tablets, title: str, photo_source: str) -> None:
    page_width, page_height = letter
    c = canvas.Canvas(str(out), pagesize=letter)
    c.setTitle(f"My Pharmacist {title}")
    c.setAuthor("My Pharmacist")

    y = page_height - MARGIN
    c.setFont("Helvetica-Bold", 17)
    c.drawString(MARGIN, y - 4 * mm, f"My Pharmacist · {title} (actual size)")
    y -= 11 * mm

    c.setFont("Helvetica", 9.5)
    steps = [
        "1.  Print at 100% (\"Actual size\"), on matte paper if you can: glossy paper reflects light into the camera.",
        "2.  Check the scale bar below measures exactly 5 cm. If not, the printer scaled the page.",
        "3.  Cut out a front-and-back pair loosely, keeping the two halves joined.",
        "4.  Fold on the dotted line with the pictures outward. Glue a piece of card inside for thickness.",
        "5.  Cut along the tablet's edge through both layers. Front and back line up.",
        "Not real medicine: printed stand-ins of the app's sample tablets, for demos only.",
    ]
    for line in steps:
        c.drawString(MARGIN, y, line)
        y -= 5 * mm

    # Scale bar: 5 cm with centimetre ticks.
    y -= 2 * mm
    c.setStrokeColor(black)
    c.setLineWidth(0.8)
    c.line(MARGIN, y, MARGIN + 50 * mm, y)
    for cm in range(6):
        tick = 2.5 * mm if cm in (0, 5) else 1.5 * mm
        c.line(MARGIN + cm * 10 * mm, y, MARGIN + cm * 10 * mm, y + tick)
    c.setFont("Helvetica", 8)
    c.drawString(MARGIN + 52 * mm, y - 1, "5 cm")
    y -= 10 * mm

    for asset, name, strength, when, size_mm, front_side, back_side, rows in tablets:
        front, front_box = tablet(asset, front_side)
        back, back_box = tablet(asset, back_side)
        tablet_width, tablet_height = tablet_extent(front_box, size_mm)

        c.setFillColor(black)
        c.setFont("Helvetica-Bold", 12)
        c.drawString(MARGIN, y, f"{name} {strength}")
        title_width = c.stringWidth(f"{name} {strength}", "Helvetica-Bold", 12)
        c.setFont("Helvetica", 9.5)
        c.setFillColor(GREY)
        c.drawString(MARGIN + title_width + 3 * mm, y, f"{size_mm} mm  ·  taken {when}")
        y -= 4 * mm + tablet_height / 2 + 2 * mm

        pair_width = 2 * (tablet_width + FOLD_GAP)
        # As many pairs as fit across the page, in full rows: spares, since small pieces get lost.
        per_row = int((page_width - 2 * MARGIN + PAIR_SPACING) // (pair_width + PAIR_SPACING))
        for copy in range(per_row * rows):
            row, column = divmod(copy, per_row)
            if column == 0 and row > 0:
                y -= tablet_height + ROW_SPACING
            fold_x = MARGIN + column * (pair_width + PAIR_SPACING) + pair_width / 2
            draw_side(c, front, front_box, size_mm, fold_x - FOLD_GAP - tablet_width / 2, y)
            draw_side(c, back, back_box, size_mm, fold_x + FOLD_GAP + tablet_width / 2, y)
            # Dotted fold line, a little longer than the tablet.
            c.setStrokeColor(LIGHT)
            c.setLineWidth(0.6)
            c.setDash(1.2, 1.6)
            c.line(fold_x, y - tablet_height / 2 - 2 * mm, fold_x, y + tablet_height / 2 + 2 * mm)
            c.setDash()
            if copy == 0:
                c.setFillColor(GREY)
                c.setFont("Helvetica", 7)
                label_y = y - tablet_height / 2 - 5 * mm
                c.drawCentredString(fold_x - FOLD_GAP - tablet_width / 2, label_y, "front")
                c.drawCentredString(fold_x + FOLD_GAP + tablet_width / 2, label_y, "back")
        y -= tablet_height / 2 + 13 * mm

    c.setFillColor(GREY)
    c.setFont("Helvetica", 7.5)
    c.drawString(MARGIN, MARGIN - 4 * mm,
                 f"Photos: {photo_source}. Sizes: FDA labels via RxNorm.")
    c.showPage()
    c.save()
    print(f"Wrote {out.relative_to(ROOT)}")


def main() -> None:
    for file, tablets, title, photo_source in SHEETS:
        make_sheet(HERE / file, tablets, title, photo_source)


if __name__ == "__main__":
    main()
