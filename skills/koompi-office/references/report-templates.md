# Report Templates

Ready-to-use templates for common PDF reports. Copy and adapt as needed.

## Invoice Template

```python
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, HRFlowable
from reportlab.lib.styles import getSampleStyleSheet
from datetime import datetime

def create_invoice(filename, invoice_data):
    doc = SimpleDocTemplate(filename, pagesize=A4,
                             leftMargin=20*mm, rightMargin=20*mm,
                             topMargin=20*mm, bottomMargin=20*mm)
    styles = getSampleStyleSheet()
    elements = []

    # Header
    elements.append(Paragraph(f"Invoice #{invoice_data['number']}", styles['Title']))
    elements.append(Paragraph(f"Date: {invoice_data['date']}", styles['Normal']))
    elements.append(Spacer(1, 5*mm))

    # From/To
    info_data = [
        ["From:", invoice_data['from_name']],
        ["To:", invoice_data['to_name']],
        ["", invoice_data['to_address']],
    ]
    info_table = Table(info_data, colWidths=[30*mm, 120*mm])
    info_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    elements.append(info_table)
    elements.append(Spacer(1, 10*mm))

    # Line items
    headers = ["Description", "Qty", "Unit Price", "Total"]
    rows = [headers] + [[item['desc'], str(item['qty']), f"${item['price']:.2f}", f"${item['qty']*item['price']:.2f}"] for item in invoice_data['items']]

    table = Table(rows, colWidths=[80*mm, 20*mm, 30*mm, 30*mm])
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E81B25')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9fafb')]),
        ('ALIGN', (1, 0), (-1, -1), 'RIGHT'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    elements.append(table)

    # Total
    total = sum(item['qty'] * item['price'] for item in invoice_data['items'])
    elements.append(Spacer(1, 5*mm))
    elements.append(Paragraph(f"<b>Total: ${total:.2f}</b>", styles['Normal']))

    doc.build(elements)
```

## Data Summary Report

```python
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
from reportlab.lib.styles import getSampleStyleSheet
import pandas as pd

def create_summary_report(filename, title, df, summary_stats=None):
    doc = SimpleDocTemplate(filename, pagesize=A4,
                             leftMargin=20*mm, rightMargin=20*mm,
                             topMargin=20*mm, bottomMargin=20*mm)
    styles = getSampleStyleSheet()
    elements = []

    elements.append(Paragraph(title, styles['Title']))
    elements.append(Spacer(1, 5*mm))

    # Summary stats as key-value table
    if summary_stats:
        stats_data = [[k, str(v)] for k, v in summary_stats.items()]
        stats_table = Table(stats_data, colWidths=[60*mm, 80*mm])
        stats_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('GRID', (0, 0), (-1, -1), 0.3, colors.lightgrey),
            ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#f3f4f6')),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ]))
        elements.append(stats_table)
        elements.append(Spacer(1, 10*mm))

    # Data table (first 50 rows)
    rows = [df.columns.tolist()] + df.head(50).fillna('').values.tolist()
    col_w = 160*mm / len(df.columns)
    table = Table(rows, colWidths=[col_w]*len(df.columns))
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E81B25')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('GRID', (0, 0), (-1, -1), 0.3, colors.grey),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9fafb')]),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    elements.append(table)

    if len(df) > 50:
        elements.append(Spacer(1, 3*mm))
        elements.append(Paragraph(f"<i>Showing 50 of {len(df)} rows</i>", styles['Normal']))

    doc.build(elements)
```

## Usage

```python
import pandas as pd
from references.report_templates import create_invoice, create_summary_report

# Invoice
create_invoice("invoice.pdf", {
    "number": "INV-001",
    "date": "2026-04-05",
    "from_name": "KOOMPI",
    "to_name": "Client Corp",
    "to_address": "123 Street, Phnom Penh",
    "items": [
        {"desc": "KoompiClaw Device", "qty": 2, "price": 239},
        {"desc": "Setup Fee", "qty": 1, "price": 50},
    ]
})

# Summary report from Excel
df = pd.read_excel("sales_data.xlsx")
create_summary_report("report.pdf", "Q1 Sales Report", df, {
    "Total Revenue": f"${df['revenue'].sum():,.2f}",
    "Transactions": len(df),
    "Average Order": f"${df['revenue'].mean():,.2f}",
})
```
