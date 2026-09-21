/*
===============================================================================
  GridPulse - 06: Integrity audit (READ-ONLY)
===============================================================================
  This is the audit that changed the project's diagnosis.

  After the initial load the SSRS reports failed: partial rendering, missing
  headers, blank blocks. The SSIS packages had been run with the Ignore Failure
  error disposition, so the assumption was that rows had been dropped silently.

  Every test below was run BEFORE any remediation was attempted. All five
  passed. Ignore Failure had not corrupted the data. The real causes were the
  textual defects addressed in script 03.

  Reporting that the audit contradicted the hypothesis produced a materially
  better fix than acting on the assumption would have.

  Safe to run at any time. Nothing here modifies data.
===============================================================================
*/

USE IEA_Analytics_DW;
GO

SET STATISTICS IO ON;
GO

-- ---------------------------------------------------------------------------
-- TEST 1: orphaned surrogate keys
-- The direct test for the damage Ignore Failure was assumed to have caused.
-- Expected: 0 across all six checks.
-- ---------------------------------------------------------------------------
SELECT 'Orphan CountryID' AS Check_Name, COUNT(*) AS Bad_Rows
FROM   FactMonthlyElectricity f
LEFT   JOIN COUNTRY d ON d.CountryID = f.CountryID
WHERE  d.CountryID IS NULL
UNION ALL
SELECT 'Orphan ProductID', COUNT(*)
FROM   FactMonthlyElectricity f
LEFT   JOIN PRODUCT d ON d.ProductID = f.ProductID
WHERE  d.ProductID IS NULL
UNION ALL
SELECT 'Orphan BalanceID', COUNT(*)
FROM   FactMonthlyElectricity f
LEFT   JOIN BALANCE d ON d.BalanceID = f.BalanceID
WHERE  d.BalanceID IS NULL
UNION ALL
SELECT 'Orphan DateID', COUNT(*)
FROM   FactMonthlyElectricity f
LEFT   JOIN [DATE] d ON d.DateID = f.DateID
WHERE  d.DateID IS NULL
UNION ALL
SELECT 'Orphan UnitID', COUNT(*)
FROM   FactMonthlyElectricity f
LEFT   JOIN UNIT d ON d.UnitID = f.UnitID
WHERE  d.UnitID IS NULL
UNION ALL
SELECT 'NULL FK values', COUNT(*)
FROM   FactMonthlyElectricity
WHERE  CountryID IS NULL OR ProductID IS NULL OR BalanceID IS NULL
    OR DateID IS NULL OR UnitID IS NULL;
GO


-- ---------------------------------------------------------------------------
-- TEST 2: grain duplicates
-- Confirms the declared grain is the actual grain. Expected: 0.
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS Grain_Violations
FROM (
    SELECT DateID, CountryID, ProductID, BalanceID
    FROM   FactMonthlyElectricity
    GROUP  BY DateID, CountryID, ProductID, BalanceID
    HAVING COUNT(*) > 1
) x;
GO


-- ---------------------------------------------------------------------------
-- TEST 3: dimensional attribute consistency
--
-- This is the strongest of the five tests. If rows had been silently mangled,
-- the same ProductName would carry two different ProductCategory values
-- somewhere in the set. Expected: 0 rows returned by each query.
-- ---------------------------------------------------------------------------
SELECT ProductName, COUNT(DISTINCT ProductCategory) AS Distinct_Categories
FROM   PRODUCT
GROUP  BY ProductName
HAVING COUNT(DISTINCT ProductCategory) > 1;

SELECT CountryName, COUNT(DISTINCT Continent) AS Distinct_Continents
FROM   COUNTRY
GROUP  BY CountryName
HAVING COUNT(DISTINCT Continent) > 1;
GO


