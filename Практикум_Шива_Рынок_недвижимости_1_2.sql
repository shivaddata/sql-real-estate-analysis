/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Шива Дарья 
 * Дата: 08.06.2026
*/

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных

analysis_data AS (
    SELECT
        a.id,
        c.city,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        CASE
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            WHEN a.days_exposition > 180 THEN '181+ days'
            ELSE 'non category'
        END AS exposition_category,
        CASE
            WHEN c.city = 'Санкт-Петербург'
                THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS region
    FROM real_estate.advertisement AS a
    INNER JOIN filtered_id AS fi ON a.id = fi.id
    INNER JOIN real_estate.flats AS f ON a.id = f.id
    INNER JOIN real_estate.city AS c ON f.city_id = c.city_id
    INNER JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 AND t.type = 'город'
)

SELECT
    region,
    exposition_category,
    COUNT(*) AS ads_cnt,
    ROUND(AVG(last_price / total_area)::numeric, 2) AS avg_price_m2,
    ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
    ROUND(AVG(rooms)::numeric, 2) AS avg_rooms,
    ROUND(AVG(balcony)::numeric, 2) AS avg_balcony
FROM analysis_data
GROUP BY
    region,
    exposition_category
ORDER BY
    region,
    exposition_category;
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------    
-- Задача 2: Сезонность объявлений                                                     ИСПРАВЛЕНО ПОСЛЕ РЕВЬЮ
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
    
base AS (
    SELECT
        a.id,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.type_id,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publish_month,
        EXTRACT(MONTH FROM (a.first_day_exposition + INTERVAL '1 day' * a.days_exposition)) AS close_month,
        a.last_price / NULLIF(f.total_area, 0) AS price_per_m2
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    JOIN filtered_id AS fi ON fi.id = f.id
    JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE
        t.type = 'город'
        AND a.first_day_exposition >= '2015-01-01'
        AND a.first_day_exposition < '2019-01-01'
),

publish_stats AS (
    SELECT
        publish_month AS month,
        COUNT(*) AS published_ads,
        AVG(price_per_m2) AS avg_price_m2,
        AVG(total_area) AS avg_area
    FROM base
    GROUP BY publish_month
),

close_stats AS (
    SELECT
        close_month AS month,
        COUNT(*) AS closed_ads,
        AVG(price_per_m2) AS avg_price_m2,
        AVG(total_area) AS avg_area
    FROM base
    GROUP BY close_month
)

SELECT
    COALESCE(p.month, c.month) AS month,
    p.published_ads,
    c.closed_ads,
    p.avg_price_m2 AS publish_avg_price_m2,
    c.avg_price_m2 AS close_avg_price_m2,
    p.avg_area AS publish_avg_area,
    c.avg_area AS close_avg_area
FROM publish_stats AS  p
FULL JOIN close_stats AS c ON p.month = c.month
ORDER BY month;   
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    