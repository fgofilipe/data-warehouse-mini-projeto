-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
-- =====================================================================================

-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================


-- TRUNCATE PARA LIMPAR A TABELA ANTES DA CARGA
TRUNCATE TABLE fato_pedido RESTART IDENTITY;

-- CARGA DA TABELA FATO
INSERT INTO fato_pedido (
    numero_pedido,
    sk_tempo_pedido,
    sk_tempo_entrega,
    sk_loja,
    sk_categoria,
    houve_desconto,
    canal_pedido,
    dt_pedido,
    qt_itens,
    vl_liquido,
    dias_integracao_separacao,
    dias_separacao_nota,
    dias_nota_despacho,
    dias_despacho_entrega,
    dias_total_ate_entrega
)
SELECT
    p."NumeroPedido",
    TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int,
    CASE
        WHEN p."DtEntregaCliente" = '' THEN -1
        ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int
    END,
    COALESCE(dl.sk_loja, -1),
    COALESCE(dc.sk_categoria, -1),
    CASE
        WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc')) IN ('S','SIM','1','X','TRUE','V') THEN 'Sim'
        WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc')) IN ('N','NAO','0','FALSE','F') THEN 'Nao'
        ELSE 'Nao Informado'
    END,
    CASE
        WHEN UPPER(p."CanalPedido") LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(p."CanalPedido") LIKE '%APP%'   THEN 'App'
        WHEN UPPER(p."CanalPedido") LIKE '%SITE%'  THEN 'Site'
        WHEN UPPER(p."CanalPedido") LIKE '%LOJA%'  THEN 'Loja Fisica'
        WHEN UPPER(p."CanalPedido") LIKE '%TEL%'   THEN 'Telefone'
        ELSE 'Nao Informado'
    END,
    TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'),
    CASE
        WHEN TRIM(p."QTD.Itens") IN ('', '-') THEN NULL
        ELSE CAST(p."QTD.Itens" AS INTEGER)
    END,
    CASE
        WHEN TRIM(REPLACE(p."ValorLiquidoPedido(R$)", 'R$', '')) IN ('', '-') THEN NULL
        WHEN p."ValorLiquidoPedido(R$)" LIKE '%,%'
            THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)", 'R$', ''), ' ', ''), '.', ''), ',', '.') AS DECIMAL(15,2))
        ELSE CAST(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)", 'R$', ''), ' ', '') AS DECIMAL(15,2))
    END,
    CASE
        WHEN p."Dt Separacao Estoque" = '' THEN NULL
        ELSE p."Dt Separacao Estoque"::date - TO_TIMESTAMP(p."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date
    END,
    CASE
        WHEN p."DtNotaFiscal" = '' THEN NULL
        ELSE p."DtNotaFiscal"::date - p."Dt Separacao Estoque"::date
    END,
    CASE
        WHEN p."Dt_Despacho_Transportadora" = '' THEN NULL
        ELSE p."Dt_Despacho_Transportadora"::date - p."DtNotaFiscal"::date
    END,
    CASE
        WHEN p."DtEntregaCliente" = '' THEN NULL
        ELSE p."DtEntregaCliente"::date - p."Dt_Despacho_Transportadora"::date
    END,
    CASE
        WHEN p."DtEntregaCliente" = '' THEN NULL
        ELSE p."DtEntregaCliente"::date - TO_TIMESTAMP(p."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date
    END
FROM stg_pedido p
LEFT JOIN dim_loja dl
    ON UPPER(TRANSLATE(TRIM(dl.chave_loja), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc')) = 
       CASE
           WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc')) = 'PATA AMIGA BLUMENAL CENTRO' THEN 'PATA AMIGA BLUMENAU CENTRO'
           WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc')) = 'PATA AMIGA FLORIPA NORTE' THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
           WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc')) = 'PATA AMIGA JGUA DO SUL' THEN 'PATA AMIGA JARAGUA DO SUL'
           ELSE UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')), 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc'))
       END
LEFT JOIN dim_categoria dc
    ON TRIM(dc.categoria_origem) = TRIM(p."CategoriaProduto");