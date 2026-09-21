import os
OUT = os.path.dirname(os.path.abspath(__file__))

PINE  = "#0A3D2E"
GREEN = "#1FA463"
LIME  = "#E6F5ED"
GOLD  = "#F2A20C"
AMBER = "#FDF4E0"
SLATE = "#5F6F68"
INK   = "#13251E"
HAIR  = "#D8E4DE"
RED   = "#C1502E"
BG    = "#FFFFFF"

FONT = "font-family='Segoe UI, Helvetica Neue, Arial, sans-serif'"


def box(x, y, w, h, fill, stroke, r=6, sw=1.5):
    return (f"<rect x='{x}' y='{y}' width='{w}' height='{h}' rx='{r}' "
            f"fill='{fill}' stroke='{stroke}' stroke-width='{sw}'/>")


def txt(x, y, s, size=13, fill=INK, weight="normal", anchor="start", mono=False):
    fam = ("font-family='Consolas, Monaco, monospace'" if mono else FONT)
    s = (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
    return (f"<text x='{x}' y='{y}' {fam} font-size='{size}' fill='{fill}' "
            f"font-weight='{weight}' text-anchor='{anchor}'>{s}</text>")


def arrow(x1, y1, x2, y2, color=GREEN, w=2):
    return (f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='{color}' "
            f"stroke-width='{w}' marker-end='url(#ah)'/>")


DEFS = (f"<defs><marker id='ah' viewBox='0 0 10 10' refX='9' refY='5' "
        f"markerWidth='6' markerHeight='6' orient='auto-start-reverse'>"
        f"<path d='M 0 0 L 10 5 L 0 10 z' fill='{GREEN}'/></marker></defs>")


# =====================================================================
# 1. ARCHITECTURE  (ELT pipeline across three databases)
# =====================================================================
W, H = 1160, 560
s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
     f"viewBox='0 0 {W} {H}'>", DEFS,
     f"<rect width='{W}' height='{H}' fill='{BG}'/>"]

s.append(txt(40, 44, "GridPulse pipeline architecture", 22, PINE, "bold"))
s.append(txt(40, 68, "Extract and load by SSIS; transform in T-SQL. 159,739 fact rows across 194 months.",
            13, SLATE))

# --- source ---
s.append(box(40, 100, 170, 92, AMBER, GOLD))
s.append(txt(125, 128, "SOURCE", 11, GOLD, "bold", "middle"))
s.append(txt(125, 150, "MES_0226.csv", 13, INK, "bold", "middle", mono=True))
s.append(txt(125, 170, "IEA monthly extract", 11, SLATE, anchor="middle"))
s.append(txt(125, 184, "8 header rows skipped", 10, SLATE, anchor="middle"))

s.append(arrow(215, 146, 272, 146))
s.append(txt(243, 136, "SSIS", 10, GREEN, "bold", "middle"))

# --- SSIS package ---
s.append(box(278, 100, 210, 92, LIME, GREEN))
s.append(txt(383, 128, "IEA_Data_Ingestion.dtsx", 11, GREEN, "bold", "middle"))
s.append(txt(383, 148, "Flat File Source", 11, INK, anchor="middle"))
s.append(txt(383, 164, "Data Conversion", 11, INK, anchor="middle"))
s.append(txt(383, 180, "OLE DB Destination", 11, INK, anchor="middle"))

s.append(arrow(493, 146, 550, 146))

# --- Layer 1 ---
s.append(box(556, 100, 230, 92, "#FFFFFF", PINE, sw=2))
s.append(txt(571, 124, "LAYER 1  ·  ODS", 10, GOLD, "bold"))
s.append(txt(571, 146, "IEA_Grid_Operations", 13, PINE, "bold", mono=True))
s.append(txt(571, 166, "RawGridLog — every column", 11, SLATE))
s.append(txt(571, 181, "NVARCHAR, nothing can fail", 11, SLATE))

# --- Layer 2 (governance) ---
s.append(box(556, 232, 230, 92, "#FFFFFF", PINE, sw=2))
s.append(txt(571, 256, "LAYER 2  ·  GOVERNANCE", 10, GOLD, "bold"))
s.append(txt(571, 278, "IEA_Governance_Registry", 13, PINE, "bold", mono=True))
s.append(txt(571, 298, "GeopoliticalLookup", 11, SLATE))
s.append(txt(571, 313, "TechnologyLookup", 11, SLATE))

