USE eupresa;

-- ============================================
-- INSERTS - CLIENTE
-- ============================================

INSERT INTO cliente (cnpj, nome_cliente, num_contrato) VALUES
('11222333000181', 'Alfa Comercio de Alimentos Ltda', 1001),
('22333444000192', 'Beta Solucoes em TI Ltda', 1002),
('33444555000103', 'Gamma Construtora S.A.', 1003),
('44555666000114', 'Delta Transportes e Logistica Ltda', 1004),
('55666777000125', 'Epsilon Consultoria Financeira Ltda', 1005),
('66777888000136', 'Zeta Industria Textil S.A.', 1006),
('77888999000147', 'Eta Marketing Digital Ltda', 1007),
('88999000000158', 'Theta Farmaceutica Ltda', 1008),
('99000111000169', 'Iota Servicos de Limpeza Ltda', 1009),
('10111222000170', 'Kappa Educacao e Cursos Ltda', 1010),
('12131415000181', 'Lambda Agropecuaria Ltda', 1011);


-- ============================================
-- INSERTS - SETOR
-- ============================================

INSERT INTO setor (nome_coordenador, nome_setor) VALUES
('Carla Menezes', 'Recursos Humanos'),
('Bruno Almeida', 'Financeiro'),
('Fernanda Ramos', 'Tecnologia da Informacao'),
('Diego Fontoura', 'Comercial'),
('Patricia Souza', 'Marketing'),
('Rafael Nogueira', 'Operacoes'),
('Juliana Prado', 'Juridico'),
('Marcos Vinicius', 'Logistica'),
('Aline Ferreira', 'Atendimento ao Cliente'),
('Thiago Barros', 'Qualidade');


-- ============================================
-- INSERTS - COLABORADOR
-- ============================================

INSERT INTO colaborador 
(cpf_colaborador, email, nome_colaborador, ativo, id_setor) 
VALUES
('52998224725', 'ana.silva@eupresa.com', 'Ana Silva', 'S', 3),
('15350946056', 'pedro.santos@eupresa.com', 'Pedro Santos', 'S', 4),
('74839201630', 'mariana.costa@eupresa.com', 'Mariana Costa', 'S', 1),
('30188319075', 'lucas.oliveira@eupresa.com', 'Lucas Oliveira', 'S', 2),
('48539641050', 'beatriz.lima@eupresa.com', 'Beatriz Lima', 'N', 5),
('91234567800', 'gustavo.pereira@eupresa.com', 'Gustavo Pereira', 'S', 6),
('60321478955', 'camila.rocha@eupresa.com', 'Camila Rocha', 'S', 3),
('78912345600', 'rodrigo.melo@eupresa.com', 'Rodrigo Melo', 'S', 7),
('23456789011', 'larissa.dias@eupresa.com', 'Larissa Dias', 'S', 8),
('34567891022', 'felipe.araujo@eupresa.com', 'Felipe Araujo', 'N', 9),
('45678912033', 'vanessa.teixeira@eupresa.com', 'Vanessa Teixeira', 'S', 10);


-- ============================================
-- INSERTS - TAREFA
-- ============================================

INSERT INTO tarefa 
(tipo_tarefa, descricao_tarefa, cnpj, cpf_colaborador) 
VALUES
('Suporte', 'Atendimento a chamado de rede', 
 '11222333000181', '52998224725'),

('Desenvolvimento', 'Criacao de modulo de relatorios', 
 '22333444000192', '15350946056'),

('Consultoria', 'Analise de processos internos', 
 '33444555000103', '74839201630'),

('Manutencao', 'Revisao de frota de veiculos', 
 '44555666000114', '30188319075'),

('Auditoria', 'Auditoria de contas a pagar', 
 '55666777000125', '48539641050'),

('Producao', 'Ajuste de linha de producao', 
 '66777888000136', '91234567800'),

('Campanha', 'Planejamento de campanha digital', 
 '77888999000147', '60321478955'),

('Registro', 'Cadastro de novo produto', 
 '88999000000158', '78912345600'),

('Limpeza', 'Contrato de limpeza predial', 
 '99000111000169', '23456789011'),

('Treinamento', 'Elaboracao de curso interno', 
 '10111222000170', '34567891022'),

('Consultoria', 'Diagnostico de gestao agropecuaria', 
 '12131415000181', '45678912033');


-- ============================================
-- INSERTS - REGISTRO DE HORAS
-- ============================================

INSERT INTO registroHora 
(hora_trabalhada, data_registro, cpf_colaborador, id_tarefa) 
VALUES
('08:30:00', '2026-07-01', '52998224725', 1),
('07:45:00', '2026-07-01', '15350946056', 2),
('09:00:00', '2026-07-02', '74839201630', 3),
('06:30:00', '2026-07-02', '30188319075', 4),
('08:00:00', '2026-07-03', '48539641050', 5),
('07:15:00', '2026-07-03', '91234567800', 6),
('08:45:00', '2026-07-04', '60321478955', 7),
('09:30:00', '2026-07-04', '78912345600', 8),
('07:00:00', '2026-07-05', '23456789011', 9),
('08:15:00', '2026-07-05', '34567891022', 10),
('06:50:00', '2026-07-06', '45678912033', 11);


-- ============================================
-- INSERTS - PLANEJAMENTO
-- ============================================

INSERT INTO planejamento 
(hora_planejada, data_planejada, cpf_colaborador, id_tarefa) 
VALUES
('08:00:00', '2026-07-08', '52998224725', 1),
('08:00:00', '2026-07-08', '15350946056', 2),
('08:00:00', '2026-07-09', '74839201630', 3),
('07:00:00', '2026-07-09', '30188319075', 4),
('08:00:00', '2026-07-10', '48539641050', 5),
('07:00:00', '2026-07-10', '91234567800', 6),
('08:00:00', '2026-07-11', '60321478955', 7),
('09:00:00', '2026-07-11', '78912345600', 8),
('07:00:00', '2026-07-12', '23456789011', 9),
('08:00:00', '2026-07-12', '34567891022', 10),
('07:00:00', '2026-07-13', '45678912033', 11);


-- ============================================
-- FIM DOS INSERTS
-- ============================================