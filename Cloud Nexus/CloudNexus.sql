USE CloudNexus_DB;
GO

-- 1. Limpa a tabela
TRUNCATE TABLE Fato_Tickets;
GO

-- 2. Tabela temporária para garantir o sorteio INDIVIDUAL (1 a 15)
IF OBJECT_ID('tempdb..#SorteioDefinitivo') IS NOT NULL DROP TABLE #SorteioDefinitivo;
CREATE TABLE #SorteioDefinitivo (ID_Cliente INT, Qtd INT);

INSERT INTO #SorteioDefinitivo (ID_Cliente, Qtd)
SELECT ID_Cliente, (ABS(CHECKSUM(NEWID())) % 15) + 1 FROM Dim_Clientes;

-- 3. Inserção com CASE (Mais seguro que CHOOSE)
WITH Lista(n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM Lista WHERE n < 15
)
INSERT INTO Fato_Tickets (ID_Cliente, Data_Abertura, Prioridade, Resolvido, Nota_Satisfacao)
SELECT 
    S.ID_Cliente,
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 60), GETDATE()),
    -- Usando CASE para garantir que sempre tenha um valor
    CASE (ABS(CHECKSUM(NEWID())) % 3)
        WHEN 0 THEN 'Baixa'
        WHEN 1 THEN 'Média'
        ELSE 'Alta'
    END,
    0, 
    (ABS(CHECKSUM(NEWID())) % 6) + 5
FROM #SorteioDefinitivo S
JOIN Lista L ON L.n <= S.Qtd
WHERE S.ID_Cliente % 2 = 0;
GO

-- 4. TRAVA DE SEGURANÇA: Se sobrou algum nulo por milagre, a gente preenche agora
UPDATE Fato_Tickets SET Prioridade = 'Baixa' WHERE Prioridade IS NULL;
GO

-- 5. Meta de 85% de Resolução (Cravada)
WITH CTE_Resolucao AS (
    SELECT TOP (85) PERCENT Resolvido FROM Fato_Tickets ORDER BY NEWID()
)
UPDATE CTE_Resolucao SET Resolvido = 1;
GO

-- PROVA REAL: Tudo preenchido e contagem variada?
SELECT 
    COUNT(*) as Total_Tickets,
    COUNT(Prioridade) as Prioridades_Preenchidas,
    MIN(Total_Por_Cliente) as Min_Tickets,
    MAX(Total_Por_Cliente) as Max_Tickets
FROM (
    SELECT ID_Cliente, Prioridade, COUNT(*) OVER(PARTITION BY ID_Cliente) as Total_Por_Cliente
    FROM Fato_Tickets
) AS CheckData;