CREATE OR REPLACE VIEW vw_locacoes_atrasadas AS 
WITH locacoes AS ( 
    SELECT 
        r.rental_id AS ID, 
        CONCAT(c.first_name, ' ', c.last_name) AS CLIENTE, 
        f.title AS FILME, 
        i.store_id AS LOJA, 
 
        DATE(r.rental_date) AS LOCACAO, 
 
        DATE_ADD( 
            DATE(r.rental_date), 
            INTERVAL f.rental_duration DAY 
        ) AS PREVISTA, 
 
        DATE(r.return_date) AS DEVOLUCAO, 
 
        DATEDIFF( 
            DATE(r.return_date), 
            DATE_ADD( 
                DATE(r.rental_date), 
                INTERVAL f.rental_duration DAY 
            ) 
        ) AS ATRASO 
 
    FROM rental r 
 
    INNER JOIN customer c 
        ON r.customer_id = c.customer_id 
 
    INNER JOIN inventory i 
        ON r.inventory_id = i.inventory_id 
 
    INNER JOIN film f 
        ON i.film_id = f.film_id 
 
    WHERE 
        r.return_date IS NOT NULL 
        AND r.return_date > 
            DATE_ADD( 
                r.rental_date, 
                INTERVAL f.rental_duration DAY 
            ) 
) 
 
SELECT 
    ID, 
    CLIENTE, 
    FILME, 
    LOJA, 
    LOCACAO, 
    PREVISTA, 
    DEVOLUCAO, 
    ATRASO, 
 
    CASE 
        WHEN ATRASO <= 2 THEN 'BAIXA' 
        WHEN ATRASO <= 4 THEN 'MEDIA' 
        ELSE 'ALTA' 
    END AS PRIORIDADE 
 
FROM locacoes;
