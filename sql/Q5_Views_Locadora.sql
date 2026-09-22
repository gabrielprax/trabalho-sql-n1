-- VIEW 1: PERFIL GERENCIAL
USE sakila; 
 
DROP VIEW IF EXISTS vw_painel_locadora_gerencial; 
 
CREATE VIEW vw_painel_locadora_gerencial AS 
SELECT 
    YEAR(r.rental_date) AS ano, 
    MONTH(r.rental_date) AS mes, 
    i.store_id AS loja, 
    COUNT(r.rental_id) AS total_locacoes, 
    COUNT(DISTINCT r.customer_id) AS clientes_unicos, 
    COALESCE(SUM(p.amount), 0) AS receita_total, 
    ROUND( 
        COALESCE(SUM(p.amount), 0) / NULLIF(COUNT(r.rental_id), 0), 
        2 
    ) AS ticket_medio, 
    SUM( 
        CASE 
            WHEN r.return_date IS NOT NULL THEN 1 
            ELSE 0 
        END 
    ) AS locacoes_devolvidas, 
    SUM( 
        CASE 
            WHEN r.return_date IS NULL THEN 1 
            ELSE 0 
        END 
    ) AS locacoes_em_aberto 
FROM rental AS r 
INNER JOIN inventory AS i 
    ON r.inventory_id = i.inventory_id 
LEFT JOIN payment AS p 
    ON r.rental_id = p.rental_id 
GROUP BY 
    YEAR(r.rental_date), 
    MONTH(r.rental_date), 
    i.store_id; 
-- VIEW 2: PERFIL ANALÍTICO/DETALHADO
DROP VIEW IF EXISTS vw_painel_locadora_detalhadas; 
 
CREATE VIEW vw_painel_locadora_detalhadas AS 
SELECT 
    r.rental_id AS id_locacao, 
    r.rental_date AS data_locacao, 
    r.return_date AS data_devolucao, 
 
    c.customer_id AS id_cliente, 
    CONCAT(c.first_name, ' ', c.last_name) AS cliente, 
 
    f.film_id AS id_filme, 
    f.title AS filme, 
    cat.name AS categoria, 
 
    i.store_id AS loja, 
 
    s.staff_id AS id_funcionario, 
    CONCAT(s.first_name, ' ', s.last_name) AS funcionario, 
 
    COALESCE(p.amount, 0) AS valor_pago, 
    p.payment_date AS data_pagamento 
 
FROM rental AS r 
 
INNER JOIN inventory AS i 
    ON r.inventory_id = i.inventory_id 
 
INNER JOIN film AS f 
    ON i.film_id = f.film_id 
 
LEFT JOIN film_category AS fc 
    ON f.film_id = fc.film_id 
 
LEFT JOIN category AS cat 
    ON fc.category_id = cat.category_id 
 
INNER JOIN customer AS c 
    ON r.customer_id = c.customer_id 
 
INNER JOIN staff AS s 
    ON r.staff_id = s.staff_id 
 
LEFT JOIN payment AS p 
    ON r.rental_id = p.rental_id; 
-- TESTES DAS VIEWS
View gerencial (Primeira) 
SELECT * 
FROM vw_painel_locadora_gerencial 
ORDER BY ano, mes, loja; 
View detalhada(segunda  (carregar apenas as 20 e não milhares)) 
SELECT * 
FROM vw_painel_locadora_detalhadas 
LIMIT 20; 
