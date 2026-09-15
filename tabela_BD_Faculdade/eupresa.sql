/*TRIGGER:
1- Impedir lançamento de horas para colaborador inativo
2- Impedir mais de 10:48 horas registradas no mesmo dia de tarefa
3- Planejamento de colaborador ativo
4- Impedir lançamento de hora em mês fechado
5- Revalidar limite diário e mês fechado em correções (UPDATE)

VIEWS (consulta):
1- vw_planejado_realizado ....... Planejado x Realizado, por tarefa
2- vw_registro_hora ............. Base detalhada para relatório de horas
3- vw_comparativo_horas ......... Planejado | Trabalhado | Diferença

PROCEDURES (toda procedure provoca mudança no banco):
1- sp_fechar_mes_cliente ........ INSERT em fechamento_mensal + historico_fechamento
2- sp_reabrir_mes_cliente ....... INSERT em historico_fechamento + DELETE em fechamento_mensal
3- sp_corrigir_hora ............. UPDATE em registroHora + INSERT em historico_correcao_hora

REQUISITO: MySQL 5.7.7 ou superior
(5.7.2+ para vários triggers BEFORE INSERT na mesma tabela;
 5.7.7+ para views com subquery na cláusula FROM)
*/

CREATE DATABASE IF NOT EXISTS eupresa;

USE eupresa;

-- ============================================
-- TABELAS PRINCIPAIS
-- ============================================

