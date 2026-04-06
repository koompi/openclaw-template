---
name: koompi-office
description: Read, create, analyze, and convert office documents and media. Covers Excel (.xlsx/.csv), PDF, Word (.docx), PowerPoint (.pptx), images, charts, QR codes, barcodes, and OCR. Use when the user asks to: (1) read/create/edit spreadsheets, (2) read/create PDF reports, (3) read/create Word documents, (4) read/create PowerPoint presentations, (5) resize/crop/convert/compress images, (6) generate charts or graphs, (7) generate QR codes or barcodes, (8) extract text from images (OCR), (9) convert between any formats, (10) any document processing, data manipulation, or file format work. Triggers on phrases like "read excel", "create xlsx", "make a PDF", "create word", "powerpoint", "pptx", "resize image", "generate chart", "make QR code", "barcode", "OCR", "extract text from image", "office document", "convert file", "report", "invoice".
---

# KOOMPI Office — Document & Media Processing

## Setup

```bash
python3 scripts/setup.py
```

Or manually:
```bash
pip install --break-system-packages openpyxl pandas xlsxwriter pdfplumber reportlab python-docx python-pptx Pillow matplotlib qrcode python-barcode pytesseract
apt-get install -y tesseract-ocr  # required for OCR
```

Verify:
```python
import openpyxl, pandas, pdfplumber, reportlab, docx, pptx
from PIL import Image
import matplotlib, qrcode, barcode
```

---

## Excel (.xlsx)

### Reading

```python
import pandas as pd

df = pd.read_excel('input.xlsx', sheet_name='Sheet1')
# All sheets: pd.read_excel('input.xlsx', sheet_name=None)
# Specific columns: pd.read_excel('input.xlsx', usecols='A:D', skiprows=2)
```

### Creating

```python
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "Report"

header_fill = PatternFill(start_color="E81B25", end_color="E81B25", fill_type="solid")
header_font = Font(bold=True, color="FFFFFF", size=12)
for col, val in enumerate(headers, 1):
    cell = ws.cell(row=1, column=col, value=val)
    cell.font = header_font
    cell.fill = header_fill
    cell.alignment = Alignment(horizontal="center")

for row_idx, row_data in enumerate(data, 2):
    for col_idx, val in enumerate(row_data, 1):
        ws.cell(row=row_idx, column=col_idx, value=val)

for col in ws.columns:
    max_len = max(len(str(cell.value or "")) for cell in col)
    ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 50)

wb.save('output.xlsx')
```

### Data Analysis

```python
import pandas as pd

df = pd.read_excel('data.xlsx')
df.describe()
filtered = df[df['price'] > 100]
summary = df.groupby('category')['revenue'].sum().reset_index()
pivot = df.pivot_table(values='amount', index='category', columns='month', aggfunc='sum')
summary.to_excel('summary.xlsx', index=False)
```

---

## PDF

### Reading

```python
import pdfplumber

with pdfplumber.open('document.pdf') as pdf:
    full_text = "".join(page.extract_text() or "" for page in pdf.pages)
    for page in pdf.pages:
        for table in page.extract_tables():
            ...  # list of lists
```

### Creating

```python
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image as RLImage
from reportlab.lib.styles import getSampleStyleSheet

doc = SimpleDocTemplate("report.pdf", pagesize=A4,
                         leftMargin=20*mm, rightMargin=20*mm,
                         topMargin=20*mm, bottomMargin=20*mm)
styles = getSampleStyleSheet()
elements = []

elements.append(Paragraph("Report Title", styles['Title']))
elements.append(Spacer(1, 10*mm))

# Table
table_data = [["Name", "Amount"], ["Item A", "$100"]]
table = Table(table_data, colWidths=[80*mm, 60*mm])
table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E81B25')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
    ('FONTSIZE', (0, 0), (-1, -1), 10),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9fafb')]),
    ('TOPPADDING', (0, 0), (-1, -1), 6),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
]))
elements.append(table)

# Embed an image
elements.append(Spacer(1, 10*mm))
elements.append(RLImage('chart.png', width=150*mm, height=80*mm))

doc.build(elements)
```

