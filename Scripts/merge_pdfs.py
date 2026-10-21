"""Merge PDF files into one, in the order given, with a bookmark per input.

Usage: python merge_pdfs.py <output.pdf> <title>=<input.pdf> [<title>=<input.pdf> ...]

Called by export_bd_pdf.tcl. Requires pypdf (pip install pypdf).
"""
import logging
import sys

# Vivado's PDFs contain some null object references; pypdf handles them but
# logs a warning for each, which is noise here.
logging.getLogger("pypdf").setLevel(logging.ERROR)

try:
    from pypdf import PdfWriter
except ImportError:
    sys.exit("merge_pdfs.py: pypdf is not installed. Run: python -m pip install pypdf")


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    output = argv[1]
    writer = PdfWriter()
    for arg in argv[2:]:
        title, sep, path = arg.partition("=")
        if not sep:
            sys.exit(f"merge_pdfs.py: expected <title>=<file>, got {arg!r}")
        writer.append(path, outline_item=title)
    writer.page_mode = "/UseOutlines"
    with open(output, "wb") as f:
        writer.write(f)


if __name__ == "__main__":
    main(sys.argv)
