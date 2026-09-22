-- ============================================================
-- Trabalho Prático SQL N1
-- Q4 - Procedure de relatório
-- Banco: Sakila
-- SGBD: MySQL 8.4+
-- ============================================================
--
-- Objetivo:
-- Gerar um relatório consolidado de desempenho por categoria,
-- considerando locações e pagamentos em um período informado.
--
-- Parâmetros:
--   p_data_inicio : DATE
--   p_data_fim    : DATE
--   p_categoria   : VARCHAR(25), ou NULL para todas as categorias
--
-- O relatório apresenta:
--   - total de locações;
--   - clientes únicos;
--   - receita total;
--   - ticket médio;
--   - ranking de receita por categoria.
-- ============================================================

USE sakila;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_relatorio_desempenho_vendas$$

CREATE PROCEDURE sp_relatorio_desempenho_vendas(
    IN p_data_inicio DATE,
    IN p_data_fim DATE,
    IN p_categoria VARCHAR(25)
)
BEGIN

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Erro inesperado ao gerar o relatório. Verifique os parâmetros informados.';
    END;

    SET p_data_inicio = IFNULL(p_data_inicio, '2005-01-01');
    SET p_data_fim = IFNULL(p_data_fim, CURDATE());

    IF p_data_inicio > p_data_fim THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Parâmetros inválidos: a data de início não pode ser maior que a data de fim.';
    END IF;

    IF p_categoria IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM category
           WHERE name = p_categoria
       ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Categoria informada não existe na base de dados.';
    END IF;

    WITH locacoes_periodo AS (
        SELECT
            cat.name AS categoria,
            r.rental_id,
            r.customer_id,
            COALESCE(p.amount, 0) AS valor_pago
        FROM rental AS r
        INNER JOIN inventory AS i
            ON r.inventory_id = i.inventory_id
        INNER JOIN film AS f
            ON i.film_id = f.film_id
        INNER JOIN film_category AS fc
            ON f.film_id = fc.film_id
        INNER JOIN category AS cat
            ON fc.category_id = cat.category_id
        LEFT JOIN payment AS p
            ON r.rental_id = p.rental_id
        WHERE DATE(r.rental_date) BETWEEN p_data_inicio AND p_data_fim
          AND (p_categoria IS NULL OR cat.name = p_categoria)
    ),
    resumo AS (
        SELECT
            categoria,
            COUNT(rental_id) AS total_locacoes,
            COUNT(DISTINCT customer_id) AS clientes_unicos,
            SUM(valor_pago) AS receita_total,
            ROUND(AVG(valor_pago), 2) AS ticket_medio
        FROM locacoes_periodo
        GROUP BY categoria
    )
    SELECT
        categoria,
        total_locacoes,
        clientes_unicos,
        receita_total,
        ticket_medio,
        RANK() OVER (
            ORDER BY receita_total DESC
        ) AS ranking_receita
    FROM resumo
    ORDER BY receita_total DESC;

END$$

DELIMITER ;