-- ---------------------------------------------------------------------------
-- TEST 4: measure integrity
-- Expected: 0 negatives, 0 NULLs.
-- ---------------------------------------------------------------------------
SELECT SUM(CASE WHEN ValueGWh < 0 THEN 1 ELSE 0 END)  AS Negative_Values,
       SUM(CASE WHEN ValueGWh IS NULL THEN 1 ELSE 0 END) AS Null_Values,
       COUNT(*)                                       AS Total_Rows
FROM   FactMonthlyElectricity;
GO


-- ---------------------------------------------------------------------------
-- TEST 5: physical column types
--
-- Check ValueGWh is DECIMAL(18,4). A lower scale silently rounds every
-- fractional value, and the error is invisible in the reporting tier.
-- ---------------------------------------------------------------------------
SELECT  t.name AS TableName, c.name AS ColumnName, ty.name AS DataType,
        c.max_length, c.precision, c.scale, c.is_nullable
FROM    sys.columns c
JOIN    sys.tables  t  ON t.object_id     = c.object_id
JOIN    sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE   t.name IN ('FactMonthlyElectricity','COUNTRY','PRODUCT',
                   'BALANCE','DATE','UNIT')
ORDER BY t.name, c.column_id;
GO


-- ---------------------------------------------------------------------------
-- RECONCILIATION: balance flow row counts
--
-- The six balance flows account for 148,394 rows carrying a positive measure.
-- 159,739 total minus 148,394 leaves exactly 11,345, which is the count of
-- rows carrying a genuine reported zero. The filter therefore excludes exactly
-- the legitimate zeros and nothing further. No rows are unaccounted for.
-- ---------------------------------------------------------------------------
SELECT  b.BalanceName, b.BalanceCategory, b.BalanceGroup,
        COUNT(*) AS Rows_Positive_Measure
FROM    FactMonthlyElectricity f
JOIN    BALANCE b ON b.BalanceID = f.BalanceID
WHERE   f.ValueGWh > 0
GROUP BY b.BalanceName, b.BalanceCategory, b.BalanceGroup
ORDER BY Rows_Positive_Measure DESC;

SELECT COUNT(*) AS Total_Rows,
       SUM(CASE WHEN ValueGWh > 0 THEN 1 ELSE 0 END)  AS Positive_Rows,
       SUM(CASE WHEN ValueGWh = 0 THEN 1 ELSE 0 END)  AS Genuine_Zero_Rows
FROM   FactMonthlyElectricity;
GO


-- ---------------------------------------------------------------------------
-- RECONCILIATION: leaf sum against the stored IEA total
--
-- This control exists only because the rollup rows were flagged rather than
-- deleted. Small residual variance is expected where the 'Not Specified'
-- member absorbs unreported generation.
-- ---------------------------------------------------------------------------
WITH leaf AS (
    SELECT DateID, CountryName, SUM(ValueGWh) AS LeafSum
    FROM   vw_ElectricityFacts_Leaf
    WHERE  BalanceName = 'Net Electricity Production'
    GROUP  BY DateID, CountryName
),
tot AS (
    SELECT DateID, CountryName, SUM(TotalGWh) AS StoredTotal
    FROM   vw_ElectricityTotals
    WHERE  BalanceName = 'Net Electricity Production'
    GROUP  BY DateID, CountryName
)
SELECT TOP 50
       t.CountryName, t.DateID,
       t.StoredTotal, l.LeafSum,
       t.StoredTotal - l.LeafSum AS Variance,
       CASE WHEN t.StoredTotal = 0 THEN NULL
            ELSE ROUND(100.0 * (t.StoredTotal - l.LeafSum) / t.StoredTotal, 2)
       END AS Variance_Pct
FROM   tot t
JOIN   leaf l ON l.DateID = t.DateID AND l.CountryName = t.CountryName
WHERE  ABS(t.StoredTotal - l.LeafSum) > 1
ORDER  BY ABS(t.StoredTotal - l.LeafSum) DESC;
GO

SET STATISTICS IO OFF;
GO
