#!/usr/bin/env python3
"""Quick setup for koompi-office dependencies. Run once."""
import subprocess, sys, os

packages = [
    "openpyxl",       # read/write xlsx
    "pandas",         # data analysis
    "xlsxwriter",     # create xlsx (alternative engine)
    "pdfplumber",     # read PDF
    "reportlab",      # create PDF
    "python-docx",    # read/write docx
    "python-pptx",    # read/write pptx
    "Pillow",         # image processing
    "matplotlib",     # charts & graphs
    "qrcode",         # QR code generation
    "python-barcode", # barcode generation
    # OCR handled via Gemini vision (no extra package needed)
]

PIP_FLAGS = ["--break-system-packages"]

print("Installing koompi-office dependencies...")

try:
    import pip
except ImportError:
    print("pip not found, bootstrapping...")
    get_pip = "/tmp/get-pip.py"
    if not os.path.exists(get_pip):
        import urllib.request
        urllib.request.urlretrieve("https://bootstrap.pypa.io/get-pip.py", get_pip)
    subprocess.run([sys.executable, get_pip] + PIP_FLAGS, capture_output=True, text=True)

result = subprocess.run(
    [sys.executable, "-m", "pip", "install"] + PIP_FLAGS + ["-q"] + packages,
    capture_output=True, text=True
)
if result.returncode != 0:
    print(f"ERROR: {result.stderr}")
    sys.exit(1)

# OCR uses Gemini vision via KConsole AI Gateway — no system dependency needed

missing = []
for pkg in ["openpyxl", "pandas", "xlsxwriter", "pdfplumber", "reportlab", "docx", "pptx", "PIL", "matplotlib", "qrcode", "barcode"]:
    try:
        __import__(pkg)
    except ImportError:
        missing.append(pkg)

if missing:
    print(f"WARNING: Failed to install: {missing}")
else:
    print(f"✅ All {len(packages)} packages installed successfully")