For ready-made templates (invoice, summary), see [references/report-templates.md](references/report-templates.md).

---

## Word (.docx)

### Reading

```python
from docx import Document

doc = Document('input.docx')
full_text = "\n".join(p.text for p in doc.paragraphs)
for table in doc.tables:
    for row in table.rows:
        cells = [cell.text for cell in row.cells]
```

### Creating

```python
from docx import Document
from docx.shared import Inches, Pt, RGBColor

doc = Document()
doc.add_heading('Report Title', level=0)

p = doc.add_paragraph()
p.add_run('Normal text. ').bold = False
p.add_run('Bold text.').bold = True

# Colored heading
run = doc.add_paragraph().add_run('KOOMPI Red Heading')
run.font.size = Pt(16)
run.font.color.rgb = RGBColor(0xE8, 0x1B, 0x25)

# Table
table = doc.add_table(rows=4, cols=3, style='Light Grid Accent 1')
table.rows[0].cells[0].text = "Name"

# Bullet list
doc.add_paragraph('Item one', style='List Bullet')

doc.add_page_break()
doc.save('output.docx')
```

### Editing (Find & Replace)

```python
from docx import Document

doc = Document('template.docx')
for p in doc.paragraphs:
    if '{{NAME}}' in p.text:
        p.text = p.text.replace('{{NAME}}', 'Hangsia')
for table in doc.tables:
    for row in table.rows:
        for cell in row.cells:
            for p in cell.paragraphs:
                if '{{DATE}}' in p.text:
                    p.text = p.text.replace('{{DATE}}', '2026-04-05')
doc.save('filled.docx')
```

---

## PowerPoint (.pptx)

### Reading

```python
from pptx import Presentation

prs = Presentation('input.pptx')
for slide_num, slide in enumerate(prs.slides, 1):
    for shape in slide.shapes:
        if shape.has_text_frame:
            for p in shape.text_frame.paragraphs:
                print(f"Slide {slide_num}: {p.text}")
```

### Creating

```python
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
blank = prs.slide_layouts[6]

# Title slide
slide = prs.slides.add_slide(blank)
txBox = slide.shapes.add_textbox(Inches(1), Inches(2.5), Inches(11), Inches(2))
tf = txBox.text_frame
tf.word_wrap = True
p = tf.paragraphs[0]
p.text = "KOOMPI Office"
p.font.size = Pt(44)
p.font.bold = True
p.font.color.rgb = RGBColor(0xE8, 0x1B, 0x25)
p.alignment = PP_ALIGN.CENTER

# Content slide
slide = prs.slides.add_slide(blank)
txBox = slide.shapes.add_textbox(Inches(1), Inches(1), Inches(11), Inches(5))
tf = txBox.text_frame
tf.word_wrap = True
p = tf.paragraphs[0]
p.text = "Key Points"
p.font.size = Pt(28)
p.font.bold = True
for point in ["Point one", "Point two", "Point three"]:
    p = tf.add_paragraph()
    p.text = point
    p.font.size = Pt(18)
    p.space_after = Pt(8)

# Table slide
slide = prs.slides.add_slide(blank)
tbl = slide.shapes.add_table(3, 3, Inches(1), Inches(1.5), Inches(11), Inches(4)).table
tbl.cell(0, 0).text = "Header"
tbl.cell(1, 0).text = "Data A"
for i in range(3):
    cell = tbl.cell(0, i)
    for p in cell.text_frame.paragraphs:
        p.font.bold = True
        p.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    cell.fill.solid()
    cell.fill.fore_color.rgb = RGBColor(0xE8, 0x1B, 0x25)

prs.save('output.pptx')
```

---

## Image Processing

Resize, crop, convert, compress, watermark.

