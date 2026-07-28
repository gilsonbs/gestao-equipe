-- Diagnóstico: o banco está na versão nova do schema?
WITH esperado(objeto, tipo) AS (
  VALUES
    ('funcionarios','tabela'), ('metas','tabela'),
    ('vendas_funcionario','tabela'), ('vendas_loja','tabela'),
    ('folgas','tabela'), ('produtos_top','tabela'),
    ('desempenho_mensal','view')
)
SELECT
  e.objeto,
  e.tipo,
  CASE WHEN c.relname IS NULL THEN '❌ FALTANDO' ELSE '✅ existe' END AS situacao
FROM esperado e
LEFT JOIN pg_class c
  ON c.relname = e.objeto
 AND c.relnamespace = 'public'::regnamespace
UNION ALL
SELECT
  'metas.valor_realizado (não deve existir)',
  'coluna',
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='metas' AND column_name='valor_realizado'
  ) THEN '❌ SCHEMA ANTIGO' ELSE '✅ ok' END
ORDER BY 2, 1;
