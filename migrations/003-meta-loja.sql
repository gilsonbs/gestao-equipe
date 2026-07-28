-- =============================================
-- Migração 003: meta mensal da loja
--
-- Guarda a meta de faturamento da loja em tabela própria, separada de
-- vendas_loja, pelo mesmo motivo que separamos metas de vendas por
-- funcionário: meta e realizado são coisas distintas e podem existir
-- uma sem a outra.
--
-- Não altera nada do que já existe.
-- Rode no SQL Editor do Supabase. É segura para rodar mais de uma vez.
-- =============================================

BEGIN;

CREATE TABLE IF NOT EXISTS metas_loja (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor_meta numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(mes, ano)
);

-- Junta a meta do mês com o total vendido.
--
-- vendas_loja não tem UNIQUE(mes, ano) — pode haver mais de um
-- lançamento no mesmo mês —, então o realizado é a SOMA dos registros
-- do período, que é como o dashboard sempre tratou esses valores.
CREATE OR REPLACE VIEW desempenho_loja
WITH (security_invoker = on) AS
WITH vendas AS (
  SELECT mes, ano, SUM(valor_total)::numeric(12,2) AS total
  FROM vendas_loja
  GROUP BY mes, ano
)
SELECT
  COALESCE(m.mes, v.mes)                   AS mes,
  COALESCE(m.ano, v.ano)                   AS ano,
  COALESCE(m.valor_meta, 0)::numeric(12,2) AS valor_meta,
  COALESCE(v.total, 0)::numeric(12,2)      AS valor_realizado,
  CASE
    WHEN COALESCE(m.valor_meta, 0) > 0
      THEN ROUND((COALESCE(v.total, 0) / m.valor_meta) * 100)
    ELSE NULL
  END                                      AS percentual
FROM metas_loja m
FULL OUTER JOIN vendas v
  ON m.mes = v.mes AND m.ano = v.ano;

GRANT SELECT ON desempenho_loja TO anon, authenticated;

ALTER TABLE metas_loja ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Leitura pública - metas_loja" ON metas_loja;
CREATE POLICY "Leitura pública - metas_loja" ON metas_loja
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin - metas_loja" ON metas_loja;
CREATE POLICY "Admin - metas_loja" ON metas_loja
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_metas_loja_mes_ano ON metas_loja(mes, ano);

COMMIT;