```python
from PIL import Image, ImageDraw, ImageFont

# Open & info
img = Image.open('photo.jpg')
print(img.size, img.format, img.mode)

# Resize (keep aspect ratio)
img.thumbnail((800, 800))
img.save('photo_small.jpg', quality=85)

# Resize to exact dimensions
img_resized = img.resize((1920, 1080), Image.Resampling.LANCZOS)

# Crop
cropped = img.crop((100, 100, 500, 400))  # left, top, right, bottom

# Convert format
img.save('photo.png')          # JPG → PNG
img.save('photo.webp', quality=80)  # → WebP

# Compress
img.save('compressed.jpg', quality=60, optimize=True)

# Watermark
watermark = Image.new('RGBA', img.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(watermark)
draw.text((10, 10), "KOOMPI", fill=(255, 255, 255, 128))
img_rgba = img.convert('RGBA')
result = Image.alpha_composite(img_rgba, watermark)
result.convert('RGB').save('watermarked.jpg')

# Batch resize all images in a folder
from pathlib import Path
for f in Path('./images').glob('*.jpg'):
    img = Image.open(f)
    img.thumbnail((800, 800))
    img.save(f'output/{f.stem}_small.jpg', quality=85)

# Rotate / Flip
img.rotate(90).save('rotated.jpg')
img.transpose(Image.FLIP_HORIZONTAL).save('flipped.jpg')
```

---

## Charts & Graphs

Generate charts as images or embed in PDF/DOCX/PPTX.

```python
import matplotlib
matplotlib.use('Agg')  # headless mode (no display)
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# Bar chart
fig, ax = plt.subplots(figsize=(10, 5))
categories = ['Q1', 'Q2', 'Q3', 'Q4']
values = [1200, 1900, 3000, 2500]
bars = ax.bar(categories, values, color='#E81B25', width=0.6)
ax.set_title('Quarterly Revenue', fontsize=16, fontweight='bold')
ax.set_ylabel('Revenue ($)', fontsize=12)
for bar, val in zip(bars, values):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 50, f'${val:,}', ha='center', fontsize=11)
plt.tight_layout()
plt.savefig('bar_chart.png', dpi=150, bbox_inches='tight')
plt.close()

# Pie chart
fig, ax = plt.subplots(figsize=(8, 8))
labels = ['Product A', 'Product B', 'Product C', 'Product D']
sizes = [40, 25, 20, 15]
ax.pie(sizes, labels=labels, autopct='%1.1f%%', colors=['#E81B25', '#FF6B00', '#3b82f6', '#10b981'],
       startangle=90, textprops={'fontsize': 12})
ax.set_title('Market Share', fontsize=16, fontweight='bold')
plt.savefig('pie_chart.png', dpi=150, bbox_inches='tight')
plt.close()

# Line chart
fig, ax = plt.subplots(figsize=(10, 5))
months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
sales = [100, 150, 180, 220, 280, 350]
ax.plot(months, sales, marker='o', linewidth=2, color='#E81B25', markersize=8)
ax.fill_between(months, sales, alpha=0.1, color='#E81B25')
ax.set_title('Monthly Sales Trend', fontsize=16, fontweight='bold')
ax.set_ylabel('Sales ($)', fontsize=12)
ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'${x:,.0f}'))
plt.savefig('line_chart.png', dpi=150, bbox_inches='tight')
plt.close()

# Chart from Excel data
import pandas as pd
df = pd.read_excel('sales.xlsx')
df.plot(x='month', y='revenue', kind='bar', color='#E81B25', figsize=(10, 5))
plt.title('Revenue by Month')
plt.savefig('from_excel.png', dpi=150, bbox_inches='tight')
plt.close()
```

---

## QR Codes

```python
import qrcode
from PIL import Image

# Basic QR code
qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=10, border=4)
qr.add_data('https://koompi.cloud')
qr.make(fit=True)
img = qr.make_image(fill_color='#E81B25', back_color='white')
img.save('qrcode.png')

# Styled QR with logo
qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=10, border=4)
qr.add_data('https://koompi.cloud')
qr.make(fit=True)
qr_img = qr.make_image(fill_color='#E81B25', back_color='white').convert('RGBA')
logo = Image.open('logo.png').resize((60, 60))
pos = ((qr_img.size[0] - logo.size[0]) // 2, (qr_img.size[1] - logo.size[1]) // 2)
qr_img.paste(logo, pos, mask=logo)
qr_img.save('qrcode_logo.png')

# Batch QR codes from Excel
import pandas as pd
df = pd.read_excel('products.xlsx')
for _, row in df.iterrows():
    qr = qrcode.make(row['url'])
    qr.save(f"qr_{row['id']}.png")
```

