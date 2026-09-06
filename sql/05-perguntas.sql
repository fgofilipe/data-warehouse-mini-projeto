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

SELECT
    pr.nome_praca,
    pr.domicilios_com_pet,
    ROUND(SUM(f.vl_liquido * b.fator_publico)) AS faturamento_rateado,
    ROUND(SUM(f.vl_liquido * b.fator_publico) / NULLIF(pr.domicilios_com_pet, 0), 2)
        AS faturamento_por_domicilio
FROM fato_pedido f
JOIN dim_loja l           ON l.sk_loja = f.sk_loja
JOIN bridge_loja_praca b  ON b.cod_loja = l.cod_loja
JOIN dim_praca pr          ON pr.sk_praca = b.sk_praca
GROUP BY pr.nome_praca, pr.domicilios_com_pet
ORDER BY faturamento_rateado DESC;

-- Extra para o README: os 3 pedidos sem loja nao entram no rateio por praca
-- (nao ha cod_loja para achar a ponte). Some este valor ao rateio para bater
-- com o total da rede - confira com o 00-conferencia.sql.
SELECT ROUND(SUM(vl_liquido)) AS faturamento_sem_loja_identificada
FROM fato_pedido
WHERE sk_loja = -1;


-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens vendidos por mil habitantes da cidade nao em
--      valor absoluto e cruze com o tempo medio de entrega.

SELECT
    l.nome_loja,
    l.cidade,
    l.populacao_cidade,
    SUM(f.qt_itens) AS itens_vendidos,
    ROUND(1000.0 * SUM(f.qt_itens) / NULLIF(l.populacao_cidade, 0), 2) AS itens_por_mil_habitantes,
    ROUND(AVG(f.dias_total_ate_entrega), 1) AS tempo_medio_entrega_dias
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.nome_loja, l.cidade, l.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

--  (b) A faixa de franquia no cadastro e a de HOJE (o passado foi sobrescrito).
--      Mostra o faturamento por faixa ATUAL. No README, explique por que isso
--      nao responde "quanto veio de lojas que JA ERAM Ouro na data do pedido".

SELECT
    l.faixa_franquia,
    ROUND(SUM(f.vl_liquido)) AS faturamento,
    ROUND(100.0 * SUM(f.vl_liquido)
        / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS percentual_do_total
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.faixa_franquia
ORDER BY faturamento DESC;

--  (c) Meca o que ficou de fora: pedidos sem loja identificada, entregas ainda
--      nao concluidas, itens e valores em branco.

SELECT
    SUM(CASE WHEN sk_loja = -1 THEN 1 ELSE 0 END)          AS pedidos_sem_loja,
    SUM(CASE WHEN sk_tempo_entrega = -1 THEN 1 ELSE 0 END) AS entregas_nao_concluidas,
    SUM(CASE WHEN qt_itens IS NULL THEN 1 ELSE 0 END)      AS pedidos_com_itens_em_branco,
    SUM(CASE WHEN vl_liquido IS NULL THEN 1 ELSE 0 END)    AS pedidos_com_valor_em_branco
FROM fato_pedido;
