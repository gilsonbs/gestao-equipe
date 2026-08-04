-- Migration 006: adiciona num_atendimentos para cálculo de ticket médio
ALTER TABLE vendas_funcionario
  ADD COLUMN IF NOT EXISTS num_atendimentos integer;

ALTER TABLE vendas_loja
  ADD COLUMN IF NOT EXISTS num_atendimentos integer;

-- Recria desempenho_mensal com num_atendimentos e ticket_medio
CREATE OR REPLACE VIEW desempenho_mensal
WITH (security_invoker = on) AS
SELECT
  COALESCE(m.funcionario_id, v.funcionario_id)      AS funcionario_id,
  m.id                                              AS meta_id,
  v.id                                              AS venda_id,
  f.nome,
  f.cargo,
  COALESCE(m.mes, v.mes)                            AS mes,
  COALESCE(m.ano, v.ano)                            AS ano,
  COALESCE(m.valor_meta, 0)::numeric(12,2)          AS valor_meta,
  COALESCE(v.valor, 0)::numeric(12,2)               AS valor_realizado,
  v.num_atendimentos,
  CASE
    WHEN COALESCE(v.num_atendimentos, 0) > 0
      THEN ROUND(COALESCE(v.valor, 0) / v.num_atendimentos, 2)::numeric(12,2)
    ELSE NULL
  END                                               AS ticket_medio,
  CASE
    WHEN COALESCE(m.valor_meta, 0) > 0
      THEN ROUND((COALESCE(v.valor, 0) / m.valor_meta) * 100)
    ELSE NULL
  END                                               AS percentual
FROM metas m
FULL OUTER JOIN vendas_funcionario v
  ON  m.funcionario_id = v.funcionario_id
  AND m.mes = v.mes
  AND m.ano = v.ano
JOIN funcionarios f
  ON f.id = COALESCE(m.funcionario_id, v.funcionario_id);

GRANT SELECT ON desempenho_mensal TO anon, authenticated;

-- Recria desempenho_loja com total_atendimentos e ticket_medio
CREATE OR REPLACE VIEW desempenho_loja
WITH (security_invoker = on) AS
WITH vendas AS (
  SELECT mes, ano,
    SUM(valor_total)::numeric(12,2)  AS total,
    SUM(num_atendimentos)            AS total_atendimentos
  FROM vendas_loja
  GROUP BY mes, ano
)
SELECT
  COALESCE(m.mes, v.mes)                   AS mes,
  COALESCE(m.ano, v.ano)                   AS ano,
  COALESCE(m.valor_meta, 0)::numeric(12,2) AS valor_meta,
  COALESCE(v.total, 0)::numeric(12,2)      AS valor_realizado,
  v.total_atendimentos,
  CASE
    WHEN COALESCE(v.total_atendimentos, 0) > 0
      THEN ROUND(COALESCE(v.total, 0) / v.total_atendimentos, 2)::numeric(12,2)
    ELSE NULL
  END                                      AS ticket_medio,
  CASE
    WHEN COALESCE(m.valor_meta, 0) > 0
      THEN ROUND((COALESCE(v.total, 0) / m.valor_meta) * 100)
    ELSE NULL
  END                                      AS percentual
FROM metas_loja m
FULL OUTER JOIN vendas v
  ON m.mes = v.mes AND m.ano = v.ano;

GRANT SELECT ON desempenho_loja TO anon, authenticated;