# transform arrow down+right
s.append(arrow(671, 196, 671, 228))
s.append(arrow(790, 146, 848, 146))
s.append(txt(819, 136, "T-SQL", 10, GREEN, "bold", "middle"))
s.append(f"<path d='M 790 278 L 818 278 L 818 168 L 848 168' fill='none' "
         f"stroke='{GREEN}' stroke-width='1.8' stroke-dasharray='5 4' marker-end='url(#ah)'/>")
s.append(txt(818, 300, "enriches", 10, SLATE, anchor="middle"))

# --- Layer 3 ---
s.append(box(854, 100, 266, 224, "#FFFFFF", PINE, sw=2))
s.append(txt(869, 124, "LAYER 3  ·  ANALYTICS", 10, GOLD, "bold"))
s.append(txt(869, 146, "IEA_Analytics_DW", 13, PINE, "bold", mono=True))
s.append(box(869, 158, 236, 44, LIME, GREEN, r=4, sw=1))
s.append(txt(987, 176, "FactMonthlyElectricity", 12, PINE, "bold", "middle", mono=True))
s.append(txt(987, 192, "COUNTRY · PRODUCT · BALANCE · DATE · UNIT", 10, SLATE, anchor="middle"))
s.append(box(869, 232, 236, 34, AMBER, GOLD, r=4, sw=1))
s.append(txt(987, 254, "governed views + procedures", 11, PINE, "bold", "middle"))
s.append(txt(987, 292, "IsAggregate filter applied here,", 10, SLATE, anchor="middle"))
s.append(txt(987, 306, "so it cannot be bypassed", 10, SLATE, anchor="middle"))

# --- BI tier ---
s.append(arrow(987, 330, 987, 372))
s.append(box(854, 378, 128, 74, LIME, GREEN))
s.append(txt(918, 402, "SSRS", 14, PINE, "bold", "middle"))
s.append(txt(918, 422, "4 reports", 11, SLATE, anchor="middle"))
s.append(txt(918, 438, "tabular · matrix", 10, SLATE, anchor="middle"))

s.append(box(992, 378, 128, 74, LIME, GREEN))
s.append(txt(1056, 402, "Tableau", 14, PINE, "bold", "middle"))
s.append(txt(1056, 422, "4 visuals", 11, SLATE, anchor="middle"))
s.append(txt(1056, 438, "mix · map · trend", 10, SLATE, anchor="middle"))

# --- note panel ---
s.append(box(40, 378, 790, 74, "#F7F9FA", HAIR))
s.append(txt(60, 402, "Why ELT rather than ETL", 12, PINE, "bold"))
s.append(txt(60, 422, "SSIS lands the raw extract untyped, so no source value can fail on ingestion and the full payload reaches a", 11, SLATE))
s.append(txt(60, 438, "queryable surface. Lookups run afterwards as SQL joins against the governance registry, under observation.", 11, SLATE))

s.append(txt(40, 502, "Layer boundaries are separate databases, not schemas: the separation is enforced by the engine rather than by convention.", 11, SLATE))
s.append(txt(40, 524, "Referential integrity is declared in Layer 3 only.", 11, SLATE))

s.append("</svg>")
open(os.path.join(OUT, "architecture.svg"), "w").write("\n".join(s))
print("architecture.svg")


# =====================================================================
# 2. STAR SCHEMA
# =====================================================================
W, H = 1120, 770
s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
     f"viewBox='0 0 {W} {H}'>", DEFS, f"<rect width='{W}' height='{H}' fill='{BG}'/>"]

s.append(txt(40, 44, "Conformed star schema", 22, PINE, "bold"))
s.append(txt(40, 68, "Grain: one row per country, per month, per fuel product, per balance flow. Zero duplicates across 159,739 rows.",
            13, SLATE))


def dim(x, y, title, rows, w=232, badge=None):
    h = 42 + len(rows) * 17
    out = [box(x, y, w, h, "#FFFFFF", PINE, sw=1.8)]
    out.append(f"<rect x='{x}' y='{y}' width='{w}' height='28' rx='6' fill='{PINE}'/>")
    out.append(f"<rect x='{x}' y='{y+18}' width='{w}' height='10' fill='{PINE}'/>")
    out.append(txt(x + 12, y + 19, title, 12, "#FFFFFF", "bold"))
    if badge:
        out.append(txt(x + w - 12, y + 19, badge, 10, LIME, anchor="end"))
    for i, (r, kind) in enumerate(rows):
        yy = y + 46 + i * 17
        col = GOLD if kind == "pk" else (GREEN if kind == "flag" else INK)
        wt = "bold" if kind == "pk" else "normal"
        out.append(txt(x + 12, yy, r, 11, col, wt, mono=True))
    return "\n".join(out), h


