-- =============================================
-- Migração 001: separa metas de vendas
--
-- Para bancos que rodaram a versão inicial do schema, onde a tabela
-- `metas` guardava tanto o valor pactuado quanto o realizado.
--
-- Esta migração NÃO apaga nenhum registro: os valores de
-- metas.valor_realizado são copiados para a nova tabela
-- vendas_funcionario antes de a coluna ser removida.
--
-- Rode no SQL Editor do Supabase. É segura para rodar mais de uma vez.
-- =============================================

BEGIN;

-- 1. Nova tabela de vendas por funcionário
CREATE TABLE IF NOT EXISTS vendas_funcionario (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(funcionario_id, mes, ano)
);

-- 2. Copia os valores realizados que já existiam.
--
--    Precisa ser SQL dinâmico: numa migração já aplicada a coluna
--    metas.valor_realizado não existe mais, e o Postgres analisa a
--    query inteira antes de executá-la — uma referência estática à
--    coluna quebraria o script na segunda execução, antes de qualquer
--    condição ser avaliada.
--
--    O ON CONFLICT cobre o caso de a cópia já ter sido feita.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'metas'
      AND column_name = 'valor_realizado'
  ) THEN
    EXECUTE $sql$
      INSERT INTO vendas_funcionario (funcionario_id, mes, ano, valor)
      SELECT funcionario_id, mes, ano, valor_realizado
      FROM metas
      WHERE valor_realizado > 0
      ON CONFLICT (funcionario_id, mes, ano) DO NOTHING
    $sql$;
  END IF;
END $$;

-- 3. Remove a coluna que passou a viver na outra tabela
ALTER TABLE metas DROP COLUMN IF EXISTS valor_realizado;

-- 4. View de desempenho
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

-- 5. RLS da nova tabela
ALTER TABLE vendas_funcionario ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Leitura pública - vendas_funcionario" ON vendas_funcionario;
CREATE POLICY "Leitura pública - vendas_funcionario" ON vendas_funcionario
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin - vendas_funcionario" ON vendas_funcionario;
CREATE POLICY "Admin - vendas_funcionario" ON vendas_funcionario
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

-- 6. Alinha as demais políticas de escrita com o schema atual:
--    o (select ...) faz o Postgres avaliar a função uma vez por query
--    em vez de uma vez por linha, e o WITH CHECK explicita a regra de
--    INSERT em vez de depender do fallback para o USING.
DROP POLICY IF EXISTS "Admin - funcionarios" ON funcionarios;
CREATE POLICY "Admin - funcionarios" ON funcionarios
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "Admin - metas" ON metas;
CREATE POLICY "Admin - metas" ON metas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "Admin - vendas_loja" ON vendas_loja;
CREATE POLICY "Admin - vendas_loja" ON vendas_loja
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "Admin - folgas" ON folgas;
CREATE POLICY "Admin - folgas" ON folgas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "Admin - produtos_top" ON produtos_top;
CREATE POLICY "Admin - produtos_top" ON produtos_top
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

-- 7. Índices que faltavam
CREATE INDEX IF NOT EXISTS idx_vendas_funcionario_mes_ano ON vendas_funcionario(mes, ano);
CREATE INDEX IF NOT EXISTS idx_vendas_loja_mes_ano        ON vendas_loja(mes, ano);

COMMIT;

-- =============================================
-- Depois de rodar, confira o resultado:
--
--   SELECT nome, valor_meta, valor_realizado, percentual
--   FROM desempenho_mensal ORDER BY ano DESC, mes DESC, nome;
--
-- Registros com valor_meta = 0 são "metas fantasma": foram criados
-- pela tela de Vendas na versão antiga, que inseria uma meta zerada
-- para poder guardar o valor vendido. A venda já foi preservada em
-- vendas_funcionario, então essas linhas podem ser removidas.
--
-- Confira antes o que seria apagado:
--
--   SELECT f.nome, m.mes, m.ano, m.valor_meta
--   FROM metas m JOIN funcionarios f ON f.id = m.funcionario_id
--   WHERE m.valor_meta = 0;
--
-- E só então, se fizer sentido:
--
--   DELETE FROM metas WHERE valor_meta = 0;
-- =============================================
