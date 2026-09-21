/*
===============================================================================
  GridPulse - 02: Aggregate isolation metadata
===============================================================================
  The IEA source interleaves pre-aggregated rollup rows with leaf rows at
  identical grain. Without control, any SUM double or triple counts.

  Measured effect, Australia / February 2026 / Net Electricity Production:
      naive SUM across all product rows = 65,984.4 GWh
      stored total ('Electricity' member) = 21,925.8 GWh
      overstatement factor = 3.01x

  Across the whole warehouse an unfiltered sum overstates by roughly 8x.

  The rollups are FLAGGED rather than DELETED. The stored IEA totals then serve
  as an independent reconciliation control: leaf sums can be tested against the
  supplied total, and a variance surfaces a data quality defect that deletion
  would have concealed. See docs/DESIGN_DECISIONS.md.

  PREREQUISITE: run this AFTER the SSIS load has populated the dimensions.
  It updates dimension rows, so the members must already exist.
===============================================================================
*/

USE IEA_Analytics_DW;
GO

-- ---------------------------------------------------------------------------
-- COUNTRY: 5 of the 53 members are IEA regional rollups, not countries
-- ---------------------------------------------------------------------------
IF COL_LENGTH('COUNTRY','IsAggregate') IS NULL
    ALTER TABLE COUNTRY ADD IsAggregate BIT NOT NULL DEFAULT 0;
GO

UPDATE COUNTRY
SET    IsAggregate = 1
WHERE  CountryName IN ('OECD Europe','OECD Total','IEA Total',
                       'OECD Americas','OECD Asia Oceania');
GO

-- Verify: expect 5
SELECT COUNT(*) AS Aggregate_Countries FROM COUNTRY WHERE IsAggregate = 1;
GO


-- ---------------------------------------------------------------------------
-- PRODUCT: 3 of the 15 members are rollups.
-- 'Electricity' is the grand total. The two 'Total ...' members are subtotals
-- that overlap it, so they cannot be summed together either.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('PRODUCT','IsAggregate') IS NULL
    ALTER TABLE PRODUCT ADD IsAggregate BIT NOT NULL DEFAULT 0;
IF COL_LENGTH('PRODUCT','AggregateLevel') IS NULL
    ALTER TABLE PRODUCT ADD AggregateLevel VARCHAR(10) NULL;
IF COL_LENGTH('PRODUCT','IsUnclassified') IS NULL
    ALTER TABLE PRODUCT ADD IsUnclassified BIT NOT NULL DEFAULT 0;
GO

UPDATE PRODUCT
SET    IsAggregate    = 1,
       AggregateLevel = CASE WHEN ProductName = 'Electricity' THEN 'Total'
                             ELSE 'Subtotal' END
WHERE  ProductName IN ('Electricity',
                       'Total Combustible Fuels',
                       'Total Renewables (Hydro, Geo, Solar, Wind, Other)');

UPDATE PRODUCT SET AggregateLevel = 'Leaf' WHERE IsAggregate = 0;
GO

-- 'Not Specified' is an inferred junk member, not a real fuel. All four of its
-- analytical flags are 'N', so it counts as neither renewable nor fossil and
-- silently understates every renewable-share calculation. Flagged so it can be
-- excluded deliberately rather than by accident. It is kept VISIBLE in the BI
-- tier: suppressing it would make the remaining segments sum to under 100%.
UPDATE PRODUCT SET IsUnclassified = 1 WHERE ProductName = 'Not Specified';
GO

-- Verify: expect 3 aggregate, 12 leaf
SELECT AggregateLevel, COUNT(*) AS Members
FROM   PRODUCT
GROUP  BY AggregateLevel;
GO