# fact in centre
fx, fy, fw = 444, 258, 232
fh = 42 + 7 * 17
s.append(box(fx, fy, fw, fh, LIME, GREEN, sw=2.5))
s.append(f"<rect x='{fx}' y='{fy}' width='{fw}' height='28' rx='6' fill='{GREEN}'/>")
s.append(f"<rect x='{fx}' y='{fy+18}' width='{fw}' height='10' fill='{GREEN}'/>")
s.append(txt(fx + 12, fy + 19, "FactMonthlyElectricity", 12, "#FFFFFF", "bold"))
for i, (r, k) in enumerate([("FactID  PK", "pk"), ("DateID  FK", "fk"),
                            ("CountryID  FK", "fk"), ("BalanceID  FK", "fk"),
                            ("ProductID  FK", "fk"), ("UnitID  FK", "fk"),
                            ("ValueGWh  DECIMAL(18,4)", "m")]):
    col = GOLD if k == "pk" else (PINE if k == "m" else INK)
    s.append(txt(fx + 12, fy + 46 + i * 17, r, 11, col,
                 "bold" if k in ("pk", "m") else "normal", mono=True))

# dimensions
d, _ = dim(40, 110, "COUNTRY", [("CountryID  PK", "pk"), ("CountryName", ""),
                                ("ISOCode", ""), ("Region", ""), ("Continent", ""),
                                ("EU_Member", ""), ("IsAggregate", "flag")], badge="53")
s.append(d)

d, _ = dim(848, 110, "PRODUCT", [("ProductID  PK", "pk"), ("ProductName", ""),
                                 ("ProductCategory", ""), ("RenewableFlag", "flag"),
                                 ("FossilFlag", "flag"), ("IntermittentFlag", "flag"),
                                 ("DispatchableFlag", "flag"), ("IsAggregate", "flag")], badge="15")
s.append(d)

d, _ = dim(40, 430, "BALANCE", [("BalanceID  PK", "pk"), ("BalanceName", ""),
                                ("BalanceCategory", ""), ("BalanceGroup", "")], badge="6")
s.append(d)

d, _ = dim(848, 430, "DATE", [("DateID  PK", "pk"), ("Year", ""), ("MonthNumber", ""),
                              ("MonthName", ""), ("Quarter", ""), ("MonthYear", ""),
                              ("MonthSortKey", "flag")], badge="194")
s.append(d)

d, _ = dim(444, 556, "UNIT", [("UnitID  PK", "pk"), ("UnitSymbol  ·  GWh", "")], badge="1")
s.append(d)

# connectors
s.append(arrow(272, 190, 440, 290, PINE, 1.6))
s.append(arrow(846, 190, 680, 290, PINE, 1.6))
s.append(arrow(272, 462, 440, 372, PINE, 1.6))
s.append(arrow(846, 462, 680, 372, PINE, 1.6))
s.append(arrow(560, 552, 560, 402, PINE, 1.6))

# legend
s.append(box(40, 676, 1040, 62, "#F7F9FA", HAIR))
s.append(f"<circle cx='62' cy='698' r='5' fill='{GOLD}'/>")
s.append(txt(76, 702, "primary key", 11, SLATE))
s.append(f"<circle cx='186' cy='698' r='5' fill='{GREEN}'/>")
s.append(txt(200, 702, "analytical or control flag", 11, SLATE))
s.append(txt(62, 724, "RenewableFlag is environmental; IntermittentFlag and DispatchableFlag are operational. Hydro is renewable", 11, SLATE))
s.append(txt(62, 740, "and dispatchable; solar is renewable and intermittent; nuclear is neither.", 11, SLATE))

s.append("</svg>")
open(os.path.join(OUT, "star-schema.svg"), "w").write("\n".join(s))
print("star-schema.svg")


# =====================================================================
# 3. THE AGGREGATION DEFECT
# =====================================================================
W, H = 1060, 580
s = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}' "
     f"viewBox='0 0 {W} {H}'>", DEFS, f"<rect width='{W}' height='{H}' fill='{BG}'/>"]