---

## Barcodes

```python
from barcode import get_barcode_class
from barcode.writer import ImageWriter

# Code 128 (any text)
EAN = get_barcode_class('code128')
barcode = EAN('KOOMPI-2026-001', writer=ImageWriter())
barcode.save('barcode_code128')

# EAN-13 (requires 12 digits)
EAN = get_barcode_class('ean13')
ean = EAN('123456789012', writer=ImageWriter())
ean.save('barcode_ean13')

# UPC-A (requires 11 digits)
UPC = get_barcode_class('upc')
upc = UPC('12345678901', writer=ImageWriter())
upc.save('barcode_upc')

# Custom styling
barcode = EAN('KOOMPI-001', writer=ImageWriter())
options = {'module_width': 0.4, 'module_height': 15, 'font_size': 12, 'text_distance': 5}
barcode.save('barcode_styled', options=options)
```

---

## OCR (Text from Images)

Extract text from scanned documents, screenshots, or photos using Gemini vision via KConsole AI Gateway. Supports **English, Khmer, Chinese, Japanese**, and 50+ languages — no system packages needed.

```python
import base64, json, os, urllib.request

def ocr(image_path, lang="auto", api_key=None):
    """Extract text from an image using Gemini vision."""
    api_key = api_key or os.environ.get('KCONSOLE_API_KEY') or os.environ.get('KCONSOLE_AI_KEY')
    if not api_key:
        raise ValueError("Set KCONSOLE_API_KEY or KCONSOLE_AI_KEY env var")

    with open(image_path, 'rb') as f:
        img_b64 = base64.b64encode(f.read()).decode()

    mime = 'image/png' if image_path.endswith('.png') else 'image/jpeg'

    lang_hint = {
        'en': 'English', 'khm': 'Khmer', 'chi_sim': 'Chinese', 'jpn': 'Japanese',
        'auto': ''
    }.get(lang, lang)

    prompt = f"Extract all text from this image. Reply with only the extracted text, preserving layout."
    if lang_hint:
        prompt += f" The text is in {lang_hint}."

    payload = json.dumps({
        'model': 'gemini-2.5-flash',
        'messages': [{
            'role': 'user',
            'content': [
                {'type': 'text', 'text': prompt},
                {'type': 'image_url', 'image_url': {'url': f'data:{mime};base64,{img_b64}'}}
            ]
        }]
    }).encode()

    req = urllib.request.Request(
        'https://ai.koompi.cloud/v1/chat/completions',
        data=payload,
        headers={
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
            'X-BACKEND': 'gemini'
        }
    )
    resp = json.loads(urllib.request.urlopen(req, timeout=30).read())
    return resp['choices'][0]['message']['content']

# Basic usage
text = ocr('scanned_doc.png')
print(text)

# Specify language
text = ocr('khmer_receipt.jpg', lang='khm')

# PDF OCR (each page → image → OCR)
import pdfplumber
with pdfplumber.open('scanned.pdf') as pdf:
    for i, page in enumerate(pdf.pages):
        img_path = f'/tmp/page_{i}.png'
        page.to_image(resolution=300).save(img_path)
        text = ocr(img_path)
        print(f'--- Page {i+1} ---')
        print(text)
```

---

## Email Parsing (.eml)

