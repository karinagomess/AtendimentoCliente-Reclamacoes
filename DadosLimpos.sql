-- 1. Criar banco
CREATE DATABASE AtendimentoClientes; --Criar o banco de dados


-- 2. Criar tabela (Criando a tabela antes de importar o arquivo .csv)

CREATE TABLE Reclamacoes(
	Ano VARCHAR(50), 
	DataArquivamento VARCHAR(50),
	DataAbertura VARCHAR(50),
	CodigoRegiao INT,
	Região VARCHAR(100),
	UF VARCHAR(50),
	RazaoSocial VARCHAR(255),
	NomeFantasia VARCHAR(255),
	Tipo VARCHAR(50),
	CNPJ VARCHAR(100),
	RadicalCNPJ VARCHAR(255),
	RazaoSocialRFB VARCHAR(255),
	NomeFantasiaRFB VARCHAR(255),
	CNAEPrincipal VARCHAR(255),
	DescCNAEPrincipal VARCHAR(255),
	Atendida VARCHAR(255),
	CodigoAssunto VARCHAR(255),
	DescricaoAssunto VARCHAR(255),
	CodigoProblema VARCHAR(255),
	DescricaoProblema VARCHAR(255),
	SexoConsumidor VARCHAR(255),
	FaixaEtariaConsumidor VARCHAR(255),
	CEPConsumidor VARCHAR(255)
)


-- 3. Importar dados da tabela
BULK INSERT Reclamacoes
FROM 'C:\Users\karin\Documents\Projetos\Projeto - Sistema de Atendimento ao Cliente\2022DadosAbertosBruto.csv'
WITH(
	FIELDTERMINATOR = ';', -- Define o delimitador de campo (no caso, ponto e vírgula)
	ROWTERMINATOR = '\n', -- Define o delimitador de linha (geralmente \n)
	FIRSTROW = 3, -- Se o arquivo CSV tiver cabeçalhos, defina FIRSTROW=2 (Aqui está 3 pois quis excluir a primeira coluna)
	CODEPAGE = '65001'    -- Especifica a codificação UTF-8
);


SELECT * FROM Reclamacoes; -- Verificar se toda tabela foi importada corretamente



-- 4. Limpeza de dados

--Alterar nome de alguma coluna
EXEC sp_rename 'Reclamacoes.DescCNAEPrincipal', 'Descrição CNAEPrincipal', 'COLUMN';

-- Colocar todas as datas em um padrão antes de transformar o tipo em DATETIME
UPDATE Reclamacoes
SET DataAbertura = '1900-01-01 00:00:00'
WHERE DataAbertura IS NULL;

-- Antes de continuar, é bom configurar seu ambiente para aceitar datas no formato YMD. Execute: set dateformat ymd

-- Alterações nas datas
ALTER TABLE Reclamacoes
ALTER COLUMN DataAbertura DATETIME2(0);

UPDATE Reclamacoes
SET DataAbertura = CAST(DataAbertura AS DATETIME2(0));-- Tirar os milissegundos das datas



-- Alterações do tipo das colunas
ALTER TABLE Reclamacoes
ALTER COLUMN CodigoProblema INT;


-- Deletar colunas desnecessàrias
ALTER TABLE Reclamacoes
DROP COLUMN Tipo; -- Tipo era o nome de uma coluna que foi deletada


-- Substituir Valores da Coluna Atendida e SexoConsumidor
UPDATE Reclamacoes
SET Atendida = CASE
	WHEN Atendida = 'S' THEN 'Sim'
    WHEN Atendida = 'N' THEN 'Não'
    ELSE Atendida
END;


-- Alterar valores null das colunas NomeFantasia, CNAEPrincipal, [Descrição CNAEPrincipal], CodigoProblema
UPDATE Reclamacoes
SET CodigoProblema = 'Não Informado'
WHERE CodigoProblema  = 'NULL';


-- Limpando dados errados nas colunas CodigoProblema, Atendida, FaixaEtariaConsumidor...

SELECT DISTINCT CodigoProblema -- Verificando todos os dados distintos das colunas
FROM Reclamacoes
WHERE CodigoProblema IS NOT NULL;

UPDATE Reclamacoes
SET CodigoProblema = '0' -- colocar '0' nas informacções de texto que tiver  
WHERE CodigoProblema IN ('Aparelho Corretivo ( Ortopédico / Auditivo / Prótese / Acessório )' )

UPDATE Reclamacoes
SET Atendida = 'Não Informada' -- colocar 'não informada' se não for 'sim' ou 'não'
WHERE Atendida NOT IN ('Sim', 'Não' );

UPDATE Reclamacoes
SET FaixaEtariaConsumidor = 'Não Informada' -- colocar 'não informada' se não estiver nas categorias abaixo
WHERE FaixaEtariaConsumidor NOT IN ('até 20 anos', 'entre 21 a 30 anos', 'entre 31 a 40 anos', 'entre 41 a 50 anos',
'entre 51 a 60 anos', 'entre 61 a 70 anos', 'mais de 70 anos');