s.append(txt(40, 44, "The aggregation defect", 22, PINE, "bold"))
s.append(txt(40, 68, "Australia · February 2026 · Net Electricity Production. Rollup rows sit at the same grain as leaf rows.",
            13, SLATE))

leaf = [("Coal, Peat and Manufactured Gases", 8877.96),
        ("Solar", 5306.02), ("Wind", 3253.64), ("Natural Gas", 3040.82),
        ("Hydro", 937.83), ("Oil and Petroleum Products", 302.45),
        ("Combustible Renewables", 207.06)]
rollup = [("Electricity  (grand total)", 21925.79),
          ("Total Combustible Fuels", 12428.29),
          ("Total Renewables (...)", 9704.56)]

MAXV = 22000.0
BARW = 296

s.append(txt(40, 112, "LEAF PRODUCTS  —  additive, safe to sum", 12, GREEN, "bold"))
y = 130
for name, v in leaf:
    s.append(txt(40, y + 11, name[:34], 11, INK))
    bw = max(3, (min(v, MAXV) / MAXV) * BARW)
    s.append(f"<rect x='300' y='{y}' width='{bw:.0f}' height='15' rx='2' fill='{GREEN}'/>")
    s.append(txt(300 + bw + 8, y + 12, f"{v:,.0f}", 11, SLATE))
    y += 22

s.append(f"<line x1='40' y1='{y+6}' x2='640' y2='{y+6}' stroke='{HAIR}' stroke-width='1'/>")
s.append(txt(40, y + 28, "Sum of 7 leaf products", 12, PINE, "bold"))
s.append(txt(300, y + 28, "21,925.8 GWh", 13, GREEN, "bold"))

s.append(txt(40, y + 62, "ROLLUP ROWS  —  pre-aggregated by the IEA, same grain", 12, RED, "bold"))
y2 = y + 80
for name, v in rollup:
    s.append(txt(40, y2 + 11, name, 11, INK))
    bw = max(3, (min(v, MAXV) / MAXV) * BARW)
    s.append(f"<rect x='300' y='{y2}' width='{bw:.0f}' height='15' rx='2' fill='{RED}' opacity='0.85'/>")
    s.append(txt(300 + bw + 8, y2 + 12, f"{v:,.0f}", 11, SLATE))
    y2 += 22

# right-hand comparison panel
s.append(box(660, 110, 360, 190, AMBER, GOLD))
s.append(txt(680, 138, "What a naive SUM returns", 13, PINE, "bold"))
s.append(txt(680, 176, "65,984.4", 34, RED, "bold"))
s.append(txt(680, 196, "GWh  —  all 10 product rows", 11, SLATE))
s.append(f"<line x1='680' y1='212' x2='1000' y2='212' stroke='{GOLD}' stroke-width='1'/>")
s.append(txt(680, 238, "True total", 12, PINE, "bold"))
s.append(txt(680, 272, "21,925.8", 30, GREEN, "bold"))
s.append(txt(680, 292, "GWh  —  the stored Electricity row", 11, SLATE))

s.append(box(660, 316, 360, 70, LIME, GREEN))
s.append(txt(840, 344, "3.01x", 30, GREEN, "bold", "middle"))
s.append(txt(840, 368, "overstatement on one country-month", 11, PINE, anchor="middle"))

s.append(box(660, 400, 360, 104, "#F7F9FA", HAIR))
s.append(txt(680, 424, "The reconciliation control", 12, PINE, "bold"))
s.append(txt(680, 444, "The 7 leaf products sum to exactly the stored", 11, SLATE))
s.append(txt(680, 460, "Electricity total, to four decimal places.", 11, SLATE))
s.append(txt(680, 480, "That check only exists because the rollups", 11, SLATE))
s.append(txt(680, 496, "were flagged rather than deleted.", 11, SLATE))

s.append(box(40, 470, 600, 74, "#F7F9FA", HAIR))
s.append(txt(60, 494, "The fix", 12, PINE, "bold"))
s.append(txt(60, 514, "IsAggregate flags on COUNTRY and PRODUCT, and a governed view that applies the", 11, SLATE))
s.append(txt(60, 530, "exclusion at the boundary. Across the warehouse, a naive sum overstates by roughly 8x.", 11, SLATE))

s.append("</svg>")
open(os.path.join(OUT, "aggregation-defect.svg"), "w").write("\n".join(s))
print("aggregation-defect.svg")
