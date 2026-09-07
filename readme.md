# 🐾 Pata Amiga — Data Warehouse

##Filipe de Oliveira Gomes

link para video apresentação: - Standby


![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?style=flat\&logo=postgresql\&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Data%20Warehouse-orange?style=flat)
![Git](https://img.shields.io/badge/Git-Version%20Control-F05032?style=flat\&logo=git\&logoColor=white)
![Status](https://img.shields.io/badge/Status-Concluído-success)


## 📌 Sobre o projeto

Este projeto foi desenvolvido como parte do **Mini-Projeto Avaliativo — Análise de Dados / Módulo 2**, utilizando o case da rede de pet shops **Pata Amiga**.

A empresa possui dados de pedidos, lojas e praças de atendimento provenientes de diferentes sistemas. Entretanto, as informações apresentam problemas de padronização, como diferentes formatos de datas, valores monetários armazenados como texto, múltiplas grafias para lojas e categorias, além de informações ausentes.

O objetivo do projeto é transformar essas fontes em um **modelo dimensional**, permitindo que os dados sejam analisados de forma consistente e respondendo a cinco perguntas de negócio essenciais.

---

# 🎯 Objetivo

Construir um **Data Warehouse dimensional em PostgreSQL 16**, utilizando um modelo estrela, capaz de organizar os dados da Pata Amiga e responder às cinco perguntas de negócio propostas no desafio.

O projeto parte de três tabelas de staging:

* `stg_pedido` — 4.044 linhas
* `stg_loja` — 32 linhas
* `stg_loja_praca` — 48 linhas

A partir dessas tabelas são construídas as dimensões, a tabela ponte e a tabela fato.

---

# 🔎 Diagnóstico da Origem

A análise diagnóstica realizada nas bases brutas revelou as seguintes volumetrias e inconsistências de dados:

* **Grafias de Lojas:** diferentes variações de escrita para as 32 lojas, incluindo erros de digitação, abreviações e sufixos como `/SC`.
* **Grafias de Categoria:** **37 grafias distintas** presentes na origem para representar 7 categorias reais.
* **Pedidos sem Código de Loja:** **1.575 pedidos (~39%)** vieram com o campo `Cod Loja` em branco, exigindo recuperação pelo nome da loja.
* **Pedidos sem Nome da Loja:** 3 pedidos apresentaram o nome da loja em branco.
* **Marcos de Processo em Branco:**

  * Separação em branco: 1.077 pedidos
  * Nota fiscal em branco: 1.338 pedidos
  * Despacho em branco: 1.665 pedidos
  * **Entrega em branco: 1.953 pedidos**

Esses problemas foram tratados durante o processo de transformação, mantendo a rastreabilidade dos dados e evitando a criação de valores artificiais.

---

# 🏗️ Arquitetura do Data Warehouse e Modelo Dimensional

O modelo desenvolvido utiliza uma arquitetura dimensional baseada em **Star Schema**, com o seguinte grão:

> **1 linha = 1 pedido**

A tabela fato possui **4.044 registros**, mantendo um registro para cada pedido existente na origem.

![Modelo Dimensional](docs/modelo-dimensional.png)

```text
                         dim_tempo
                       /           \
                      /             \
             data pedido       data entrega
                    \               /
                     \             /
                      ┌───────────────┐
                      │  fato_pedido  │
                      │               │
                      │ 1 pedido/linha│
                      └───────────────┘
                       /      |       \
                      /       |        \
                     /        |         \
              dim_loja  dim_categoria  bridge_loja_praca
                                               |
                                           dim_praca
```

---

# 🧩 Estrutura do Modelo

## 📅 dim_tempo

Dimensão responsável pelo tratamento das datas utilizadas no Data Warehouse.

A mesma dimensão é utilizada para diferentes papéis:

* Data do pedido
* Data de entrega

Essa abordagem caracteriza o uso de uma **Role-Playing Dimension**.

---

## 🏪 dim_loja

Dimensão responsável pelas informações cadastrais das lojas.

Entre os principais atributos estão:

* Código da loja
* Chave padronizada da loja
* Nome da loja
* Município
* UF
* Mesorregião
* População
* Área territorial
* Porte
* Tier atual da franquia
* Formato da loja

A dimensão possui também o registro:

> `-1 = Não Informado`

Esse registro é utilizado para preservar a integridade referencial quando não é possível identificar a loja de um pedido.

---

## 🏷️ dim_categoria

Dimensão criada para padronizar as diferentes grafias encontradas na origem.

As categorias foram consolidadas em:

| Categoria padronizada |
| --------------------- |
| Alimentacao           |
| Bem-estar             |
| Saude e Higiene       |
| Medicamento           |
| Petisco               |
| Racao                 |
| Higiene               |
| Acessorio             |
| Brinquedo             |
| Servico               |
| Nao Informado         |

A classificação respeita a ordem das regras de negócio.

Um exemplo importante é:

> **Ração Medicamentosa → Medicamento**

Por isso, a regra de `MED` deve ser avaliada antes da regra de `RA`.

A dimensão mantém também a informação da grafia original através do campo `categoria_origem`.

---

## 📍 dim_praca

Dimensão responsável pelas áreas de atendimento da rede.

Cada praça representa uma região utilizada para análise de distribuição de receita e atendimento.

---

## 🔗 bridge_loja_praca

Tabela ponte utilizada para representar o relacionamento **N:N** entre lojas e praças.

Como uma loja pode atender mais de uma praça, cada relacionamento possui um:

> `fator_publico`

Esse fator representa a proporção utilizada para distribuir a receita da loja entre as praças.

Para cada loja:

> **Σ fator_publico = 1,00**

Essa regra evita a duplicação da receita quando os valores são agregados por praça.

---

## 📦 fato_pedido

Tabela fato principal do Data Warehouse.

O grão da tabela é:

> **1 linha = 1 pedido**

A tabela possui:

* Chaves das dimensões
* Valor bruto
* Desconto
* Valor líquido
* Quantidade de itens
* Canal de venda
* Datas relacionadas ao processo
* Intervalos entre as etapas do pedido
* Tempo total até a entrega

Quando uma informação dimensional não pode ser identificada, a chave estrangeira recebe:

> `-1 = Não Informado`

Dessa forma, não são utilizadas chaves estrangeiras nulas.

---

# 🧹 Tratamento e Padronização dos Dados

## 📅 Datas

As datas de origem apresentam formatos diferentes.

Foram tratados:

* Datas do pedido
* Data de integração com o ERP
* Data de separação
* Data da nota fiscal
* Data de despacho
* Data de entrega

Os marcos ainda não concluídos permanecem como `NULL`.

> Um processo não concluído não é representado como `0`.

---

## 💰 Valores monetários

Os valores financeiros originalmente armazenados como texto foram convertidos para tipos numéricos adequados.

Valores vazios ou representados por `-` são tratados como `NULL`, nunca como zero.

---

## 🏪 Padronização das lojas

Foram realizadas etapas de normalização para permitir a identificação correta das lojas.

Entre os tratamentos realizados:

* Remoção do sufixo `/SC`
* Remoção de espaços duplicados
* Conversão para letras maiúsculas
* Uso de `TRANSLATE`
* Correção de grafias específicas

Algumas correções manuais necessárias incluem:

```text
PATA AMIGA BLUMENAL CENTRO
→ PATA AMIGA BLUMENAU CENTRO

PATA AMIGA FLORIPA NORTE
→ PATA AMIGA FLORIANOPOLIS NORTE

PATA AMIGA JGUA DO SUL
→ PATA AMIGA JARAGUA DO SUL
```

---

## 🏷️ Padronização das categorias

As 37 grafias existentes na origem foram normalizadas de acordo com as regras de negócio.

Exemplos:

```text
MED     → Medicamento
PETISC  → Petisco
RA      → Racao
HIG     → Higiene
BRINQ   → Brinquedo
ACESS   → Acessorio
SERV    → Servico
```

Valores que não se enquadram nas regras recebem:

```text
Nao Informado
```

---

# ❓ Perguntas de Negócio

O Data Warehouse foi construído para responder a cinco perguntas principais.

---

# 1️⃣ Onde está o gargalo na entrega?

Foi calculado o tempo médio entre cada etapa do processo:

```text
Integração → Separação
Separação → Nota
Nota → Despacho
Despacho → Entrega
```

Os resultados indicam que o principal gargalo está no intervalo:

> **Nota → Despacho**

O problema é especialmente relevante nas lojas de **pequeno porte**, que apresentam tempo médio significativamente superior às lojas médias e grandes.

### Média aproximada por porte

| Porte   | Integração → Separação | Separação → Nota | Nota → Despacho | Despacho → Entrega |         Total |
| ------- | ---------------------: | ---------------: | --------------: | -----------------: | ------------: |
| Grande  |               2,0 dias |         0,6 dias |        3,3 dias |           2,0 dias |      7,9 dias |
| Média   |               2,0 dias |         0,6 dias |        3,4 dias |           2,0 dias |      8,0 dias |
| Pequena |               3,0 dias |         0,7 dias |    **8,5 dias** |           2,9 dias | **15,2 dias** |

### 💡 Insight

O tempo elevado entre emissão da nota e despacho sugere um possível problema operacional no processo de expedição, principalmente nas unidades menores.

---

# 2️⃣ Qual categoria gera mais receita?

A distribuição de receita por categoria padronizada apresentou aproximadamente:

| Categoria   |         Receita | Participação |
| ----------- | --------------: | -----------: |
| Racao       | R$ 1.076.202,55 |   **60,01%** |
| Medicamento |   R$ 305.904,03 |   **17,06%** |
| Petisco     |   R$ 128.590,16 |        7,17% |
| Servico     |    R$ 94.001,37 |        5,24% |
| Higiene     |    R$ 92.314,45 |        5,15% |
| Acessorio   |    R$ 64.661,39 |        3,61% |
| Brinquedo   |    R$ 31.634,56 |        1,76% |

A categoria de maior faturamento é:

> 🥇 **Racao — 60,01% da receita**

### 💡 Insight

A forte concentração de receita em ração demonstra a importância dessa categoria para o negócio e indica que alterações em preço, estoque ou disponibilidade podem gerar impacto significativo no faturamento da rede.

---

# 3️⃣ Os descontos são efetivos?

Foi realizada uma análise dos pedidos por canal, comparando o ticket médio de pedidos com desconto e sem desconto.

| Canal         | Ticket com desconto | Ticket sem desconto | Participação na receita |
| ------------- | ------------------: | ------------------: | ----------------------: |
| App           |           R$ 488,04 |           R$ 167,63 |                  30,79% |
| Site          |           R$ 501,92 |           R$ 189,68 |                  25,13% |
| Loja Física   |           R$ 494,04 |           R$ 197,55 |                  20,11% |
| WhatsApp      |           R$ 514,33 |           R$ 179,26 |                  10,52% |
| Telefone      |           R$ 514,02 |           R$ 195,23 |                   6,88% |
| Não Informado |           R$ 561,59 |           R$ 206,95 |                   6,57% |

### 💡 Insight

Em todos os canais analisados, o ticket médio dos pedidos com desconto é superior ao dos pedidos sem desconto.

Isso indica uma associação positiva entre utilização de descontos e valor do pedido.

Entretanto, a análise não permite afirmar que o desconto **causou** o aumento do ticket, pois podem existir outros fatores envolvidos, como perfil do cliente, composição do carrinho e campanhas específicas.

---

# 4️⃣ Qual praça possui maior receita?

Como as lojas podem atender múltiplas praças, a receita foi distribuída utilizando o `fator_publico` da tabela `bridge_loja_praca`.

Dessa forma, a receita não é contabilizada integralmente em todas as praças atendidas.

Entre os principais resultados:

| Praça                | Receita aproximada |
| -------------------- | -----------------: |
| Vale do Itajai       |      R$ 633.746,09 |
| Grande Florianopolis |      R$ 283.546,75 |
| Norte Industrial     |      R$ 175.431,90 |
| Litoral Sul          |      R$ 137.051,20 |
| Litoral Norte        |      R$ 128.872,75 |

A praça com maior receita é:

> 🥇 **Vale do Itajai**

### 💡 Insight

A utilização do fator de alocação permite distribuir a receita de maneira proporcional, evitando a duplicação dos valores quando uma loja atende mais de uma praça.

Além disso, a análise pode ser comparada com a quantidade estimada de domicílios com animais de estimação, permitindo observar oportunidades de mercado.

---

# 5️⃣ Onde abrir a próxima loja?

Para identificar possíveis oportunidades, foi analisada a quantidade de itens vendidos por **1.000 habitantes** e posteriormente cruzada com o tempo médio de entrega.

Entre os municípios com maior indicador:

| Loja                      | Itens / 1.000 habitantes | Tempo médio de entrega |
| ------------------------- | -----------------------: | ---------------------: |
| Rio dos Cedros            |                **41,87** |              14,2 dias |
| Presidente Getulio        |                    34,84 |              14,2 dias |
| Ibirama                   |                    32,07 |              15,4 dias |
| Itapoa                    |                    25,94 |              15,4 dias |
| Santo Amaro da Imperatriz |                    23,71 |              15,9 dias |

### 🥇 Principal candidata

> **Pata Amiga Rio dos Cedros**

A unidade apresenta o maior volume de itens vendidos por 1.000 habitantes entre os municípios analisados.

Além disso, apresenta tempo médio de entrega elevado, o que pode indicar uma combinação de **demanda relevante + oportunidade de melhoria logística**.

### ⚠️ Limitações da análise

O indicador não é suficiente, sozinho, para determinar definitivamente o local da próxima loja.

Seria necessário complementar a análise com informações como:

* Concorrência local
* Renda média
* Crescimento populacional
* Aluguel e custo imobiliário
* Margem de contribuição
* Distância das lojas existentes
* Potencial de mercado
* Número de clientes
* Crescimento histórico da demanda
* Custos logísticos

Portanto, **Rio dos Cedros deve ser tratado como uma candidata para investigação**, e não como uma decisão definitiva de expansão.

---

# 📊 Receita por Tier Atual da Franquia

Também foi analisada a receita de acordo com o **tier atual** das lojas.

| Tier atual | Pedidos |         Receita | Ticket médio |
| ---------- | ------: | --------------: | -----------: |
| Ouro       |   2.316 | R$ 1.012.264,38 |    R$ 451,46 |
| Diamante   |     818 |   R$ 382.209,74 |    R$ 477,76 |
| Prata      |     719 |   R$ 314.812,03 |    R$ 451,02 |
| Bronze     |     188 |    R$ 84.036,06 |    R$ 461,74 |

### ⚠️ Importante

Essa análise utiliza o **tier atual da loja**.

Portanto, ela **não permite afirmar qual era o tier da franquia no momento de cada pedido**.

Para realizar uma análise histórica correta seria necessário possuir uma tabela de histórico de alterações de tier, contendo, por exemplo:

```text
cod_loja
tier
data_inicio
data_fim
```

Sem essa informação, o tier atual não deve ser utilizado como se fosse uma característica histórica do pedido.

---

# 🧪 Validações do Data Warehouse

Após a execução dos scripts, alguns checkpoints importantes devem ser confirmados.

| Validação                        | Resultado esperado |
| -------------------------------- | -----------------: |
| Registros em `stg_pedido`        |              4.044 |
| Registros em `stg_loja`          |                 32 |
| Registros em `stg_loja_praca`    |                 48 |
| Registros em `dim_tempo`         |                236 |
| Registros em `dim_loja`          |                 33 |
| Registros em `dim_categoria`     |                 38 |
| Registros em `dim_praca`         |                 13 |
| Registros em `bridge_loja_praca` |                 48 |
| Registros em `fato_pedido`       |          **4.044** |
| FKs nulas/orfãs                  |              **0** |
| Pedidos na loja `-1`             |                  3 |
| Entregas incompletas             |              1.953 |

O valor total de receita esperado é aproximadamente:

> **R$ 1.793.309,00**

Além disso, a receita alocada por praça deve reconciliar com a receita da rede, considerando os pedidos sem loja identificada.

---

# 📁 Organização dos Scripts

Os scripts devem ser executados na seguinte ordem:

```text
01-carga-staging.sql
        ↓
02-dimensoes-prontas.sql
        ↓
03-dimensoes-bridge.sql
        ↓
04-fato-pedido.sql
        ↓
05-perguntas-negocio.sql
```

O script:

```text
00-conferencia.sql
```

é utilizado para realizar as validações e conferir os checkpoints esperados.

---

# 🗂️ Estrutura do Projeto

Uma possível organização do projeto é:

```text
pata-amiga/
│
├── README.md
│
├── docs/
│   └── modelo-dimensional.png
│
├── sql/
│   ├── 00-conferencia.sql
│   ├── 01-carga-staging.sql
│   ├── 02-dimensoes-prontas.sql
│   ├── 03-dimensoes-bridge.sql
│   ├── 04-fato-pedido.sql
│   └── 05-perguntas-negocio.sql
│
└── ...
```

---

# ▶️ Como executar

## 1. Criar o banco

Utilize o **PostgreSQL 16** para executar o projeto.

## 2. Executar o staging

Execute:

```sql
01-carga-staging.sql
```

Esse script realiza a carga das tabelas de staging.

## 3. Criar as dimensões fornecidas

Execute:

```sql
02-dimensoes-prontas.sql
```

## 4. Criar dimensões e tabela ponte

Execute:

```sql
03-dimensoes-bridge.sql
```

## 5. Popular a tabela fato

Execute:

```sql
04-fato-pedido.sql
```

A tabela `fato_pedido` deverá conter:

```text
4.044 registros
```

## 6. Executar as perguntas de negócio

Por fim:

```sql
05-perguntas-negocio.sql
```

Esse script apresenta as consultas utilizadas para responder às cinco perguntas propostas.

## 7. Conferir os resultados

Execute:

```sql
00-conferencia.sql
```

para validar os principais checkpoints do projeto.

---

# 🛠️ Tecnologias utilizadas

* **PostgreSQL 16**
* **SQL**
* **Git**
* **GitHub**
* **VS Code**

---

# 📌 Principais aprendizados

Durante o desenvolvimento do projeto foram aplicados conceitos de:

* Modelagem dimensional
* Star Schema
* Tabelas fato e dimensões
* Role-Playing Dimension
* Tabela Bridge
* Chaves substitutas
* Tratamento de valores nulos
* Padronização de dados
* Limpeza de dados
* Conversão de tipos
* Tratamento de datas
* Normalização de categorias
* Recuperação de chaves
* Integridade referencial
* Análise exploratória em SQL
* Indicadores de negócio
* Reconciliação de receita
* Análise crítica de dados

---

# ⚠️ Limitações

Apesar da construção do Data Warehouse permitir responder às perguntas propostas, algumas limitações permanecem.

Entre elas:

* Grande quantidade de pedidos sem código de loja;
* Pedidos com etapas do processo ainda não concluídas;
* Ausência de histórico dos tiers das franquias;
* Ausência de informações completas sobre concorrência;
* Ausência de dados de renda e potencial econômico por município;
* Ausência de custos imobiliários;
* Ausência de margem por categoria;
* Ausência de informações completas sobre clientes e recorrência.

Por isso, os indicadores devem ser utilizados como **apoio à tomada de decisão**, e não como única fonte para decisões estratégicas.

---

# 🚀 Possíveis melhorias futuras

Como evolução do projeto, poderiam ser implementadas:

* Histórico de alterações do tier das franquias;
* Dados de clientes e recorrência de compra;
* Margem de contribuição por produto;
* Dados de concorrência;
* Dados socioeconômicos por município;
* Custos logísticos;
* Indicadores de estoque;
* Análise de sazonalidade;
* Dashboards em Power BI ou ferramenta equivalente;
* Monitoramento automatizado dos indicadores;
* Pipeline de ETL/ELT automatizado.

---

# 👨‍💻 Conclusão

O projeto **Pata Amiga — Data Warehouse** demonstra como dados brutos e inconsistentes podem ser transformados em uma estrutura dimensional organizada e confiável para análise.

A construção do modelo permitiu centralizar informações de pedidos, lojas, categorias e praças, garantindo **4.044 pedidos na tabela fato**, integridade referencial e tratamento adequado das informações ausentes.

A partir desse modelo foi possível identificar gargalos logísticos, analisar a concentração de receita por categoria, avaliar o comportamento dos descontos, distribuir corretamente a receita entre as praças e identificar possíveis oportunidades de expansão.

O projeto também evidencia a importância de conhecer as **limitações dos dados** antes de transformar indicadores em decisões de negócio.

> **Dados bem tratados geram análises mais confiáveis e decisões de negócio mais conscientes.** 
        