-- Tirando caracteres especiais das colunas 
UPDATE Reclamacoes
SET NomeFantasia = 'Não Informado'
WHERE 
    -- Identificar se a coluna contém apenas asteriscos (qualquer quantidade)
    NomeFantasia LIKE '%*%' AND LEN(NomeFantasia) > 2 -- Garantir que tem mais de 2 asteriscos
    OR NomeFantasia = '""' -- Para lidar com strings contendo apenas aspas duplas
    OR NomeFantasia LIKE '%-% '-- Se contém traços
    OR 
    -- Identificar números puros ou notações científicas
    (PATINDEX('%[0-9]%', NomeFantasia) > 0 AND 
     (
        NomeFantasia NOT LIKE '%[a-zA-Z]%' -- Não tem letras (somente números ou caracteres especiais)
        OR 
        NomeFantasia LIKE '%[0-9]%[eE]%[+-]%' -- Formato de notação científica
        OR 
        NomeFantasia LIKE '%,%' -- Se contém vírgula (como no exemplo 1,2548725+13)
    ))




SELECT * FROM Reclamacoes; -- Verificar se toda tabela foi Limpa



-- 5. Ajustes finais

-- Criar colunas e views necessárias para o projeto
ALTER TABLE Reclamacoes
ADD Tempo_Resolucao_Dias AS 
    DATEDIFF(DAY, DataAbertura, DataArquivamento);



-- Criando a view ReclamacoesPorTipo
CREATE VIEW vw_ReclamacoesPorTipo AS
SELECT 
    DescricaoAssunto, 
    DescricaoProblema,
    COUNT(*) AS total_reclamacoes
FROM 
    Reclamacoes
GROUP BY 
    DescricaoAssunto, DescricaoProblema;


 --Visualizando a View
SELECT * FROM vw_ReclamacoesPorTipo;


-- Criando a view TempoMedioResolucao 
CREATE VIEW vw_TempoMedioResolucao 
AS SELECT DescricaoAssunto, DescricaoProblema, 
-- Cálculo do tempo médio em dias
CONCAT( ROUND(AVG(Tempo_Resolucao_Dias), 0), ' dias' ) AS tempo_medio_resolucao 
FROM Reclamacoes 
WHERE Tempo_Resolucao_Dias IS NOT NULL 
GROUP BY DescricaoAssunto, DescricaoProblema;



--Visualizando a View
SELECT * FROM vw_TempoMedioResolucao; 



-- Criando a view ProcedenciaPercentual
ALTER VIEW vw_ProcedenciaPercentual AS
WITH ReclamacoesStatus AS (
    SELECT
        COUNT(*) AS TotalReclamacoes,
        SUM(CASE WHEN Atendida = 'Sim' THEN 1 ELSE 0 END) AS TotalAtendidas,
        SUM(CASE WHEN Atendida = 'Não' THEN 1 ELSE 0 END) AS TotalNaoAtendidas
    FROM Reclamacoes
)
SELECT
    TotalReclamacoes,
    TotalAtendidas,
    TotalNaoAtendidas,
    -- Retornar os percentuais como números (não como strings)
    ROUND(CAST(TotalAtendidas AS FLOAT) / TotalReclamacoes, 4) AS PercentualAtendidas,  -- Ex: 0.1580
    ROUND(CAST(TotalNaoAtendidas AS FLOAT) / TotalReclamacoes, 4) AS PercentualNaoAtendidas  -- Ex: 0.8420
FROM ReclamacoesStatus;

--Visualizando a View
SELECT * FROM vw_ProcedenciaPercentual;



-- Criando a view TendenciaMensal
ALTER VIEW vw_TendenciaMensal AS
WITH ReclamacoesPorStatus AS (
    SELECT
        YEAR(DataAbertura) AS Ano,
        MONTH(DataAbertura) AS Mes,
        COUNT(*) AS TotalReclamacoes,
        SUM(CASE WHEN Atendida = 'Sim' THEN 1 ELSE 0 END) AS TotalAtendidas,
        SUM(CASE WHEN Atendida = 'Não' THEN 1 ELSE 0 END) AS TotalNaoAtendidas
    FROM Reclamacoes
    GROUP BY YEAR(DataAbertura), MONTH(DataAbertura)
)
SELECT 
    Ano, 
    Mes, 
    TotalReclamacoes, 
    TotalAtendidas, 
    TotalNaoAtendidas,
    -- Corrigido: sem multiplicar por 100, já retornando como número decimal
    ROUND(CAST(TotalAtendidas AS FLOAT) / TotalReclamacoes, 4) AS PercentualAtendidas,  -- Ex: 0.1580
    ROUND(CAST(TotalNaoAtendidas AS FLOAT) / TotalReclamacoes, 4) AS PercentualNaoAtendidas  -- Ex: 0.8420
FROM ReclamacoesPorStatus;


--Visualizando a View
SELECT * FROM vw_TendenciaMensal; 





SELECT * FROM Reclamacoes;--Verificação final de toda tabela limpa e atualizada
