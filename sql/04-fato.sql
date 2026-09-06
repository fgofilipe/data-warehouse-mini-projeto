-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
-- =====================================================================================

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

    -- sk_tempo_pedido: a chave e a propria data, calculada, sem JOIN.
    -- Data do pedido vem no formato americano com AM/PM.
    TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int,

    -- sk_tempo_entrega: -1 se a entrega ainda nao aconteceu (marco em branco).
    CASE
        WHEN p."DtEntregaCliente" = '' THEN -1
        ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int
    END,

    -- sk_loja: acha a loja pelo NOME limpo. Se nao achar, -1.
    COALESCE(dl.sk_loja, -1),

    -- sk_categoria: acha pela grafia crua, join de uma linha so. Se nao achar, -1.
    COALESCE(dc.sk_categoria, -1),

    -- houve_desconto: 17 grafias caem em 3 valores. Acento fora antes do UPPER.
    CASE
        WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
                 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç',
                 'AAAAEEIOOOUUCaaaaeeiooouuc')) IN ('S','SIM','1','X','TRUE','V')
            THEN 'Sim'
        WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
                 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç',
                 'AAAAEEIOOOUUCaaaaeeiooouuc')) IN ('N','NAO','0','FALSE','F')
            THEN 'Nao'
        ELSE 'Nao Informado'
    END,

    -- canal_pedido: ORDEM IMPORTA - "WHATSAPP" contem "APP", entao testa WHATS antes.
    CASE
        WHEN UPPER(p."CanalPedido") LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(p."CanalPedido") LIKE '%APP%'   THEN 'App'
        WHEN UPPER(p."CanalPedido") LIKE '%SITE%'  THEN 'Site'
        WHEN UPPER(p."CanalPedido") LIKE '%LOJA%'  THEN 'Loja Fisica'
        WHEN UPPER(p."CanalPedido") LIKE '%TEL%'   THEN 'Telefone'
        ELSE 'Nao Informado'
    END,

    -- dt_pedido
    TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'),

    -- qt_itens: '' e '-' viram NULL, nunca 0
    CASE
        WHEN TRIM(p."QTD.Itens") IN ('', '-') THEN NULL
        ELSE CAST(p."QTD.Itens" AS INTEGER)
    END,

    -- vl_liquido: expressao do enunciado, trata "R$ 1.850,00" / "1850.00" / "-" / vazio
    CASE
        WHEN TRIM(REPLACE(p."ValorLiquidoPedido(R$)", 'R$', '')) IN ('', '-') THEN NULL
        WHEN p."ValorLiquidoPedido(R$)" LIKE '%,%'
            THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",
                    'R$', ''), ' ', ''), '.', ''), ',', '.') AS DECIMAL(15,2))
        ELSE CAST(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)", 'R$', ''), ' ', '') AS DECIMAL(15,2))
    END,

    -- dias_integracao_separacao: NULL se o marco de fim (separacao) esta em branco
    CASE
        WHEN p."Dt Separacao Estoque" = '' THEN NULL
        ELSE p."Dt Separacao Estoque"::date
             - TO_TIMESTAMP(p."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date
    END,

    -- dias_separacao_nota
    CASE
        WHEN p."DtNotaFiscal" = '' THEN NULL
        ELSE p."DtNotaFiscal"::date - p."Dt Separacao Estoque"::date
    END,

    -- dias_nota_despacho
    CASE
        WHEN p."Dt_Despacho_Transportadora" = '' THEN NULL
        ELSE p."Dt_Despacho_Transportadora"::date - p."DtNotaFiscal"::date
    END,

    -- dias_despacho_entrega
    CASE
        WHEN p."DtEntregaCliente" = '' THEN NULL
        ELSE p."DtEntregaCliente"::date - p."Dt_Despacho_Transportadora"::date
    END,

    -- dias_total_ate_entrega: o processo inteiro, do ERP ate o cliente
    CASE
        WHEN p."DtEntregaCliente" = '' THEN NULL
        ELSE p."DtEntregaCliente"::date
             - TO_TIMESTAMP(p."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date
    END

FROM stg_pedido p

-- LOJA: limpa o nome (tira /SC, colapsa espaco duplo, tira espaco das pontas,
-- tira acento e maiuscula) e resolve as 3 grafias que sobram com um CASE escrito
-- a mao. So depois faz o lookup em dim_loja.chave_loja.
LEFT JOIN dim_loja dl
    ON dl.chave_loja = CASE
        WHEN UPPER(TRANSLATE(
                 TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')),
                 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc'))
             = 'PATA AMIGA BLUMENAL CENTRO'  THEN 'PATA AMIGA BLUMENAU CENTRO'
        WHEN UPPER(TRANSLATE(
                 TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')),
                 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc'))
             = 'PATA AMIGA FLORIPA NORTE'     THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
        WHEN UPPER(TRANSLATE(
                 TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')),
                 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc'))
             = 'PATA AMIGA JGUA DO SUL'       THEN 'PATA AMIGA JARAGUA DO SUL'
        ELSE UPPER(TRANSLATE(
                 TRIM(REPLACE(REPLACE(TRIM(p."Loja-Nome"), '/SC', ''), '  ', ' ')),
                 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç', 'AAAAEEIOOOUUCaaaaeeiooouuc'))
    END

-- CATEGORIA: join de uma linha so, pela grafia crua
LEFT JOIN dim_categoria dc
    ON dc.categoria_origem = p."CategoriaProduto";

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
