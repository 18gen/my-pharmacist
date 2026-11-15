"""Makes the QR codes for the keychain's medication cards: one PNG per card in qr/, and
keychain-qr-letter.pdf with all four at 25 mm for printing and cutting out.

Scanning a card's code in My Pharmacist ("Scan a card", or the iPhone's Camera) adds
that medication with its pill pictures and the times printed here. Each code is one line
of text, a link the app knows how to read:

    mypharmacist://add?v=1&id=<medication>&t=<HHMM,HHMM>     taken at set times
    mypharmacist://add?v=1&id=<medication>&prn=1             taken only when needed

The four lines below are the app's sample list. `MedicationCardTests.keychain` holds the
same four and checks that the app writes them from its own list, so a card printed from
here and the app can't drift apart: change both together.

Run from the repository root:  python3 design/keychain/make_card_qr.py
Needs Pillow and reportlab.
"""

from pathlib import Path

from PIL import Image
from reportlab.graphics.barcode import qrencoder
from reportlab.lib.colors import black
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

HERE = Path(__file__).parent

# (the code's text, the name and strength, when it is taken)
CARDS = [
    ("mypharmacist://add?v=1&id=capecitabine-500&t=1230,2000", "Capecitabine 500 mg", "12:30 PM · 8:00 PM"),
    ("mypharmacist://add?v=1&id=dexamethasone-4&t=1230", "Dexamethasone 4 mg", "12:30 PM"),
    ("mypharmacist://add?v=1&id=allopurinol-300&t=2000", "Allopurinol 300 mg", "8:00 PM"),
    ("mypharmacist://add?v=1&id=ondansetron-8&prn=1", "Ondansetron 8 mg", "Only when you feel sick"),
]

QUIET = 4            # clear squares around the code, as the QR standard asks
PIXELS_PER_SQUARE = 16
CODE_SIDE = 25 * mm  # the printed code, clear margin included


def squares(text):
    """The code as rows of True (black) and False (white), without its margin."""
    # Medium error correction: still read with a scratch or a keyring's scuff.
    code = qrencoder.QRCode(None, qrencoder.QRErrorCorrectLevel.M)
    code.addData(text)
    code.make()
    return [[bool(cell) for cell in row] for row in code.modules]


def save_png(rows, path):
    count = len(rows) + 2 * QUIET
    image = Image.new("1", (count, count), 1)
    for y, row in enumerate(rows):
        for x, is_black in enumerate(row):
            if is_black:
                image.putpixel((x + QUIET, y + QUIET), 0)
    image.resize((count * PIXELS_PER_SQUARE,) * 2, Image.NEAREST).save(path)


def draw(page, rows, left, bottom):
    """Draws the code with its margin in a `CODE_SIDE` square whose corner is given."""
    side = CODE_SIDE / (len(rows) + 2 * QUIET)
    page.setFillColor(black)
    for y, row in enumerate(rows):
        for x, is_black in enumerate(row):
            if is_black:
                page.rect(left + (x + QUIET) * side, bottom + CODE_SIDE - (y + QUIET + 1) * side,
                          side, side, stroke=0, fill=1)


def main():
    (HERE / "qr").mkdir(exist_ok=True)
    width, height = letter
    page = canvas.Canvas(str(HERE / "keychain-qr-letter.pdf"), pagesize=letter)
    page.setTitle("My Pharmacist keychain card codes")
    page.setFont("Helvetica-Bold", 14)
    page.drawString(20 * mm, height - 20 * mm, "My Pharmacist: keychain card codes")
    page.setFont("Helvetica", 10)
    page.drawString(20 * mm, height - 26 * mm,
                    "Print at 100% (no scaling). Each code is 25 mm; cut on the grey line and glue it to its card.")

    for index, (text, name, when) in enumerate(CARDS):
        rows = squares(text)
        save_png(rows, HERE / "qr" / (text.split("id=")[1].split("&")[0] + ".png"))

        left = 20 * mm + (index % 2) * 90 * mm
        bottom = height - 70 * mm - (index // 2) * 55 * mm
        draw(page, rows, left, bottom)
        page.setStrokeGray(0.7)
        page.setDash(2, 2)
        page.rect(left, bottom, CODE_SIDE, CODE_SIDE, stroke=1, fill=0)
        page.setDash()
        page.setFillColor(black)
        page.setFont("Helvetica-Bold", 11)
        page.drawString(left + CODE_SIDE + 5 * mm, bottom + CODE_SIDE - 6 * mm, name)
        page.setFont("Helvetica", 10)
        page.drawString(left + CODE_SIDE + 5 * mm, bottom + CODE_SIDE - 12 * mm, when)
        print(text)

    page.save()


if __name__ == "__main__":
    main()
