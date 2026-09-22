-- Q1 - Panorama temporal e ranking
-- Banco de dados: Sakila
-- SGBD: MySQL 8.4 LTS
--
-- Objetivo:
-- 1. Apresentar a evolução mensal das locações por categoria;
-- 2. Identificar os 3 filmes mais alugados de cada categoria em cada mês;
-- 3. Calcular a variação percentual das locações da categoria em relação ao mês anterior;
-- 4. Preservar empates no ranking utilizando DENSE_RANK().

USE sakila;

WITH locacoes_por_categoria_mes AS (
    SELECT
        DATE_FORMAT(r.rental_date, '%Y-%m') AS ano_mes,
        c.category_id,
        c.name AS categoria,
        COUNT(*) AS total_locacoes
    FROM rental AS r
    INNER JOIN inventory AS i
        ON r.inventory_id = i.inventory_id
    INNER JOIN film AS f
        ON i.film_id = f.film_id
    INNER JOIN film_category AS fc
        ON f.film_id = fc.film_id
    INNER JOIN category AS c
        ON fc.category_id = c.category_id
    GROUP BY
        DATE_FORMAT(r.rental_date, '%Y-%m'),
        c.category_id,
        c.name
),

tendencia_categoria AS (
    SELECT
        ano_mes,
        category_id,
        categoria,
        total_locacoes,
        LAG(total_locacoes) OVER (
            PARTITION BY category_id
            ORDER BY ano_mes
        ) AS locacoes_mes_anterior
    FROM locacoes_por_categoria_mes
),

locacoes_por_filme AS (
    SELECT
        DATE_FORMAT(r.rental_date, '%Y-%m') AS ano_mes,
        c.category_id,
        c.name AS categoria,
        f.film_id,
        f.title AS filme,
        COUNT(*) AS total_locacoes_filme
    FROM rental AS r
    INNER JOIN inventory AS i
        ON r.inventory_id = i.inventory_id
    INNER JOIN film AS f
        ON i.film_id = f.film_id
    INNER JOIN film_category AS fc
        ON f.film_id = fc.film_id
    INNER JOIN category AS c
        ON fc.category_id = c.category_id
    GROUP BY
        DATE_FORMAT(r.rental_date, '%Y-%m'),
        c.category_id,
        c.name,
        f.film_id,
        f.title
),

ranking_filmes AS (
    SELECT
        ano_mes,
        category_id,
        categoria,
        film_id,
        filme,
        total_locacoes_filme,
        DENSE_RANK() OVER (
            PARTITION BY category_id, ano_mes
            ORDER BY total_locacoes_filme DESC
        ) AS ranking
    FROM locacoes_por_filme
)

SELECT
    rf.ano_mes,
    rf.categoria,
    tc.total_locacoes AS total_locacoes_categoria,
    tc.locacoes_mes_anterior,
    ROUND(
        (
            (tc.total_locacoes - tc.locacoes_mes_anterior)
            / NULLIF(tc.locacoes_mes_anterior, 0)
        ) * 100,
        2
    ) AS variacao_percentual,
    rf.ranking,
    rf.filme,
    rf.total_locacoes_filme
FROM ranking_filmes AS rf
INNER JOIN tendencia_categoria AS tc
    ON tc.ano_mes = rf.ano_mes
    AND tc.category_id = rf.category_id
WHERE rf.ranking <= 3
ORDER BY
    rf.ano_mes,
    rf.categoria,
    rf.ranking,
    rf.filme;
