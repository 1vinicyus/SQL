USE insight_places;

#verificando se as tabelas já existem
#DROP TABLE IF EXISTS avaliacoes;
#DROP TABLE IF EXISTS alugueis;
#DROP TABLE IF EXISTS hospedagens;
#DROP TABLE IF EXISTS clientes;
#DROP TABLE IF EXISTS proprietarios;
#DROP TABLE IF EXISTS enderecos;

CREATE TABLE IF NOT EXISTS proprietarios (
	proprietario_id VARCHAR(255) PRIMARY KEY,
	nome VARCHAR(255),
	cpf_cnpj VARCHAR(20),
	contato VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS clientes (
    cliente_id VARCHAR(255) PRIMARY KEY,
    nome VARCHAR(255),
    cpf VARCHAR(14),
    contato VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS enderecos (
    endereco_id VARCHAR(255) PRIMARY KEY,
    rua VARCHAR(255),
    numero INT,
    bairro VARCHAR(255),
    cidade VARCHAR(255),
    estado VARCHAR(2),
    cep VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS hospedagens (
    hospedagem_id VARCHAR(255) PRIMARY KEY,
    tipo VARCHAR(50),
    endereco_id VARCHAR(255),
    proprietario_id VARCHAR(255),
        ativo bool,
    FOREIGN KEY (endereco_id) REFERENCES enderecos(endereco_id),
    FOREIGN KEY (proprietario_id) REFERENCES proprietarios(proprietario_id)
);

CREATE TABLE IF NOT EXISTS alugueis (
    aluguel_id VARCHAR(255) PRIMARY KEY,
    cliente_id VARCHAR(255),
    hospedagem_id VARCHAR(255),
    data_inicio DATE,
    data_fim DATE,
    preco_total DECIMAL(10, 2),
    FOREIGN KEY (cliente_id) REFERENCES clientes(cliente_id),
    FOREIGN KEY (hospedagem_id) REFERENCES hospedagens(hospedagem_id)
);

CREATE TABLE IF NOT EXISTS avaliacoes (
	avaliacao_id VARCHAR(255) PRIMARY KEY,
	cliente_id VARCHAR(255),
	hospedagem_id VARCHAR(255),
	nota INT,
	comentario TEXT,
	FOREIGN KEY (cliente_id) REFERENCES clientes(cliente_id),
	FOREIGN KEY (hospedagem_id) REFERENCES hospedagens(hospedagem_id)
);