```python
import email
from email import policy
from pathlib import Path

# Read .eml file
with open('email.eml', 'rb') as f:
    msg = email.message_from_binary_file(f, policy=policy.default)

# Extract fields
print(f"From: {msg['from']}")
print(f"To: {msg['to']}")
print(f"Subject: {msg['subject']}")
print(f"Date: {msg['date']}")

# Extract body
body = msg.get_body(preferencelist=('plain', 'html'))
print(body.get_content())

# Extract attachments
for attachment in msg.iter_attachments():
    filename = attachment.get_filename()
    if filename:
        content = attachment.get_content()
        with open(filename, 'wb') as f:
            f.write(content if isinstance(content, bytes) else content.encode())
        print(f"Saved: {filename}")
```

---

## Markdown → DOCX

```python
from docx import Document
from docx.shared import Pt, RGBColor
import re

def md_to_docx(md_text, output_path):
    doc = Document()
    for line in md_text.split('\n'):
        if line.startswith('# '):
            doc.add_heading(line[2:], level=0)
        elif line.startswith('## '):
            doc.add_heading(line[3:], level=1)
        elif line.startswith('### '):
            doc.add_heading(line[4:], level=2)
        elif line.startswith('- ') or line.startswith('* '):
            doc.add_paragraph(line[2:], style='List Bullet')
        elif re.match(r'^\d+\.\s', line):
            doc.add_paragraph(re.sub(r'^\d+\.\s', '', line), style='List Number')
        elif line.strip() == '':
            pass
        else:
            # Handle inline bold **text**
            p = doc.add_paragraph()
            parts = re.split(r'(\*\*.*?\*\*)', line)
            for part in parts:
                if part.startswith('**') and part.endswith('**'):
                    run = p.add_run(part[2:-2])
                    run.bold = True
                else:
                    p.add_run(part)
    doc.save(output_path)

md_to_docx(open('readme.md').read(), 'readme.docx')
```

---

## CSV Deep Work

```python
import pandas as pd

# Clean CSV
df = pd.read_csv('messy_data.csv', skip_blank_lines=True, na_values=['N/A', 'NULL', '-'])
df.drop_duplicates(inplace=True)
df.dropna(subset=['required_column'], inplace=True)
df['date_column'] = pd.to_datetime(df['date_column'], errors='coerce')

# Merge two CSVs
df1 = pd.read_csv('orders.csv')
df2 = pd.read_csv('customers.csv')
merged = pd.merge(df1, df2, on='customer_id')

# Split large CSV
df = pd.read_csv('large.csv')
chunk_size = 10000
for i, chunk in enumerate(range(0, len(df), chunk_size)):
    df.iloc[chunk:chunk+chunk_size].to_csv(f'part_{i}.csv', index=False)

# Clean & export to Excel
df.to_excel('clean_data.xlsx', index=False, sheet_name='Clean Data')
```

---

## Format Conversion Patterns

| From | To | Method |
|------|----|--------|
| Excel → PDF | pandas read → reportlab build | See [references/report-templates.md](references/report-templates.md) |
| DOCX → PDF | python-docx read → reportlab build | Extract text, rebuild layout |
| Excel → PPTX | pandas read → python-pptx build | Data → slides |
| PPTX → DOCX | python-pptx read → python-docx build | Extract text → document |
| CSV → Excel | `pd.read_csv().to_excel()` | Direct |
| Image → PDF | `RLImage()` in reportlab | Embed in PDF elements |
| Chart → PPTX | matplotlib save → pptx `add_picture()` | `slide.shapes.add_picture()` |

---

## Tips

- **Large Excel (>10MB):** `read_excel(..., dtype=str)` to skip slow type inference
- **PDF merged cells:** `page.extract_tables(table_settings={"vertical_strategy": "text"})`
- **DOCX templates:** Use `{{PLACEHOLDER}}` pattern for find-and-replace
- **matplotlib:** Always call `matplotlib.use('Agg')` first — no display in server
- **Charts in reports:** Save chart as PNG first, then embed in PDF/DOCX/PPTX
- **Image compression:** WebP format gives best quality/size ratio
- **OCR:** Uses Gemini vision via KConsole AI Gateway — no tesseract needed. Set `KCONSOLE_API_KEY` env var.
- **QR error correction:** Use `ERROR_CORRECT_H` when adding a logo overlay
- Always call `.save()` — data stays in memory until explicitly written
