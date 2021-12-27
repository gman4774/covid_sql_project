--Data was downloaded from here: https://ourworldindata.org/covid-deaths

-- Create smaller table only with data I want to use

SELECT [iso_code]
      ,[continent]
      ,[location]
      ,[date]
	  ,[population]
      ,[total_cases]
      ,[new_cases]
      ,[total_deaths]
      ,[new_deaths]
      ,[icu_patients]
      ,[hosp_patients]
INTO covid_short
FROM [dbo].[owid-covid-data (2)];

--View top of new table to verify everything is ok 

SELECT TOP(10) *
FROM [dbo].[covid_short];

--Quick look at the country with the most recorded deaths

SELECT location, MAX(total_deaths) AS mx
FROM [dbo].[covid_short]
GROUP BY location
ORDER BY mx DESC;

--Looking at the schema to verify column data types

USE covid;
SELECT *
FROM INFORMATION_SCHEMA.columns
WHERE TABLE_NAME = 'covid_short';

--Columns need to be cleaned and data types need to be changed

SELECT MAX(LEN(iso_code)) FROM [dbo].[covid_short];

SELECT iso_code, RIGHT(iso_code, 3) AS trimmed_iso
FROM [dbo].[covid_short]
WHERE LEN(iso_code) > 3;

UPDATE [dbo].[covid_short]
SET iso_code = RIGHT(ISO_code, 3)
WHERE LEN(iso_code) > 3;

SELECT iso_code
FROM [dbo].[covid_short];

--Update column to correct data type

ALTER TABLE [dbo].[covid_short]
ALTER COLUMN iso_code VARCHAR(3);

--Update date column

ALTER TABLE [dbo].[covid_short]
ALTER COLUMN date DATE;


--Update remaining columns to float

UPDATE [dbo].[covid_short]
SET population = CAST(population AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN population FLOAT(53);
--
UPDATE [dbo].[covid_short]
SET total_cases = CAST(total_cases AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN total_cases FLOAT(53);
--
UPDATE [dbo].[covid_short]
SET new_cases = CAST(new_cases AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN new_cases FLOAT(53);
--
UPDATE [dbo].[covid_short]
SET total_deaths = CAST(total_deaths AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN total_deaths FLOAT(53);
--
UPDATE [dbo].[covid_short]
SET new_deaths = CAST(new_deaths AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN new_deaths FLOAT(53);
--
UPDATE [dbo].[covid_short]
SET icu_patients = CAST(icu_patients AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN icu_patients FLOAT(53);
--
UPDATE [dbo].[covid_short]
SET hosp_patients = CAST(hosp_patients AS float(53));
ALTER TABLE [dbo].[covid_short] ALTER COLUMN hosp_patients FLOAT(53);

--Looking at total cases vs total deaths

SELECT location, date, total_cases, total_deaths, ROUND((total_deaths / NULLIF(total_cases, 0)) * 100, 2) AS deathpercentage
FROM covid_short
WHERE location LIKE '%state%'
ORDER BY 2 DESC;

--Looking at total cases vs population

SELECT continent, location, date, total_cases, population, ROUND((total_cases / NULLIF(population, 0)) * 100, 2) AS percent_pop_infected
FROM covid_short
WHERE location LIKE '%Canada%'
ORDER BY 2 DESC;

--Looking at countries with highest infection rate compared to population

SELECT location, population, MAX(total_cases) AS highest_infection_count, MAX(ROUND((total_cases / NULLIF(population, 0)) * 100, 2)) AS percent_pop_infected
FROM covid_short
GROUP BY location, population
ORDER BY 4 DESC;

--Showing countries with highest death count per population

SELECT location, MAX(total_deaths) AS total_death_count
FROM covid_short
GROUP BY location
ORDER BY 2 DESC;

--Breaking things down by continent

SELECT continent, MAX(total_deaths) AS total_death_count
FROM covid_short
--WHERE continent IS NOT NULL
WHERE DATALENGTH(continent) > 0
GROUP BY continent
ORDER BY total_death_count;

--Global total

SELECT SUM(sub.total_death_count) AS global_death_total
FROM(SELECT MAX(total_deaths) AS total_death_count
FROM covid_short
WHERE DATALENGTH(continent) > 0
GROUP BY continent) AS sub;

--Total population vs vaccinations

SELECT s.continent, s.location, s.date, s.population, o.new_vaccinations
FROM covid_short AS s
JOIN [dbo].[owid-covid-data (2)] AS o
ON s.location = o.location
AND s.date = o.date
WHERE DATALENGTH(s.continent) > 0
ORDER BY 2,3;

--Rolling vaccination count

SELECT s.continent, s.location, s.date, s.population, o.new_vaccinations, SUM(CAST(o.new_vaccinations AS FLOAT(53))) OVER(PARTITION BY s.location ORDER BY s.location, s.date) AS rolling_vac_count
FROM covid_short AS s
JOIN [dbo].[owid-covid-data (2)] AS o
ON s.location = o.location
AND s.date = o.date
WHERE DATALENGTH(s.continent) > 0
ORDER BY 2,3;

--Using CTE to find rolling percentage of population vaccinated

WITH popvsvac (continent, location, date, population, new_vaccinations, rolling_vac_count)
AS (
SELECT s.continent, s.location, s.date, s.population, o.new_vaccinations, SUM(CAST(o.new_vaccinations AS FLOAT(53))) OVER(PARTITION BY s.location ORDER BY s.location, s.date) AS rolling_vac_count
FROM covid_short AS s
JOIN [dbo].[owid-covid-data (2)] AS o
ON s.location = o.location
AND s.date = o.date
WHERE DATALENGTH(s.continent) > 0
)

SELECT *, (rolling_vac_count/NULLIF(population, 0)) * 100 AS rolling_per_pop_count
FROM popvsvac

--Store results into view

CREATE VIEW percentpopvac AS 
SELECT s.continent, s.location, s.date, s.population, o.new_vaccinations, SUM(CAST(o.new_vaccinations AS FLOAT(53))) OVER(PARTITION BY s.location ORDER BY s.location, s.date) AS rolling_vac_count
FROM covid_short AS s
JOIN [dbo].[owid-covid-data (2)] AS o
ON s.location = o.location
AND s.date = o.date
WHERE DATALENGTH(s.continent) > 0

