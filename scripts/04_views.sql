/*
===============================================================================
  GridPulse - 04: Governed access layer
===============================================================================
  These two views are the boundary between the warehouse and everything
  downstream. Every SSRS dataset and every Tableau data source connects here,
  never to FactMonthlyElectricity directly.

  This is the control that prevents the 3.01x aggregation defect. The design
  principle is that the correct query must be the easy query: the exclusion is
  applied once at the boundary rather than depending on eight separate reports
  each remembering to filter.
===============================================================================
*/

USE IEA_Analytics_DW;
GO

-- ---------------------------------------------------------------------------
-- vw_ElectricityFacts_Leaf
-- Additive. Safe to SUM along any axis. Leaf countries and leaf products only.
-- ---------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_ElectricityFacts_Leaf
AS
SELECT  f.FactID,
        d.DateID, d.FullDate, d.[Year], d.MonthNumber, d.MonthName,
        d.MonthYear, d.MonthSortKey, d.Quarter,
        c.CountryName, c.ISOCode, c.Region, c.Continent, c.EU_Member,
        p.ProductName, p.ProductCategory, p.SubCategory,
        p.RenewableFlag, p.FossilFlag, p.EnergyGroup,
        p.IntermittentFlag, p.DispatchableFlag,
        b.BalanceName, b.BalanceCategory, b.BalanceGroup,
        f.ValueGWh,
        u.UnitSymbol, u.UnitName
FROM    FactMonthlyElectricity f
JOIN    [DATE]  d ON d.DateID    = f.DateID
JOIN    COUNTRY c ON c.CountryID = f.CountryID
JOIN    PRODUCT p ON p.ProductID = f.ProductID
JOIN    BALANCE b ON b.BalanceID = f.BalanceID
JOIN    UNIT    u ON u.UnitID    = f.UnitID
WHERE   c.IsAggregate = 0
  AND   p.IsAggregate = 0;
GO


-- ---------------------------------------------------------------------------
-- vw_ElectricityTotals
-- The pre-calculated 'Electricity' total per country and month. Use for
-- headline figures and for trade balances, which only ever carry the
-- 'Electricity' product.
--
-- NEVER combine this with the leaf view in a single SUM. They overlap.
-- ---------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_ElectricityTotals
AS
SELECT  d.DateID, d.FullDate, d.MonthYear, d.MonthSortKey,
        d.[Year], d.Quarter,
        c.CountryName, c.ISOCode, c.Region, c.Continent, c.EU_Member,
        b.BalanceName, b.BalanceCategory,
        f.ValueGWh AS TotalGWh
FROM    FactMonthlyElectricity f
JOIN    [DATE]  d ON d.DateID    = f.DateID
JOIN    COUNTRY c ON c.CountryID = f.CountryID
JOIN    PRODUCT p ON p.ProductID = f.ProductID
JOIN    BALANCE b ON b.BalanceID = f.BalanceID
WHERE   c.IsAggregate = 0
  AND   p.ProductName = 'Electricity';
GO