CREATE TABLE IF NOT EXISTS cliente (
    cnpj VARCHAR(20) PRIMARY KEY,
    nome_cliente VARCHAR(100) NOT NULL,
    num_contrato INT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS setor (
    id_setor INTEGER PRIMARY KEY AUTO_INCREMENT,
    nome_coordenador VARCHAR(100) NOT NULL,
    nome_setor VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS colaborador (
    cpf_colaborador VARCHAR(11) PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
    nome_colaborador VARCHAR(100) NOT NULL,
    ativo CHAR(1) NOT NULL CHECK (ativo IN ('S', 'N')),
    id_setor INT,
    FOREIGN KEY (id_setor) REFERENCES setor(id_setor)
);

CREATE TABLE IF NOT EXISTS tarefa (
    id_tarefa INTEGER PRIMARY KEY AUTO_INCREMENT,
    tipo_tarefa VARCHAR(220) NOT NULL,
    descricao_tarefa VARCHAR(220) NOT NULL,
    cnpj VARCHAR(20) NOT NULL,
    cpf_colaborador VARCHAR(11),
    FOREIGN KEY (cnpj) REFERENCES cliente(cnpj),
    FOREIGN KEY (cpf_colaborador) REFERENCES colaborador(cpf_colaborador)
);

CREATE TABLE IF NOT EXISTS registroHora (
    id_registro INTEGER PRIMARY KEY AUTO_INCREMENT,
    hora_trabalhada TIME NOT NULL,
    data_registro DATE NOT NULL,
    cpf_colaborador VARCHAR(11) NOT NULL,
    id_tarefa INT,
    FOREIGN KEY (cpf_colaborador) REFERENCES colaborador(cpf_colaborador),
    FOREIGN KEY (id_tarefa) REFERENCES tarefa(id_tarefa)
);

CREATE TABLE IF NOT EXISTS planejamento (
    id_planejamento INTEGER PRIMARY KEY AUTO_INCREMENT,
    hora_planejada TIME NOT NULL,
    data_planejada DATE NOT NULL,
    cpf_colaborador VARCHAR(11) NOT NULL,
    id_tarefa INT,
    FOREIGN KEY (cpf_colaborador) REFERENCES colaborador(cpf_colaborador),
    FOREIGN KEY (id_tarefa) REFERENCES tarefa(id_tarefa)
);


-- ============================================
-- TABELAS DE APOIO
-- ============================================

CREATE TABLE IF NOT EXISTS fechamento_mensal (
    id_fechamento INT PRIMARY KEY AUTO_INCREMENT,
    cnpj VARCHAR(20) NOT NULL,
    ano INT NOT NULL,
    mes INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    total_horas TIME NOT NULL,
    data_fechamento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responsavel_fechamento VARCHAR(100) NOT NULL,
    UNIQUE KEY uk_fechamento_periodo (cnpj, ano, mes),
    FOREIGN KEY (cnpj) REFERENCES cliente(cnpj)
);

CREATE TABLE IF NOT EXISTS historico_fechamento (
    id_historico INT PRIMARY KEY AUTO_INCREMENT,
    cnpj VARCHAR(20) NOT NULL,
    ano INT NOT NULL,
    mes INT NOT NULL,
    acao VARCHAR(15) NOT NULL CHECK (acao IN ('FECHAMENTO', 'REABERTURA')),
    responsavel VARCHAR(100) NOT NULL,
    motivo VARCHAR(255),
    total_horas TIME,
    data_acao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cnpj) REFERENCES cliente(cnpj)
);

CREATE TABLE IF NOT EXISTS historico_correcao_hora (
    id_correcao INT PRIMARY KEY AUTO_INCREMENT,
    id_registro INT NOT NULL,
    cpf_colaborador VARCHAR(11) NOT NULL,
    data_registro DATE NOT NULL,
    hora_anterior TIME NOT NULL,
    hora_nova TIME NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    responsavel VARCHAR(100),
    data_correcao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================
-- TRIGGER 1: IMPEDIR HORA DE COLABORADOR INATIVO
-- ============================================
DELIMITER $$
DROP TRIGGER IF EXISTS trg_impedir_hora_colaborador_inativo $$
CREATE TRIGGER trg_impedir_hora_colaborador_inativo
BEFORE INSERT ON registroHora
FOR EACH ROW
BEGIN
    DECLARE v_ativo CHAR(1);
    SELECT ativo INTO v_ativo FROM colaborador WHERE cpf_colaborador = NEW.cpf_colaborador;
    IF v_ativo = 'N' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: colaborador inativo nao pode registrar horas.';
    END IF;
END $$
DELIMITER ;


-- ============================================
-- TRIGGER 2: LIMITE DE 10:48 HORAS DIÁRIAS
-- ============================================
DELIMITER $$
DROP TRIGGER IF EXISTS trg_limite_horas_diarias $$
CREATE TRIGGER trg_limite_horas_diarias
BEFORE INSERT ON registroHora
FOR EACH ROW
BEGIN
    DECLARE v_total_segundos INT DEFAULT 0;
    DECLARE v_novo_registro INT DEFAULT 0;
    DECLARE v_limite_segundos INT DEFAULT 38880; -- 10:48

    SELECT COALESCE(SUM(TIME_TO_SEC(hora_trabalhada)), 0) INTO v_total_segundos
    FROM registroHora
    WHERE cpf_colaborador = NEW.cpf_colaborador AND data_registro = NEW.data_registro;

    SET v_novo_registro = TIME_TO_SEC(NEW.hora_trabalhada);

    IF v_total_segundos + v_novo_registro > v_limite_segundos THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: limite diario de 10:48 horas excedido.';
    END IF;
END $$
DELIMITER ;


-- ============================================
-- TRIGGER 3: IMPEDIR PLANEJAMENTO PARA INATIVO
-- ============================================
DELIMITER $$
DROP TRIGGER IF EXISTS trg_impedir_planejamento_inativo $$
CREATE TRIGGER trg_impedir_planejamento_inativo
BEFORE INSERT ON planejamento
FOR EACH ROW
BEGIN
    DECLARE v_ativo CHAR(1);
    SELECT ativo INTO v_ativo FROM colaborador WHERE cpf_colaborador = NEW.cpf_colaborador;
    IF v_ativo = 'N' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: colaborador inativo nao pode receber planejamento.';
    END IF;
END $$
DELIMITER ;


-- ============================================
-- TRIGGER 4: IMPEDIR HORA EM MÊS FECHADO
-- ============================================
DELIMITER $$
DROP TRIGGER IF EXISTS trg_impedir_hora_mes_fechado $$
CREATE TRIGGER trg_impedir_hora_mes_fechado
BEFORE INSERT ON registroHora
FOR EACH ROW
BEGIN
    DECLARE v_cnpj VARCHAR(20) DEFAULT NULL;
    DECLARE v_fechado INT DEFAULT 0;

    IF NEW.id_tarefa IS NOT NULL THEN
        SELECT cnpj INTO v_cnpj FROM tarefa WHERE id_tarefa = NEW.id_tarefa;

        SELECT COUNT(*) INTO v_fechado
        FROM fechamento_mensal
        WHERE cnpj = v_cnpj
          AND ano = YEAR(NEW.data_registro)
          AND mes = MONTH(NEW.data_registro);

        IF v_fechado > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: mes fechado para este cliente, nao e possivel lancar horas.';
        END IF;
    END IF;
END $$
DELIMITER ;


-- ============================================
-- TRIGGER 5: REVALIDAR REGRAS NO UPDATE
-- Sem ela, qualquer UPDATE em registroHora (inclusive o
-- da sp_corrigir_hora) passa por fora das triggers 2 e 4.
-- ============================================
DELIMITER $$
DROP TRIGGER IF EXISTS trg_validar_correcao_hora $$
CREATE TRIGGER trg_validar_correcao_hora
BEFORE UPDATE ON registroHora
FOR EACH ROW
BEGIN
    DECLARE v_total_segundos INT DEFAULT 0;
    DECLARE v_limite_segundos INT DEFAULT 38880; -- 10:48
    DECLARE v_cnpj VARCHAR(20) DEFAULT NULL;
    DECLARE v_fechado INT DEFAULT 0;

    -- limite diario, desconsiderando a propria linha que esta sendo alterada
    SELECT COALESCE(SUM(TIME_TO_SEC(hora_trabalhada)), 0) INTO v_total_segundos
    FROM registroHora
    WHERE cpf_colaborador = NEW.cpf_colaborador
      AND data_registro = NEW.data_registro
      AND id_registro <> NEW.id_registro;

    IF v_total_segundos + TIME_TO_SEC(NEW.hora_trabalhada) > v_limite_segundos THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: limite diario de 10:48 horas excedido.';
    END IF;

    -- mes fechado
    IF NEW.id_tarefa IS NOT NULL THEN
        SELECT cnpj INTO v_cnpj FROM tarefa WHERE id_tarefa = NEW.id_tarefa;

        SELECT COUNT(*) INTO v_fechado
        FROM fechamento_mensal
        WHERE cnpj = v_cnpj
          AND ano = YEAR(NEW.data_registro)
          AND mes = MONTH(NEW.data_registro);

        IF v_fechado > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: mes fechado para este cliente, reabra o mes antes de corrigir.';
        END IF;
    END IF;
END $$
DELIMITER ;


-- ============================================
-- LIMPEZA: as procedures de consulta viraram views
-- ============================================
DROP PROCEDURE IF EXISTS sp_planejado_realizado;
DROP PROCEDURE IF EXISTS sp_relatorio_horas;
DROP PROCEDURE IF EXISTS sp_comparativo_horas;


-- ============================================
-- VIEW 1: PLANEJADO X REALIZADO
-- Grao: colaborador + data + tarefa.
-- O filtro de periodo fica a cargo de quem consulta.
-- ============================================
CREATE OR REPLACE VIEW vw_planejado_realizado AS
SELECT
    c.cpf_colaborador,
    c.nome_colaborador,
    dados.data_referencia,
    dados.id_tarefa,
    t.tipo_tarefa,
    SEC_TO_TIME(COALESCE(p.planejado_segundos, 0))  AS horas_planejadas,
    SEC_TO_TIME(COALESCE(r.realizado_segundos, 0))  AS horas_trabalhadas
FROM (
    SELECT cpf_colaborador, data_planejada AS data_referencia, id_tarefa
    FROM planejamento
    UNION
    SELECT cpf_colaborador, data_registro AS data_referencia, id_tarefa
    FROM registroHora
) AS dados
INNER JOIN colaborador c ON c.cpf_colaborador = dados.cpf_colaborador
LEFT JOIN tarefa t ON t.id_tarefa = dados.id_tarefa
LEFT JOIN (
    SELECT cpf_colaborador, data_planejada, id_tarefa, SUM(TIME_TO_SEC(hora_planejada)) AS planejado_segundos
    FROM planejamento
    GROUP BY cpf_colaborador, data_planejada, id_tarefa
) AS p ON p.cpf_colaborador = dados.cpf_colaborador
      AND p.data_planejada  = dados.data_referencia
      AND p.id_tarefa      <=> dados.id_tarefa
LEFT JOIN (
    SELECT cpf_colaborador, data_registro, id_tarefa, SUM(TIME_TO_SEC(hora_trabalhada)) AS realizado_segundos
    FROM registroHora
    GROUP BY cpf_colaborador, data_registro, id_tarefa
) AS r ON r.cpf_colaborador = dados.cpf_colaborador
      AND r.data_registro   = dados.data_referencia
      AND r.id_tarefa      <=> dados.id_tarefa;

/* Uso:
SELECT * FROM vw_planejado_realizado
 WHERE data_referencia BETWEEN '2026-07-01' AND '2026-07-31'
 ORDER BY data_referencia, nome_colaborador;
*/


-- ============================================
-- VIEW 2: BASE DETALHADA DE HORAS TRABALHADAS
-- Grao: um registro de hora.
-- O COUNT(DISTINCT id_tarefa) do relatorio original nao pode
-- ser recomposto a partir de totais ja agregados, entao a view
-- entrega o detalhe e a agregacao fica na consulta.
-- ============================================
CREATE OR REPLACE VIEW vw_registro_hora AS
SELECT
    r.id_registro,
    r.data_registro,
    r.hora_trabalhada,
    r.id_tarefa,
    t.tipo_tarefa,
    t.cnpj,
    cl.nome_cliente,
    c.cpf_colaborador,
    c.nome_colaborador,
    c.ativo
FROM registroHora r
INNER JOIN colaborador c ON c.cpf_colaborador = r.cpf_colaborador
LEFT JOIN tarefa  t  ON t.id_tarefa = r.id_tarefa
LEFT JOIN cliente cl ON cl.cnpj = t.cnpj;

/* Uso (reproduz o relatorio de horas original):
SELECT cpf_colaborador,
       nome_colaborador,
       COUNT(DISTINCT id_tarefa) AS quantidade_tarefas,
       COUNT(id_registro)        AS quantidade_registros,
       SEC_TO_TIME(SUM(TIME_TO_SEC(hora_trabalhada))) AS total_horas_trabalhadas
  FROM vw_registro_hora
 WHERE data_registro BETWEEN '2026-07-01' AND '2026-07-31'
 GROUP BY cpf_colaborador, nome_colaborador
 ORDER BY total_horas_trabalhadas DESC;
*/


-- ============================================
-- VIEW 3: PLANEJADO X TRABALHADO X DIFERENÇA
-- Grao: colaborador + data.
-- ============================================
CREATE OR REPLACE VIEW vw_comparativo_horas AS
SELECT
    c.cpf_colaborador,
    c.nome_colaborador,
    dados.data_referencia,
    SEC_TO_TIME(COALESCE(p.total_planejado, 0))  AS horas_planejadas,
    SEC_TO_TIME(COALESCE(r.total_trabalhado, 0)) AS horas_trabalhadas,
    CASE
        WHEN COALESCE(r.total_trabalhado, 0) - COALESCE(p.total_planejado, 0) >= 0
        THEN CONCAT('+', SEC_TO_TIME(COALESCE(r.total_trabalhado, 0) - COALESCE(p.total_planejado, 0)))
        ELSE SEC_TO_TIME(COALESCE(r.total_trabalhado, 0) - COALESCE(p.total_planejado, 0))
    END AS diferenca
FROM (
    SELECT cpf_colaborador, data_planejada AS data_referencia
    FROM planejamento
    GROUP BY cpf_colaborador, data_planejada
    UNION
    SELECT cpf_colaborador, data_registro AS data_referencia
    FROM registroHora
    GROUP BY cpf_colaborador, data_registro
) AS dados
INNER JOIN colaborador c ON c.cpf_colaborador = dados.cpf_colaborador
LEFT JOIN (
    SELECT cpf_colaborador, data_planejada, SUM(TIME_TO_SEC(hora_planejada)) AS total_planejado
    FROM planejamento
    GROUP BY cpf_colaborador, data_planejada
) AS p ON p.cpf_colaborador = dados.cpf_colaborador
      AND p.data_planejada  = dados.data_referencia
LEFT JOIN (
    SELECT cpf_colaborador, data_registro, SUM(TIME_TO_SEC(hora_trabalhada)) AS total_trabalhado
    FROM registroHora
    GROUP BY cpf_colaborador, data_registro
) AS r ON r.cpf_colaborador = dados.cpf_colaborador
      AND r.data_registro   = dados.data_referencia;

/* Uso:
SELECT * FROM vw_comparativo_horas
 WHERE data_referencia BETWEEN '2026-07-01' AND '2026-07-31'
 ORDER BY data_referencia, nome_colaborador;
*/


-- ============================================
-- PROCEDURE 1: FECHAR O MÊS DE UM CLIENTE
-- Grava em: fechamento_mensal, historico_fechamento
-- ============================================
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_fechar_mes_cliente $$
CREATE PROCEDURE sp_fechar_mes_cliente(
    IN p_cnpj VARCHAR(20),
    IN p_ano INT,
    IN p_mes INT,
    IN p_responsavel VARCHAR(100)
)
BEGIN
    DECLARE v_ja_fechado INT DEFAULT 0;
    DECLARE v_total_segundos INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_mes < 1 OR p_mes > 12 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: mes invalido (informe de 1 a 12).';
    END IF;

    IF p_responsavel IS NULL OR TRIM(p_responsavel) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: e obrigatorio informar o responsavel pelo fechamento.';
    END IF;

    -- recusa fechar duas vezes o mesmo mes
    SELECT COUNT(*) INTO v_ja_fechado
    FROM fechamento_mensal
    WHERE cnpj = p_cnpj AND ano = p_ano AND mes = p_mes;

    IF v_ja_fechado > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: este mes ja foi fechado para este cliente.';
    END IF;

    -- soma tudo que foi trabalhado naquele mes para aquele cliente
    SELECT COALESCE(SUM(TIME_TO_SEC(r.hora_trabalhada)), 0) INTO v_total_segundos
    FROM registroHora r
    INNER JOIN tarefa t ON t.id_tarefa = r.id_tarefa
    WHERE t.cnpj = p_cnpj
      AND YEAR(r.data_registro) = p_ano
      AND MONTH(r.data_registro) = p_mes;

    -- recusa fechar um mes vazio
    IF v_total_segundos = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: nao ha horas lancadas neste mes, fechamento nao permitido.';
    END IF;

    START TRANSACTION;

        INSERT INTO fechamento_mensal (cnpj, ano, mes, total_horas, responsavel_fechamento)
        VALUES (p_cnpj, p_ano, p_mes, SEC_TO_TIME(v_total_segundos), p_responsavel);

        INSERT INTO historico_fechamento (cnpj, ano, mes, acao, responsavel, motivo, total_horas)
        VALUES (p_cnpj, p_ano, p_mes, 'FECHAMENTO', p_responsavel, NULL, SEC_TO_TIME(v_total_segundos));

    COMMIT;

    SELECT CONCAT('Mes ', p_mes, '/', p_ano, ' fechado para o cliente ', p_cnpj,
                  ' - total: ', SEC_TO_TIME(v_total_segundos)) AS resultado;
END $$
DELIMITER ;


-- ============================================
-- PROCEDURE 2: REABRIR UM MÊS FECHADO
-- Grava em: historico_fechamento; apaga de fechamento_mensal
-- ============================================
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_reabrir_mes_cliente $$
CREATE PROCEDURE sp_reabrir_mes_cliente(
    IN p_cnpj VARCHAR(20),
    IN p_ano INT,
    IN p_mes INT,
    IN p_responsavel VARCHAR(100),
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_total_horas TIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- exige justificativa
    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: e obrigatorio informar o motivo da reabertura.';
    END IF;

    IF p_responsavel IS NULL OR TRIM(p_responsavel) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: e obrigatorio informar o responsavel pela reabertura.';
    END IF;

    SELECT COUNT(*), MAX(total_horas) INTO v_existe, v_total_horas
    FROM fechamento_mensal
    WHERE cnpj = p_cnpj AND ano = p_ano AND mes = p_mes;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: este mes nao esta fechado, nao ha o que reabrir.';
    END IF;

    START TRANSACTION;

        -- registra no historico ANTES de apagar o fechamento
        INSERT INTO historico_fechamento (cnpj, ano, mes, acao, responsavel, motivo, total_horas)
        VALUES (p_cnpj, p_ano, p_mes, 'REABERTURA', p_responsavel, p_motivo, v_total_horas);

        DELETE FROM fechamento_mensal
        WHERE cnpj = p_cnpj AND ano = p_ano AND mes = p_mes;

    COMMIT;

    SELECT CONCAT('Mes ', p_mes, '/', p_ano, ' reaberto para o cliente ', p_cnpj) AS resultado;
END $$
DELIMITER ;


-- ============================================
-- PROCEDURE 3: CORRIGIR UMA HORA JÁ LANÇADA
-- Grava em: registroHora (UPDATE), historico_correcao_hora
-- O limite de 10:48 e o bloqueio de mes fechado sao
-- garantidos pela Trigger 5.
-- ============================================
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_corrigir_hora $$
CREATE PROCEDURE sp_corrigir_hora(
    IN p_id_registro INT,
    IN p_nova_hora TIME,
    IN p_motivo VARCHAR(255),
    IN p_responsavel VARCHAR(100)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_hora_atual TIME;
    DECLARE v_cpf VARCHAR(11);
    DECLARE v_data DATE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- confere se o lancamento existe mesmo
    SELECT COUNT(*) INTO v_existe FROM registroHora WHERE id_registro = p_id_registro;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: registro de hora nao encontrado.';
    END IF;

    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: e obrigatorio informar o motivo da correcao.';
    END IF;

    -- confere se o novo valor faz sentido (nada de 0 hora nem 30 horas num dia)
    IF p_nova_hora <= '00:00:00' OR p_nova_hora >= '24:00:00' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: hora corrigida invalida (deve ser maior que 0 e menor que 24:00:00).';
    END IF;

    SELECT hora_trabalhada, cpf_colaborador, data_registro
    INTO v_hora_atual, v_cpf, v_data
    FROM registroHora
    WHERE id_registro = p_id_registro;

    START TRANSACTION;

        UPDATE registroHora
        SET hora_trabalhada = p_nova_hora
        WHERE id_registro = p_id_registro;

        INSERT INTO historico_correcao_hora
            (id_registro, cpf_colaborador, data_registro, hora_anterior, hora_nova, motivo, responsavel)
        VALUES
            (p_id_registro, v_cpf, v_data, v_hora_atual, p_nova_hora, p_motivo, p_responsavel);

    COMMIT;

    SELECT CONCAT('Registro ', p_id_registro, ' corrigido de ', v_hora_atual, ' para ', p_nova_hora) AS resultado;
END $$
DELIMITER ;
