/*
===============================================================================
  GridPulse - 01: Layer deployment and conformed star schema
===============================================================================
  Creates the three logical layer databases, the operational data store landing
  table, and the analytical star schema.

  WARNING: this script drops and recreates tables in IEA_Analytics_DW. Existing
  data in those tables will be lost. Read before running.

  SCOPE: this is the database layer, run in SQL Server Management Studio.
  It does NOT load data. Row movement was performed by SSIS packages; see
  docs/ARCHITECTURE.md for the pipeline.

  Sequence:
      01 (this script)  ->  SSIS load  ->  02  ->  03  ->  04  ->  05
      06 is read-only and can be run at any point.
===============================================================================
*/

-- ---------------------------------------------------------------------------
-- STEP 1: Deploy the three logical layer databases
-- ---------------------------------------------------------------------------
USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'IEA_Grid_Operations')
    CREATE DATABASE IEA_Grid_Operations;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'IEA_Governance_Registry')
    CREATE DATABASE IEA_Governance_Registry;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'IEA_Analytics_DW')
    CREATE DATABASE IEA_Analytics_DW;
GO


-- ---------------------------------------------------------------------------
-- STEP 2: Operational data store landing table
--
-- Every column is NVARCHAR deliberately. Typing at the landing boundary causes
-- conversion failure on ingestion, at which point the offending value is lost.
-- Landing as text guarantees the full source payload reaches a queryable
-- surface, after which conversion happens under observation.
-- ---------------------------------------------------------------------------
USE IEA_Grid_Operations;
GO

DROP TABLE IF EXISTS RawGridLog;
GO

CREATE TABLE RawGridLog (
    CountryString   NVARCHAR(150),
    ReadingDate     NVARCHAR(50),
    BalanceString   NVARCHAR(150),
    ProductString   NVARCHAR(150),
    UnitString      NVARCHAR(50),
    RecordedValue   NVARCHAR(50)
);
GO


-- ---------------------------------------------------------------------------
-- STEP 3: Analytical star schema
-- ---------------------------------------------------------------------------
USE IEA_Analytics_DW;
GO

DROP TABLE IF EXISTS FactMonthlyElectricity;
DROP TABLE IF EXISTS COUNTRY;
DROP TABLE IF EXISTS PRODUCT;
DROP TABLE IF EXISTS BALANCE;
DROP TABLE IF EXISTS UNIT;
DROP TABLE IF EXISTS [DATE];
GO

-- COUNTRY: 48 sovereign states plus 5 IEA regional aggregates.
-- ISOCode is NVARCHAR(10) rather than CHAR(3) because aggregate members carry
-- no ISO code and the source delivers the literal string 'NULL' for them,
-- which is four characters. Script 03 converts those to true NULL.
CREATE TABLE COUNTRY (
    CountryID       INT IDENTITY(1,1) PRIMARY KEY,
    CountryName     NVARCHAR(150) NOT NULL,
    ISOCode         NVARCHAR(10)  NULL,
    Region          NVARCHAR(100),
    Continent       NVARCHAR(100),
    EU_Member       CHAR(1)
);

-- PRODUCT: 12 leaf fuel lines plus 3 pre-calculated rollups.
-- RenewableFlag is environmental. IntermittentFlag and DispatchableFlag are
-- operational. They are kept independent: hydro is renewable and dispatchable,
-- solar is renewable and intermittent, nuclear is neither.
-- ProductName is NVARCHAR(150): the longest real value is 49 characters
-- ('Total Renewables (Hydro, Geo, Solar, Wind, Other)').
CREATE TABLE PRODUCT (
    ProductID        INT IDENTITY(1,1) PRIMARY KEY,
    ProductName      NVARCHAR(150) NOT NULL,
    ProductCategory  NVARCHAR(100),
    SubCategory      NVARCHAR(100),
    EnergyGroup      NVARCHAR(100)  NULL,
    RenewableFlag    CHAR(1),
    FossilFlag       CHAR(1),
    IntermittentFlag CHAR(1),
    DispatchableFlag CHAR(1)
);

CREATE TABLE BALANCE (
    BalanceID        INT IDENTITY(1,1) PRIMARY KEY,
    BalanceName      NVARCHAR(150) NOT NULL,
    BalanceCategory  NVARCHAR(100),
    BalanceGroup     NVARCHAR(100)
);

-- UNIT is degenerate in the current implementation: a single member (GWh)
-- applies to every fact row. Retained as an extension point for a future
-- multi-unit model. See docs/DESIGN_DECISIONS.md.
CREATE TABLE UNIT (
    UnitID           INT IDENTITY(1,1) PRIMARY KEY,
    UnitName         NVARCHAR(50) NOT NULL,
    UnitSymbol       NVARCHAR(50) NOT NULL,
    UnitType         NVARCHAR(100),
    ConversionToSI   DECIMAL(18,9)
);

-- DateID is a smart key in YYYYMM form, chosen for sortability and for
-- legibility during ETL debugging. FullDate and MonthSortKey are added in
-- script 03 to support date parameters and continuous axes in the BI tier.
CREATE TABLE [DATE] (
    DateID           INT PRIMARY KEY,
    [Year]           INT,
    MonthNumber      INT,
    MonthName        NVARCHAR(50),
    Quarter          CHAR(2),
    MonthYear        NVARCHAR(10)
);

-- Grain: one row per country, per month, per product, per balance flow.
-- ValueGWh is DECIMAL(18,4) because the source carries up to four decimal
-- places. A lower scale would silently round every fractional value.
CREATE TABLE FactMonthlyElectricity (
    FactID     INT IDENTITY(1,1) PRIMARY KEY,
    DateID     INT FOREIGN KEY REFERENCES [DATE](DateID),
    CountryID  INT FOREIGN KEY REFERENCES COUNTRY(CountryID),
    BalanceID  INT FOREIGN KEY REFERENCES BALANCE(BalanceID),
    ProductID  INT FOREIGN KEY REFERENCES PRODUCT(ProductID),
    UnitID     INT FOREIGN KEY REFERENCES UNIT(UnitID),
    ValueGWh   DECIMAL(18,4) NOT NULL
);
GO
