/*TRIGGER:
1- Impedir lançamento de horas para colaborador inativo
2- Impedir mais de 10:48 horas registradas no mesmo dia de tarefa
3- Planejamento de colaborador ativo
4- Impedir lançamento de hora em mês fechado
5- Revalidar limite diário e mês fechado em correções (UPDATE)

VIEWS (cada uma atende uma procedure):
1- vw_horas_cliente_mes ......... consumida por sp_fechar_mes_cliente
2- vw_meses_fechados ............ consumida por sp_reabrir_mes_cliente
3- vw_registro_hora_detalhe ..... consumida por sp_corrigir_hora

PROCEDURES (toda procedure provoca mudança no banco):
1- sp_fechar_mes_cliente ........ INSERT em fechamento_mensal + historico_fechamento
2- sp_reabrir_mes_cliente ....... INSERT em historico_fechamento + DELETE em fechamento_mensal
3- sp_corrigir_hora ............. UPDATE em registroHora + INSERT em historico_correcao_hora

REQUISITO: MySQL 5.7.2+ / MariaDB 10.2.4+
(vários triggers BEFORE INSERT na mesma tabela)
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
-- VIEW 1: HORAS POR CLIENTE E MÊS
-- Consumida por sp_fechar_mes_cliente.
-- Isola a travessia registroHora -> tarefa -> cliente e a
-- consolidacao mensal, que a procedure apenas le.
-- ============================================
CREATE OR REPLACE VIEW vw_horas_cliente_mes AS
SELECT
    t.cnpj,
    cl.nome_cliente,
    YEAR(r.data_registro)  AS ano,
    MONTH(r.data_registro) AS mes,
    COUNT(r.id_registro)   AS qtd_registros,
    SUM(TIME_TO_SEC(r.hora_trabalhada)) AS total_segundos
FROM registroHora r
INNER JOIN tarefa  t  ON t.id_tarefa = r.id_tarefa
INNER JOIN cliente cl ON cl.cnpj = t.cnpj
GROUP BY t.cnpj, cl.nome_cliente, YEAR(r.data_registro), MONTH(r.data_registro);

/* Consulta avulsa:
SELECT cnpj, nome_cliente, ano, mes, qtd_registros,
       SEC_TO_TIME(total_segundos) AS total_horas
  FROM vw_horas_cliente_mes
 WHERE ano = 2026
 ORDER BY nome_cliente, mes;
*/


-- ============================================
-- VIEW 2: MESES FECHADOS
-- Consumida por sp_reabrir_mes_cliente.
-- Mostra os periodos encerrados ja com o nome do cliente.
-- ============================================
CREATE OR REPLACE VIEW vw_meses_fechados AS
SELECT
    f.id_fechamento,
    f.cnpj,
    cl.nome_cliente,
    f.ano,
    f.mes,
    f.total_horas,
    f.data_fechamento,
    f.responsavel_fechamento
FROM fechamento_mensal f
INNER JOIN cliente cl ON cl.cnpj = f.cnpj;

/* Consulta avulsa:
SELECT * FROM vw_meses_fechados ORDER BY ano DESC, mes DESC;
*/


-- ============================================
-- VIEW 3: REGISTRO DE HORA DETALHADO
-- Consumida por sp_corrigir_hora.
-- Junta o lancamento ao colaborador, a tarefa e ao cliente,
-- e indica se o mes daquele registro esta aberto ou fechado.
-- ============================================
CREATE OR REPLACE VIEW vw_registro_hora_detalhe AS
SELECT
    r.id_registro,
    r.data_registro,
    r.hora_trabalhada,
    r.cpf_colaborador,
    c.nome_colaborador,
    r.id_tarefa,
    t.tipo_tarefa,
    t.cnpj,
    cl.nome_cliente,
    CASE WHEN f.id_fechamento IS NULL THEN 'ABERTO' ELSE 'FECHADO' END AS situacao_mes
FROM registroHora r
INNER JOIN colaborador c ON c.cpf_colaborador = r.cpf_colaborador
LEFT JOIN tarefa  t  ON t.id_tarefa = r.id_tarefa
LEFT JOIN cliente cl ON cl.cnpj = t.cnpj
LEFT JOIN fechamento_mensal f
       ON f.cnpj = t.cnpj
      AND f.ano  = YEAR(r.data_registro)
      AND f.mes  = MONTH(r.data_registro);

/* Consulta avulsa:
SELECT * FROM vw_registro_hora_detalhe
 WHERE situacao_mes = 'FECHADO'
 ORDER BY data_registro;
*/


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
-- Sem ela, qualquer UPDATE em registroHora passa por fora
-- das triggers 2 e 4.
-- Le as tabelas direto, e nao a vw_registro_hora_detalhe:
-- a view se apoia em registroHora, que e a propria tabela
-- da trigger.
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
-- PROCEDURE 1: FECHAR O MÊS DE UM CLIENTE
-- Le: vw_meses_fechados, vw_horas_cliente_mes
-- Grava: fechamento_mensal, historico_fechamento
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

    -- recusa fechar duas vezes o mesmo mes  (VIEW 2)
    SELECT COUNT(*) INTO v_ja_fechado
    FROM vw_meses_fechados
    WHERE cnpj = p_cnpj AND ano = p_ano AND mes = p_mes;

    IF v_ja_fechado > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: este mes ja foi fechado para este cliente.';
    END IF;

    -- total trabalhado no periodo, ja consolidado pela view  (VIEW 1)
    SELECT COALESCE(MAX(total_segundos), 0) INTO v_total_segundos
    FROM vw_horas_cliente_mes
    WHERE cnpj = p_cnpj AND ano = p_ano AND mes = p_mes;

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
-- Le: vw_meses_fechados
-- Grava: historico_fechamento; apaga de fechamento_mensal
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

    -- situacao atual do periodo  (VIEW 2)
    SELECT COUNT(*), MAX(total_horas) INTO v_existe, v_total_horas
    FROM vw_meses_fechados
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
-- Le: vw_registro_hora_detalhe
-- Grava: registroHora (UPDATE), historico_correcao_hora
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
    DECLARE v_situacao VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- confere se o lancamento existe mesmo  (VIEW 3)
    SELECT COUNT(*) INTO v_existe
    FROM vw_registro_hora_detalhe
    WHERE id_registro = p_id_registro;

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

    -- dados do registro e situacao do mes  (VIEW 3)
    SELECT hora_trabalhada, cpf_colaborador, data_registro, situacao_mes
    INTO v_hora_atual, v_cpf, v_data, v_situacao
    FROM vw_registro_hora_detalhe
    WHERE id_registro = p_id_registro;

    IF v_situacao = 'FECHADO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERRO: mes fechado, reabra o periodo antes de corrigir esta hora.';
    END IF;

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
