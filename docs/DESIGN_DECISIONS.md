# Design Decisions

The reasoning behind the non-obvious choices, including the ones I would make differently.

---

## Medallion architecture to three-layer SSIS

This project started as a modern data warehouse using the medallion pattern: `bronze` for raw ingested data, `silver` for cleaned and standardised, `gold` for the dimensional model. The original schema creation script is preserved in [`archive/init_database_medallion.sql`](../archive/init_database_medallion.sql).

The project was subsequently constrained to an SSIS-based ETL pipeline. Rather than force medallion naming onto a toolchain that does not assume it, the layering was reworked into three physical databases: operational data store, governance registry, and analytical warehouse.

The mapping is close but not identical:

| Medallion | GridPulse equivalent | Difference |
|---|---|---|
| `bronze` | `IEA_Grid_Operations.RawGridLog` | Same role. Raw, untyped, immutable |
| `silver` | Handled inside the SSIS data flow | Cleansing happens in-flight via derived column transformation rather than persisting an intermediate table |
| `gold` | `IEA_Analytics_DW` star schema | Same role |

The genuine difference is that silver is not materialised. In the medallion version, cleaned data would persist as a queryable layer. In the SSIS version, cleansing occurs in the pipeline buffer and only the conformed output lands.

**Trade-off.** Not materialising silver means less storage and one fewer write, but it also means a cleansing defect is harder to diagnose after the fact, because there is no persisted intermediate to inspect. This was partly mitigated by the error-capture table, which persists every row that failed a lookup. If I were rebuilding this, I would materialise silver.

---

## Flagging rollups rather than deleting them

The IEA source interleaves pre-aggregated rows with leaf rows at identical grain. Five of 53 country members are regional aggregates; three of 15 product members are rollups.

The obvious fix is to filter them out during ETL so they never reach the warehouse. I flagged them instead.

**Why.** The stored IEA totals are an independent reconciliation control. With rollups retained, the sum of leaf members for any country-month can be tested against the supplied total, and a variance surfaces a data quality defect. Deleting the rollups would have removed the only external check on the correctness of the leaf data.

**Cost.** Every downstream consumer must now apply the exclusion. That is a real risk, and it is why the governed view layer exists: the exclusion is applied once at the boundary rather than repeated in eight separate reports.

---

## Smart key on the date dimension

`DateID` is `YYYYMM` as an integer rather than an arbitrary surrogate. This violates the general principle that surrogate keys should carry no meaning.

**Why.** A `YYYYMM` integer is chronologically sortable and immediately legible when debugging an ETL run. Reading `202602` in a failed lookup is more useful than reading `147`.

**Cost.** It cannot serve as a date parameter, a continuous axis, or an input to time-intelligence functions in the BI tier. `FullDate` and `MonthSortKey` were added later to cover those needs, which means the dimension now carries three representations of the same thing. A conventional surrogate plus `FullDate` from the start would have been cleaner.

---

## Retaining a degenerate UNIT dimension

`UNIT` has one member across all 159,739 rows. A single-member dimension with a surrogate key and a join contributes cost and no analytical value.

I kept it to preserve symmetry with the logical model and to establish an extension point for a future multi-unit model, where terajoule or megawatt-hour measures would coexist with `ConversionToSI` mediating between them.

**Honest assessment.** This is the weakest justification in the project. If the multi-unit extension never arrives, the dimension is pure overhead. A degenerate attribute on the fact table would have been the defensible choice, with the dimension introduced only when a second unit actually appeared.

---

## Type 1 slowly changing dimensions throughout

All five dimensions use Type 1: the new value replaces the old, no history preserved.

**Why.** The attributes carried are either genuinely static (a country's continent, a fuel's renewable classification) or are corrections to prior misclassification. Neither case requires history.

**The exception I did not handle.** European Union membership is a dated event with analytical significance. Under Type 1, historic EU aggregates are restated under the present membership roster rather than the roster contemporaneous with each observation. A Type 2 treatment on `COUNTRY` would require surrogate key versioning with effective start and end timestamps, a current-row indicator, and a fact load that resolves to the dimension version valid at the observation date. Scoped but not implemented.

---

## Keeping the unclassified product member visible

The `Not Specified` fuel member carries 6,834 rows, roughly 0.22% of generation, with `ProductCategory` of `Unknown` and all four analytical flags set to `N`. It counts as neither renewable nor fossil, which means it silently understates every renewable share calculation.

The temptation is to filter it out. I flagged it with `IsUnclassified` and kept it rendered, in neutral grey on the donut chart.

**Why.** Suppressing it would cause the remaining segments to sum to less than 100% with no explanation visible on the chart. Showing it is both more honest and easier to defend.

---

## Fixing textual defects in the database, not the reports

The `Sept-19` against `Sep-19` inconsistency could have been handled with a conditional expression in the SSRS matrix. The literal `NULL` strings could have been handled with a string comparison in each report expression.

Both were fixed with `UPDATE` statements against the dimension tables instead.

**Why.** A presentation-layer workaround has to be repeated in every report that touches the field, and a report added later will not have it. Fixing the data means the defect is gone once. The corresponding normalisation was also added to the SSIS derived column so a future load does not reintroduce it.

---

## What I would change

**Materialise the silver layer.** As above. The diagnostic value outweighs the storage.

**Conventional surrogate on DATE.** Keep `FullDate` as the business attribute and drop the smart key.

**Drop or defer the UNIT dimension.** Degenerate attribute until a second unit exists.

**Instrument the load.** Row counts in and out per component, persisted per batch. The reconciliation in this project was performed after the fact against the final table. It should have been continuous.

**Type 2 on COUNTRY** for EU membership, as scoped above.
