-- ============================================================
-- Q3 - Garantia de regra de negócio (TRIGGER com AUDITORIA)
-- Banco: sakila
-- Autor: [preencher com seu nome]
-- ============================================================
--
-- REGRA DE NEGÓCIO
-- Um exemplar (inventory_id) não pode ser locado novamente
-- enquanto a locação anterior desse mesmo exemplar ainda estiver
-- em aberto (rental.return_date IS NULL).
--
-- IMPORTÂNCIA
-- O schema padrão do Sakila não possui nenhuma constraint que
-- impeça a "dupla locação" de um exemplar físico. Sem essa regra,
-- seria possível registrar a locação de uma mídia que já está
-- com outro cliente, gerando inconsistência de estoque e conflito
-- de atendimento. Essa validação garante integridade operacional
-- do processo de locação.
-- ============================================================

USE sakila;

-- ------------------------------------------------------------
-- 1) TABELA DE LOG / AUDITORIA
-- ------------------------------------------------------------
DROP TABLE IF EXISTS log_auditoria_locacao;

CREATE TABLE log_auditoria_locacao (
    id_log              INT AUTO_INCREMENT PRIMARY KEY,
    data_hora           DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario             VARCHAR(100),
    operacao            VARCHAR(50),
    tabela_afetada      VARCHAR(50),
    id_inventory        INT,
    id_customer         INT,
    descricao_problema  VARCHAR(255)
) ENGINE=MyISAM;
-- IMPORTANTE: usamos MyISAM (não transacional) porque o InnoDB desfaz
-- TODAS as escritas feitas dentro da mesma instrução quando ela falha
-- (via SIGNAL). Como o INSERT no log acontece dentro do mesmo INSERT
-- que a trigger está bloqueando, ele seria desfeito junto se a tabela
-- de log também fosse InnoDB. MyISAM não participa dessa transação,
-- então o registro de auditoria sobrevive mesmo com a operação bloqueada.

-- ------------------------------------------------------------
-- 2) TRIGGER: bloqueia locação de exemplar já em aberto
--    e registra a tentativa na tabela de auditoria
-- ------------------------------------------------------------
DELIMITER $$

DROP TRIGGER IF EXISTS trg_bloqueia_locacao_duplicada$$

CREATE TRIGGER trg_bloqueia_locacao_duplicada
BEFORE INSERT ON rental
FOR EACH ROW
BEGIN
    DECLARE v_locacoes_abertas INT;

    -- Verifica se já existe locação em aberto para o mesmo exemplar
    SELECT COUNT(*) INTO v_locacoes_abertas
    FROM rental
    WHERE inventory_id = NEW.inventory_id
      AND return_date IS NULL;

    IF v_locacoes_abertas > 0 THEN

        -- Registra a tentativa de violação antes de bloquear
        INSERT INTO log_auditoria_locacao
            (usuario, operacao, tabela_afetada, id_inventory, id_customer, descricao_problema)
        VALUES
            (CURRENT_USER(), 'INSERT BLOQUEADO', 'rental', NEW.inventory_id, NEW.customer_id,
             CONCAT('Tentativa de locar o exemplar ', NEW.inventory_id,
                    ' que já possui locação em aberto (sem devolução registrada)'));

        -- Bloqueia a operação
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Operação bloqueada: este exemplar já está locado e ainda não foi devolvido.';

    END IF;
END$$

DELIMITER ;

-- ============================================================
-- 3) TESTES / DEMONSTRAÇÃO
-- ============================================================

-- 3.1) Localizar um exemplar que está atualmente em aberto (sem devolução)
SELECT rental_id, inventory_id, customer_id, rental_date
FROM rental
WHERE return_date IS NULL
LIMIT 1;

-- Anote o inventory_id retornado acima e use no teste abaixo.

-- 3.2) TESTE 1 - Tentativa inválida (deve ser BLOQUEADA e registrada no log)
-- Troque <inventory_id_em_aberto> pelo valor obtido em 3.1
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, last_update)
VALUES (NOW(), <inventory_id_em_aberto>, 1, 1, NOW());
-- Resultado esperado: erro 45000 "Operação bloqueada: ..."

-- 3.3) Conferir que a tentativa foi registrada na auditoria
SELECT * FROM log_auditoria_locacao ORDER BY id_log DESC;

-- 3.4) TESTE 2 - Locação válida (exemplar sem locação em aberto -> deve funcionar normalmente)
-- Escolha um inventory_id que NÃO aparece na consulta 3.1
SELECT inventory_id
FROM inventory i
WHERE NOT EXISTS (
    SELECT 1 FROM rental r
    WHERE r.inventory_id = i.inventory_id
      AND r.return_date IS NULL
)
LIMIT 1;

INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, last_update)
VALUES (NOW(), <inventory_id_disponivel>, 1, 1, NOW());
-- Resultado esperado: INSERT bem-sucedido, nenhuma nova linha no log

-- ============================================================
-- 4) DOCUMENTAÇÃO (para incluir no relatório/apresentação)
-- ============================================================
-- Regra monitorada:
--   Impedir a locação de um exemplar (inventory_id) que já possui
--   uma locação em aberto (return_date IS NULL).
--
-- Como funciona:
--   O trigger é do tipo BEFORE INSERT na tabela rental. A cada
--   tentativa de inserção, ele conta quantas locações do mesmo
--   inventory_id ainda não têm devolução registrada. Se houver
--   pelo menos uma, a tentativa é registrada na tabela de log
--   (com usuário, timestamp, operação e descrição do problema)
--   e a inserção é bloqueada via SIGNAL SQLSTATE '45000'.
--
-- Tabela de log (log_auditoria_locacao):
--   id_log             - identificador da auditoria
--   data_hora          - momento da tentativa (timestamp)
--   usuario             - usuário que executou a operação
--   operacao            - tipo de operação (ex.: 'INSERT BLOQUEADO')
--   tabela_afetada      - tabela onde ocorreu a tentativa (rental)
--   id_inventory        - exemplar envolvido na tentativa
--   id_customer         - cliente que tentaria realizar a locação
--   descricao_problema  - detalhamento da violação
