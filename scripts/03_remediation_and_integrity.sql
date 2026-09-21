/*
===============================================================================
  GridPulse - 03: Data quality remediation and integrity enforcement
===============================================================================
  These defects were inherited unchanged from the source. None of them caused a
  load failure, which is precisely why they survived to the presentation tier
  and broke the SSRS reports.

  They are fixed HERE, in the database, rather than with conditional expressions
  in each report. A presentation-layer workaround must be repeated in every
  report that touches the field, and a report added later will not have it.
===============================================================================
*/

USE IEA_Analytics_DW;
GO

-- ---------------------------------------------------------------------------
-- DEFECT 1: literal 'NULL' stored as four characters of text
--
-- 19,202 fact rows for ISOCode, 6,834 for EnergyGroup. Effect: every ISNULL
-- and IsNothing check in the reports was dead code, and the word NULL printed
-- in report cells. Cause: the SSIS flat file source read every column as
-- DT_STR, so nothing failed and Ignore Failure never engaged.
-- ---------------------------------------------------------------------------
UPDATE COUNTRY SET ISOCode     = NULL WHERE ISOCode     IN ('NULL','null','NA','N/A','');
UPDATE PRODUCT SET EnergyGroup = NULL WHERE EnergyGroup IN ('NULL','null','NA','N/A','');
GO

-- Trim latent whitespace while here. Whitespace in a lookup key produces a
-- silent no-match, which is what left the fact table empty on early loads.
UPDATE COUNTRY SET CountryName = LTRIM(RTRIM(CountryName)),
                   Region      = LTRIM(RTRIM(Region)),
                   Continent   = LTRIM(RTRIM(Continent));

UPDATE PRODUCT SET ProductName     = LTRIM(RTRIM(ProductName)),
                   ProductCategory = LTRIM(RTRIM(ProductCategory)),
                   SubCategory     = LTRIM(RTRIM(SubCategory));
GO


-- ---------------------------------------------------------------------------
-- DEFECT 2: September abbreviated two ways
--
-- 13,174 rows carried 'Sept-19' against 146,565 using 'Sep-19'. An SSRS matrix
-- grouped on MonthYear treats those as two distinct column groups, which is
-- the cause of the missing and duplicated column headers.
-- ---------------------------------------------------------------------------
UPDATE [DATE]
SET    MonthYear = REPLACE(MonthYear, 'Sept-', 'Sep-')
WHERE  MonthYear LIKE 'Sept-%';
GO

-- Verify: every prefix should now be exactly 3 characters
SELECT DISTINCT
       LEFT(MonthYear, CHARINDEX('-', MonthYear) - 1)      AS Prefix,
       LEN(LEFT(MonthYear, CHARINDEX('-', MonthYear) - 1)) AS PrefixLen
FROM   [DATE]
ORDER  BY PrefixLen DESC, Prefix;
GO


-- ---------------------------------------------------------------------------
-- DEFECT 3: MonthYear is text, so it sorts alphabetically
--
-- Apr-10, Apr-11, Apr-12, Aug-10 ... An integer sort key fixes this. Every
-- chronological axis and column group in the BI tier sorts on MonthSortKey,
-- never on MonthYear.
--
-- DEFECT 4: no true DATE column. DateID is an integer smart key, which SSRS
-- and Tableau cannot use for date parameters or continuous axes.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('[DATE]','FullDate') IS NULL
    ALTER TABLE [DATE] ADD FullDate DATE NULL;
IF COL_LENGTH('[DATE]','MonthSortKey') IS NULL
    ALTER TABLE [DATE] ADD MonthSortKey INT NULL;
GO

UPDATE [DATE] SET FullDate     = DATEFROMPARTS([Year], MonthNumber, 1);
UPDATE [DATE] SET MonthSortKey = ([Year] * 100) + MonthNumber;
GO

ALTER TABLE [DATE] ALTER COLUMN FullDate DATE NOT NULL;
GO


-- ---------------------------------------------------------------------------
-- INTEGRITY ENFORCEMENT
--
-- Applied WITH CHECK so existing rows are validated at creation time. If any
-- of these statements fails, orphaned keys genuinely exist and the error names
-- the constraint. Each executed successfully against the populated warehouse,
-- which independently corroborates the audit results in script 06.
-- ---------------------------------------------------------------------------
ALTER TABLE FactMonthlyElectricity WITH CHECK
    ADD CONSTRAINT FK_Fact_Country FOREIGN KEY (CountryID) REFERENCES COUNTRY(CountryID);
ALTER TABLE FactMonthlyElectricity WITH CHECK
    ADD CONSTRAINT FK_Fact_Product FOREIGN KEY (ProductID) REFERENCES PRODUCT(ProductID);
ALTER TABLE FactMonthlyElectricity WITH CHECK
    ADD CONSTRAINT FK_Fact_Balance FOREIGN KEY (BalanceID) REFERENCES BALANCE(BalanceID);
ALTER TABLE FactMonthlyElectricity WITH CHECK
    ADD CONSTRAINT FK_Fact_Date    FOREIGN KEY (DateID)    REFERENCES [DATE](DateID);
ALTER TABLE FactMonthlyElectricity WITH CHECK
    ADD CONSTRAINT FK_Fact_Unit    FOREIGN KEY (UnitID)    REFERENCES UNIT(UnitID);
GO

-- Protect the declared grain. Fails loudly on a repeated ETL execution.
ALTER TABLE FactMonthlyElectricity
    ADD CONSTRAINT UQ_Fact_Grain UNIQUE (DateID, CountryID, ProductID, BalanceID);

ALTER TABLE FactMonthlyElectricity
    ADD CONSTRAINT CK_Fact_ValueGWh CHECK (ValueGWh >= 0);
GO
