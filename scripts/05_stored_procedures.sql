/*
===============================================================================
  GridPulse - 05: Server-side stored procedures for the parameterised report
===============================================================================
  Filtering happens on the database server rather than in the report, so only
  the requested rows traverse the network.

  Requires SQL Server 2016 or later for STRING_SPLIT.
===============================================================================
*/

USE IEA_Analytics_DW;
GO

-- ---------------------------------------------------------------------------
-- Populates the country dropdown.
--
-- The ISNULL wrapper is required: concatenating a NULL in T-SQL yields NULL
-- for the entire expression, which would blank the whole label rather than
-- just the missing ISO code.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_RPT_CountryList
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
           CountryName AS ParamValue,
           CountryName + ' (' + ISNULL(ISOCode, 'n/a') + ')' AS ParamLabel,
           Region,
           Continent
    FROM   dbo.vw_ElectricityFacts_Leaf
    ORDER  BY CountryName;
END;
GO


-- ---------------------------------------------------------------------------
-- The report body.
--
-- Sources from the governed view, so aggregate exclusion is inherited and
-- cannot be bypassed. NULLIF guards the window-function denominator against a
-- country-year with no recorded generation.
--
-- In the SSRS dataset parameter mapping, the value expression MUST be
--     =Join(Parameters!CountryName.Value, ",")
-- Passing the parameter directly transmits only the first selection, which
-- presents as a data problem rather than a configuration one.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_RPT_CountryEnergyProfile
    @CountryName  NVARCHAR(200),
    @StartYear    INT = 2010,
    @EndYear      INT = 2025,
    @BalanceName  NVARCHAR(50) = 'Net Electricity Production'
AS
BEGIN
    SET NOCOUNT ON;

    -- Fail loudly. Returning an empty set silently is worse, because the user
    -- concludes there is genuinely no data.
    IF @StartYear > @EndYear
    BEGIN
        RAISERROR('Start year cannot be later than end year.', 16, 1);
        RETURN;
    END

    ;WITH SelectedCountries AS (
        SELECT LTRIM(RTRIM(value)) AS CountryName
        FROM   STRING_SPLIT(@CountryName, ',')
        WHERE  LTRIM(RTRIM(value)) <> ''
    )
    SELECT  f.CountryName,
            f.ISOCode,
            f.Region,
            f.Continent,
            f.EU_Member,
            f.[Year],
            f.MonthYear,
            f.MonthSortKey,
            f.ProductName,
            f.ProductCategory,
            f.RenewableFlag,
            f.IntermittentFlag,
            f.DispatchableFlag,
            f.ValueGWh,
            SUM(f.ValueGWh) OVER (PARTITION BY f.CountryName, f.[Year])
                AS CountryYearTotal,
            CAST(100.0 * f.ValueGWh
                 / NULLIF(SUM(f.ValueGWh) OVER
                          (PARTITION BY f.CountryName, f.[Year]), 0)
                 AS DECIMAL(5,2)) AS PctOfYearTotal
    FROM    dbo.vw_ElectricityFacts_Leaf f
    JOIN    SelectedCountries s ON s.CountryName = f.CountryName
    WHERE   f.BalanceName = @BalanceName
      AND   f.[Year] BETWEEN @StartYear AND @EndYear
    ORDER BY f.CountryName, f.MonthSortKey, f.ProductName;
END;
GO
