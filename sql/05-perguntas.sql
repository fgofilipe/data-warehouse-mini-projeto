-- =====================================================================================
--  ARQUIVO 5: AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC | PostgreSQL 16
-- =====================================================================================

-- Rode depois de: 04-fato.sql

-- Cada pergunta possui uma consulta principal.
-- O objetivo é responder às cinco perguntas de negócio utilizando
-- o modelo dimensional construído.

-- ================================================
-- P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?

SELECT
    l.porte,
    ROUND(AVG(f.dias_integracao_separacao), 1) AS media_integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 1) AS media_separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 1) AS media_nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 1) AS media_despacho_entrega,
    ROUND(AVG(f.dias_total_ate_entrega), 1) AS media_total_ate_entrega
FROM fato_pedido f
JOIN dim_loja l
    ON l.sk_loja = f.sk_loja
GROUP BY l.porte
ORDER BY l.porte;


-- ============================================
-- P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?

SELECT
    COALESCE(c.nome_categoria, 'Nao Informado') AS nome_categoria,
    ROUND(SUM(f.vl_liquido)) AS faturamento,
    ROUND(
        100.0 * SUM(f.vl_liquido) / NULLIF((SELECT SUM(vl_liquido) FROM fato_pedido), 0),
        2
    ) AS percentual_do_total
FROM fato_pedido f
LEFT JOIN dim_categoria c
    ON c.sk_categoria = f.sk_categoria
GROUP BY c.nome_categoria
ORDER BY faturamento DESC;


-- =============================================
-- P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?

SELECT
    f.canal_pedido,
    ROUND(
        AVG(
            CASE
                WHEN f.houve_desconto = 'Sim'
                THEN f.vl_liquido
            END
        ),
        2
    ) AS ticket_medio_com_desconto,

    ROUND(
        AVG(
            CASE
                WHEN f.houve_desconto = 'Nao'
                THEN f.vl_liquido
            END
        ),
        2
    ) AS ticket_medio_sem_desconto,

    ROUND(
        100.0 * SUM(f.vl_liquido)
        / (SELECT SUM(vl_liquido) FROM fato_pedido),
        2
    ) AS percentual_do_faturamento

FROM fato_pedido f
GROUP BY f.canal_pedido
ORDER BY percentual_do_faturamento DESC;


-- =======================================================
-- P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?

SELECT
    pr.nome_praca,
    pr.domicilios_com_pet,

    ROUND(
        SUM(f.vl_liquido * b.fator_publico)
    ) AS faturamento_rateado,

    ROUND(
        SUM(f.vl_liquido * b.fator_publico)
        / NULLIF(pr.domicilios_com_pet, 0), 
        2
    ) AS faturamento_por_domicilio

FROM fato_pedido f

JOIN dim_loja l 
    ON l.sk_loja = f.sk_loja

JOIN bridge_loja_praca b 
    ON b.cod_loja = l.cod_loja

JOIN dim_praca pr 
    ON pr.sk_praca = b.sk_praca

GROUP BY 
    pr.nome_praca, 
    pr.domicilios_com_pet

ORDER BY faturamento_rateado DESC;

-- ===============================
-- P5 - ONDE ABRIR A PROXIMA LOJA?

-- (a) Ranking por densidade de itens vendidos por 1.000 habitantes
SELECT
    l.nome_loja,
    l.cidade,
    l.populacao_cidade,

    SUM(f.qt_itens) AS itens_vendidos,

    ROUND(
        1000.0 * SUM(f.qt_itens)
        / NULLIF(l.populacao_cidade, 0),
        2
    ) AS itens_por_mil_habitantes,

    ROUND(
        AVG(f.dias_total_ate_entrega),
        1
    ) AS tempo_medio_entrega_dias

FROM fato_pedido f

JOIN dim_loja l
    ON l.sk_loja = f.sk_loja

WHERE l.sk_loja <> -1

GROUP BY
    l.nome_loja,
    l.cidade,
    l.populacao_cidade

ORDER BY
    itens_por_mil_habitantes DESC,
    tempo_medio_entrega_dias ASC;


-- (b) Faturamento por faixa de franquia atual

SELECT
    l.faixa_franquia, 
    COUNT(f.numero_pedido) AS total_pedidos,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento_total,
    ROUND(AVG(f.vl_liquido), 2) AS ticket_medio

FROM fato_pedido f

JOIN dim_loja l 
    ON l.sk_loja = f.sk_loja

WHERE l.sk_loja <> -1

GROUP BY l.faixa_franquia

ORDER BY faturamento_total DESC;


-- (c) Mapeamento do que ficou de fora das analises

SELECT
    'Pedidos sem Loja Identificada' AS tipo_limitacao,
    COUNT(*) AS total_registros,
    ROUND(SUM(vl_liquido), 2) AS faturamento_impactado
FROM fato_pedido
WHERE sk_loja = -1

UNION ALL

SELECT
    'Entregas Nao Concluidas (Sem DtEntrega)' AS tipo_limitacao,
    COUNT(*) AS total_registros,
    ROUND(SUM(vl_liquido), 2) AS faturamento_impactado
FROM fato_pedido
WHERE sk_tempo_entrega = -1

UNION ALL

SELECT
    'Pedidos com Itens nulos ou nao informados' AS tipo_limitacao,
    COUNT(*) AS total_registros,
    ROUND(SUM(vl_liquido), 2) AS faturamento_impactado
FROM fato_pedido
WHERE qt_itens IS NULL;