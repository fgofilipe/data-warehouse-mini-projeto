-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
--
--  ATENCAO AO POSTGRESQL: int / int TRUNCA. Nos percentuais e taxas use o fator
--  100.0 / 1000.0 (com ponto); e ROUND(x, casas) exige x numerico.
-- =====================================================================================

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

SELECT
    l.porte,
    ROUND(AVG(f.dias_integracao_separacao), 1) AS media_integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 1)       AS media_separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 1)        AS media_nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 1)     AS media_despacho_entrega,
    ROUND(AVG(f.dias_total_ate_entrega), 1)    AS media_total_ate_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte
ORDER BY l.porte;


-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

SELECT
    c.nome_categoria,
    ROUND(SUM(f.vl_liquido)) AS faturamento,
    ROUND(100.0 * SUM(f.vl_liquido)
        / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS percentual_do_total
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
GROUP BY c.nome_categoria
ORDER BY faturamento DESC;

-- Extra para o README: confirmar se a categoria campeã se repete nos 3 portes.
SELECT
    l.porte,
    c.nome_categoria,
    ROUND(SUM(f.vl_liquido)) AS faturamento
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte, c.nome_categoria
ORDER BY l.porte, faturamento DESC;


-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

SELECT
    canal_pedido,
    ROUND(AVG(CASE WHEN houve_desconto = 'Sim' THEN vl_liquido END), 2) AS ticket_medio_com_desconto,
    ROUND(AVG(CASE WHEN houve_desconto = 'Nao' THEN vl_liquido END), 2) AS ticket_medio_sem_desconto,
    ROUND(100.0 * SUM(vl_liquido)
        / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS percentual_do_faturamento
FROM fato_pedido
GROUP BY canal_pedido
ORDER BY percentual_do_faturamento DESC;


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

