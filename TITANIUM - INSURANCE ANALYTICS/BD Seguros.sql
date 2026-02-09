/*
PROJETO TITANIUM - INSURANCE ANALYTICS
Data Warehouse Creation Script
Autor: Gabriel [Seu Sobrenome]
Data: 09/02/2026
Descrição: Criação de banco de dados para seguradora fictícia com injeção de dados sintéticos,
           lógica de sinistralidade controlada e simulação de fraudes em veículos de luxo.
*/

USE master;
GO

-- 1. LIMPEZA E CRIAÇÃO DO BANCO (Idempotência)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'TITANIUM_DB')
BEGIN
    ALTER DATABASE TITANIUM_DB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TITANIUM_DB;
END
GO

CREATE DATABASE TITANIUM_DB;
GO
USE TITANIUM_DB;
GO

-- 2. MODELAGEM DIMENSIONAL (STAR SCHEMA)
CREATE TABLE Dim_Clientes (
    ID_Cliente INT PRIMARY KEY,
    Nome VARCHAR(100),
    Idade INT,
    Genero CHAR(1),
    Estado CHAR(2)
);

CREATE TABLE Dim_Veiculos (
    ID_Veiculo INT PRIMARY KEY,
    Marca VARCHAR(50),
    Modelo VARCHAR(50),
    Categoria VARCHAR(30),
    Valor_Fipe DECIMAL(18,2)
);

CREATE TABLE Dim_Corretores (
    ID_Corretor INT PRIMARY KEY,
    Nome VARCHAR(100),
    Regional VARCHAR(50)
);

CREATE TABLE Dim_Oficinas (
    ID_Oficina INT PRIMARY KEY,
    Nome VARCHAR(100),
    Especialidade VARCHAR(50)
);

CREATE TABLE Dim_Calendario (
    Data DATE PRIMARY KEY,
    Ano INT,
    Mes INT,
    Nome_Mes VARCHAR(20)
);

CREATE TABLE Fato_Vendas (
    ID_Apolice INT PRIMARY KEY,
    ID_Cliente INT REFERENCES Dim_Clientes(ID_Cliente),
    ID_Veiculo INT REFERENCES Dim_Veiculos(ID_Veiculo),
    ID_Corretor INT REFERENCES Dim_Corretores(ID_Corretor),
    Data_Vigencia DATE,
    Valor_Premio DECIMAL(18,2)
);

CREATE TABLE Fato_Sinistros (
    ID_Sinistro INT PRIMARY KEY,
    ID_Apolice INT REFERENCES Fato_Vendas(ID_Apolice),
    ID_Oficina INT REFERENCES Dim_Oficinas(ID_Oficina),
    Data_Sinistro DATE,
    Valor_Sinistro DECIMAL(18,2),
    Tipo_Sinistro VARCHAR(30),
    Fraude_Confirmada INT -- Flag de Risco (0 ou 1)
);
GO

-- 3. POPULANDO DIMENSÕES (DADOS MESTRES)
INSERT INTO Dim_Corretores VALUES (1,'Alfa Seguros','Sudeste'),(2,'Beta Brokers','Sul'),(3,'SafeLife','Nordeste'),(4,'Digital Insure','Nacional'),(5,'Premium Private','Sudeste');
INSERT INTO Dim_Oficinas VALUES (1,'AutoCenter Geral','Mecânica'),(2,'Mecânica Especializada','Motor'),(3,'Prime Repair Luxo','Funilaria'),(4,'Glass & Vidros','Vidros'),(5,'Funilaria Express','Funilaria');

-- Mix de Veículos (Populares e Luxo para análise de portfólio)
INSERT INTO Dim_Veiculos VALUES 
(1,'Toyota','Corolla','Sedan',140000),(2,'Toyota','Hilux','SUV',280000),(3,'BMW','320i','Luxo',320000),(4,'BMW','X5','Luxo',650000),
(5,'VW','Gol','Popular',55000),(6,'VW','T-Cross','SUV',140000),(7,'Fiat','Toro','SUV',160000),(8,'Fiat','Mobi','Popular',50000),
(9,'Honda','Civic','Sedan',150000),(10,'Honda','HR-V','SUV',160000),(11,'Mercedes','C180','Luxo',300000),(12,'Jeep','Compass','SUV',180000);

-- Calendário Completo (2024 a 2026)
DECLARE @d DATE = '2024-01-01'; 
WHILE @d <= '2026-12-31' BEGIN 
    INSERT INTO Dim_Calendario VALUES (@d, YEAR(@d), MONTH(@d), DATENAME(MONTH, @d)); 
    SET @d = DATEADD(DAY, 1, @d); 
END;

-- 1.000 Clientes Aleatórios
DECLARE @c INT = 1; 
WHILE @c <= 1000 BEGIN 
    INSERT INTO Dim_Clientes VALUES (@c, 'Cliente '+CAST(@c AS VARCHAR), 18+(ABS(CHECKSUM(NEWID()))%60), CASE WHEN @c%2=0 THEN 'M' ELSE 'F' END, 'SP'); 
    SET @c = @c + 1; 
END;
GO

-- 4. CARGA DE FATOS (LÓGICA DE NEGÓCIOS & INJEÇÃO DE FRAUDE)
SET NOCOUNT ON;
DECLARE @i INT = 1;
WHILE @i <= 8000
BEGIN
    DECLARE @ID_V INT = (ABS(CHECKSUM(NEWID())) % 12) + 1;
    DECLARE @Fipe DECIMAL(18,2) = (SELECT Valor_Fipe FROM Dim_Veiculos WHERE ID_Veiculo = @ID_V);
    DECLARE @DtVenda DATE = DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 730, '2024-01-01');

    -- VENDA: Prêmio de 12% do carro (Garante Receita Alta)
    INSERT INTO Fato_Vendas VALUES (@i, (ABS(CHECKSUM(NEWID())) % 1000) + 1, @ID_V, (ABS(CHECKSUM(NEWID())) % 5) + 1, @DtVenda, @Fipe * 0.12);

    -- SINISTRO: Ocorre apenas em 25% dos casos (1 a cada 4 apólices)
    IF @i % 4 = 0 
    BEGIN
        -- Lógica de Fraude: 1 a cada 100 apólices (Taxa ~4% sobre os sinistros)
        -- Objetivo: Criar massa de dados para análise de risco
        DECLARE @EhFraude INT = 0;
        IF @i % 100 = 0 SET @EhFraude = 1; 

        -- CUSTO: 30% da Fipe. Como só 25% batem, o custo global cai para 7.5% da base.
        INSERT INTO Fato_Sinistros VALUES (
            @i + 10000, @i, (ABS(CHECKSUM(NEWID())) % 5) + 1, DATEADD(DAY, 30, @DtVenda), 
            @Fipe * 0.30, 'Colisão', @EhFraude
        );
    END
    SET @i = @i + 1;
END;
GO

-- 5. RELATÓRIO DE VALIDAÇÃO (Prova Real)
PRINT '--- VALIDAÇÃO TITANIUM DB ---';
SELECT 
    FORMAT(SUM(v.Valor_Premio), 'C', 'pt-BR') as [Total Receita],
    FORMAT(SUM(s.Valor_Sinistro), 'C', 'pt-BR') as [Total Custo],
    FORMAT(SUM(s.Valor_Sinistro) / SUM(v.Valor_Premio), 'P') as [Sinistralidade (Meta < 70%)],
    SUM(s.Fraude_Confirmada) as [Qtd Fraudes Injetadas]
FROM Fato_Vendas v
LEFT JOIN Fato_Sinistros s ON v.ID_Apolice = s.ID_Apolice;