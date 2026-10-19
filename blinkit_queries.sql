/* 
=============================================================================
Project: Blinkit Grocery Sales Analysis
RDBMS: PostgreSQL
Skills: Data Staging, CTEs, Window Functions, Aggregations, Data Cleaning
=============================================================================
*/

-- ==========================================
-- PHASE 1: DATABASE SETUP & DATA STAGING
-- ==========================================

-- 1. Create the database
-- CREATE DATABASE blinkit_analytics;

-- 2. Create a staging table with TEXT data types to safely import raw CSV
CREATE TABLE blinkit_staging (
    item_identifier TEXT,
    item_weight TEXT,
    item_fat_content TEXT,
    item_visibility TEXT,
    item_type TEXT,
    item_mrp TEXT,
    outlet_identifier TEXT,
    outlet_establishment_year TEXT,
    outlet_size TEXT,
    outlet_location_type TEXT,
    outlet_type TEXT,
    item_outlet_sales TEXT
);

-- 3. Import raw data from CSV
-- COPY blinkit_staging FROM 'C:\temp\Grocery_Sales.csv' DELIMITER ',' CSV HEADER;

-- ==========================================
-- PHASE 2: DATA CLEANING & TYPE CASTING
-- ==========================================

-- Standardize categorical strings and cast numerical values safely
CREATE TABLE blinkit_cleaned AS
SELECT 
    item_identifier,
    CAST(NULLIF(item_weight, '') AS NUMERIC(10,2)) AS item_weight,
    
    CASE 
        WHEN item_fat_content IN ('LF', 'low fat', 'Low Fat') THEN 'Low Fat'
        WHEN item_fat_content IN ('reg', 'Regular') THEN 'Regular'
        ELSE item_fat_content 
    END AS item_fat_content,
    
    CAST(NULLIF(item_visibility, '') AS NUMERIC(10,4)) AS item_visibility,
    item_type,
    CAST(NULLIF(item_mrp, '') AS NUMERIC(10,2)) AS item_mrp,
    outlet_identifier,
    CAST(NULLIF(outlet_establishment_year, '') AS INT) AS outlet_establishment_year,
    outlet_size,
    outlet_location_type,
    outlet_type,
    CAST(NULLIF(item_outlet_sales, '') AS NUMERIC(10,2)) AS item_outlet_sales
FROM blinkit_staging;


-- ==========================================
-- PHASE 3: CORE KPI & CATEGORY ANALYTICS
-- ==========================================

-- 1. High-Level Performance Metrics
SELECT 
    ROUND(SUM(item_outlet_sales), 2) AS total_revenue,
    COUNT(DISTINCT item_identifier) AS total_items_sold,
    ROUND(AVG(item_outlet_sales), 2) AS avg_sales_per_item
FROM blinkit_cleaned;

-- 2. Top 5 Highest-Grossing Product Categories
SELECT 
    item_type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(item_outlet_sales), 2) AS category_revenue,
    ROUND(
        (SUM(item_outlet_sales) * 100.0) / (SELECT SUM(item_outlet_sales) FROM blinkit_cleaned), 
        2
    ) AS pct_of_total_revenue
FROM blinkit_cleaned
GROUP BY item_type
ORDER BY category_revenue DESC
LIMIT 5;

-- 3. Customer Fat Content Preference
SELECT 
    item_fat_content,
    COUNT(*) AS total_items,
    ROUND(SUM(item_outlet_sales), 2) AS total_sales,
    ROUND(AVG(item_outlet_sales), 2) AS avg_sales
FROM blinkit_cleaned
GROUP BY item_fat_content
ORDER BY total_sales DESC;


-- ==========================================
-- PHASE 4: OUTLET PERFORMANCE & EFFICIENCY
-- ==========================================

-- 4. Sales by Outlet Location Tier & Outlet Type
SELECT 
    outlet_location_type,
    outlet_type,
    COUNT(DISTINCT outlet_identifier) AS outlet_count,
    ROUND(SUM(item_outlet_sales), 2) AS total_sales,
    ROUND(AVG(item_outlet_sales), 2) AS avg_sales_per_item
FROM blinkit_cleaned
GROUP BY outlet_location_type, outlet_type
ORDER BY total_sales DESC;

-- 5. Outlet Efficiency Filtering (High-performing stores only)
SELECT 
    outlet_identifier,
    outlet_establishment_year,
    outlet_size,
    outlet_location_type,
    outlet_type,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(item_outlet_sales), 2) AS total_revenue,
    ROUND(AVG(item_outlet_sales), 2) AS avg_item_sales
FROM blinkit_cleaned
GROUP BY 
    outlet_identifier, 
    outlet_establishment_year, 
    outlet_size, 
    outlet_location_type, 
    outlet_type
HAVING 
    SUM(item_outlet_sales) > 2000000 
    AND AVG(item_outlet_sales) > 2100
ORDER BY total_revenue DESC;


-- ==========================================
-- PHASE 5: ADVANCED SQL (WINDOW FUNCTIONS)
-- ==========================================

-- 6. Top 3 Revenue-Generating Items in Each Category
WITH CategoryItemSales AS (
    SELECT 
        item_type,
        item_identifier,
        ROUND(SUM(item_outlet_sales), 2) AS total_item_sales,
        DENSE_RANK() OVER (
            PARTITION BY item_type 
            ORDER BY SUM(item_outlet_sales) DESC
        ) AS rank_in_category
    FROM blinkit_cleaned
    GROUP BY item_type, item_identifier
)
SELECT 
    item_type,
    rank_in_category,
    item_identifier,
    total_item_sales
FROM CategoryItemSales
WHERE rank_in_category <= 3
ORDER BY item_type, rank_in_category;

-- 7. Outlet Performance Contribution (% Share via Window Functions)
SELECT 
    outlet_identifier,
    outlet_type,
    outlet_location_type,
    ROUND(SUM(item_outlet_sales), 2) AS outlet_revenue,
    ROUND(
        (SUM(item_outlet_sales) * 100.0) / SUM(SUM(item_outlet_sales)) OVER (),
        2
    ) AS pct_contribution_to_total
FROM blinkit_cleaned
GROUP BY outlet_identifier, outlet_type, outlet_location_type
ORDER BY outlet_revenue DESC;
