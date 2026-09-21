# Architecture

## Layer separation

Three physical databases rather than three schemas inside one. The separation is architectural rather than cosmetic: a schema boundary is a naming convention, whereas a database boundary is enforced by the engine.

| Database | Layer | Contents | Why |
|---|---|---|---|
| `IEA_Grid_Operations` | Operational data store | `RawGridLog`, all columns `NVARCHAR` | Accepts any source value without conversion failure, so profiling happens before typing |
| `IEA_Governance_Registry` | Governance and metadata | Lookup registries, classification mappings, error capture | Isolates reference data from both raw and analytical layers |
| `IEA_Analytics_DW` | Analytical warehouse | Star schema, views, stored procedures | Presentation-facing; the only layer carrying referential integrity |

### Why the landing table is entirely text

Typing at the landing boundary causes conversion failure on ingestion, at which point the offending value is lost and the failure must be diagnosed from a log rather than from the data. Landing everything as text guarantees the complete source payload reaches a queryable surface, after which conversion can be performed under observation with failing rows visible.

This is what made the post-hoc integrity audit possible at all.

---

## The ETL pipeline

The SSIS solution uses a control flow orchestrating sequential data flow tasks. Dimensions load before the fact table, because fact loading depends on dimension lookups resolving to existing surrogate keys.

The fact data flow:

1. **Flat File Source** — all output columns configured as `DT_WSTR` to prevent source-level conversion failure
2. **Derived Column** — trimming, literal-token normalisation, type preparation
3. **Lookup transformations** — five lookups resolving natural keys to warehouse surrogate keys
4. **Error output routing** — no-match rows redirected to an error output rather than failing the component
5. **Data Conversion** — prepared string measure converted to `DECIMAL(18,4)`
6. **OLE DB Destination** — fast-load bulk insert

### Derived column responsibilities

- **Whitespace trimming** on every text attribute. Leading or trailing whitespace in a lookup key produces a silent no-match, which is how the fact table initially loaded empty.
- **Literal token normalisation.** Source values of `NULL`, `NA` and empty string mapped to true `NULL` rather than retained as text.
- **Decimal separator normalisation** for locale-independent conversion.
- **Audit columns** — load batch identifier and timestamp, to support later reconciliation.

### Lookup error tracking

Each lookup is configured with the no-match disposition set to **Redirect rows to no match output**, not **Fail component** and not **Ignore failure**. Redirected rows route to an error-capture table in the governance registry with the source payload and the identity of the failing lookup preserved.

This allows a load to complete while retaining a complete, queryable record of every row that could not be resolved. A load must not be permitted to discard rows without record.

---

## Dimensional model

### Grain

One row per country, per calendar month, per fuel product, per balance flow.

This is a line-item detailed fact table: each record refers to a single reported statistical observation rather than a summarisation.

Grain declaration precedes dimension selection because it determines dimensional applicability. A monthly grain excludes anything finer, which is why the date dimension carries no time-of-day attribute. The grain also determines the uniqueness constraint: `DateID`, `CountryID`, `ProductID` and `BalanceID` together must be unique, and a duplicate indicates a repeated ETL execution rather than genuine data.

Verified empirically: zero duplicate violations across all 159,739 rows.

### Fact table

| Column | Type | Role |
|---|---|---|
| `FactID` | `INT IDENTITY` | Surrogate primary key |
| `DateID` | `INT` | FK, smart key in `YYYYMM` form |
| `CountryID` | `INT` | FK |
| `BalanceID` | `INT` | FK |
| `ProductID` | `INT` | FK |
| `UnitID` | `INT` | FK |
| `ValueGWh` | `DECIMAL(18,4)` | Additive measure, `NOT NULL` |

The decimal scale is material. Profiling found 82,545 values carrying four decimal places and 57,288 carrying three. A `DECIMAL(18,0)` declaration would silently round every fractional value, and the resulting error would be invisible in the reporting tier.

`ValueGWh` is fully additive across all five dimensions, which permits summation along any combination of axes without semantic qualification.

### Dimensions

All five carry system-generated surrogate keys. A dimensional consistency audit tested whether any single member maps to more than one attribute set: `COUNTRY` returned 53 members with zero inconsistencies, `PRODUCT` 15 members with zero, `BALANCE` 6 members with zero.

**COUNTRY** — 48 sovereign states plus 5 IEA regional aggregates. Carries `ISOCode` (ISO 3166-1 alpha-3), `Region`, `Continent`, `EU_Member`, and the `IsAggregate` flag.

**PRODUCT** — 12 leaf fuel lines plus 3 pre-calculated rollups. Carries `ProductCategory`, `SubCategory`, `EnergyGroup`, and four analytical flags: `RenewableFlag`, `FossilFlag`, `IntermittentFlag`, `DispatchableFlag`. Also `IsAggregate`, `AggregateLevel` and `IsUnclassified`.

**BALANCE** — six flows.

| Balance | Category | Group | Rows with positive measure |
|---|---|---|---|
| Net Electricity Production | Production | Supply-Side | 113,628 |
| Distribution Losses | Losses | Supply-Side | 7,968 |
| Final Consumption (Calculated) | Consumption | Demand-Side | 7,968 |
| Total Exports | Trade | Supply-Side | 6,615 |
| Total Imports | Trade | Demand-Side | 6,606 |
| Used for pumped storage | Storage | Demand-Side | 5,609 |

These sum to 148,394. Subtracted from 159,739 that leaves exactly 11,345, which is the count of rows carrying a genuine reported zero. The positive-value filter therefore excludes precisely the legitimate zeros and nothing further. No rows are unaccounted for.

**DATE** — 194 members. `DateID` is a smart key in `YYYYMM` form rather than a meaningless surrogate, chosen because it is both chronologically sortable and legible during ETL debugging. The trade-off is that it cannot serve as a date parameter or a continuous axis in the presentation tier, which is why `FullDate` and `MonthSortKey` were added during remediation.

**UNIT** — degenerate. A single member, gigawatt-hours, applies to all rows. Retained rather than collapsed to preserve symmetry with the logical model and to establish an extension point for a future multi-unit constellation with `ConversionToSI` mediating. This is a decision, not an oversight.

### Star rather than snowflake

Dimensions are deliberately denormalised. `COUNTRY` carries `Region` and `Continent` as repeating text rather than referencing normalised tables, and `PRODUCT` carries category and subcategory inline.

The storage penalty of repeating a continent name across 53 rows is negligible. The query cost of two additional joins on every geographic rollup, executed against a 159,739-row fact table, is not.

---

## Governed access layer

Two views form the boundary between the warehouse and everything downstream.

| View | Contents | Correct use |
|---|---|---|
| `vw_ElectricityFacts_Leaf` | Leaf countries and leaf products only, `IsAggregate = 0` on both | Additive. Safe to sum on any axis |
| `vw_ElectricityTotals` | Pre-calculated `Electricity` total per country and month | Headline totals and trade balances. Never combined with the leaf view in one sum |

The governing principle: **make the correct query the easy query**. The BI layer does not rely on analysts remembering to exclude aggregate rows; the exclusion happens at the view boundary, so default behaviour is safe behaviour.

---

## Integrity enforcement

Applied after remediation, to convert a future silent bad load into a loud failure.

- Five foreign key constraints, applied `WITH CHECK` so existing rows are validated at creation
- A unique constraint on the declared grain
- A check constraint enforcing `ValueGWh >= 0`
- `NOT NULL` on the measure

The `WITH CHECK` clause is material to the audit narrative: each constraint creation statement executed successfully, which independently corroborates the orphan-key finding through a mechanism separate from the audit queries themselves.

---

## Sparsity is not missing data

The fact table occupies 17.3% of the full dimensional cartesian product: 159,739 rows against a possible 925,380.

This is correct. Coverage is structured, not lossy. Costa Rica reports from January 2021, a second group from January 2015, the OECD core from January 2010. No country reports every fuel type. Costa Rica records no nuclear generation because Costa Rica operates no reactors.

An empty cell is the honest rendering of an absent observation. Handling it belongs in the report layer, not in a data repair. There are already 11,345 rows carrying a genuinely reported zero, so imputing zeros into empty cells would make "not reported" and "reported zero" indistinguishable.
