-- =============================================
-- Migração 002: sistema de avisos
--
-- Adiciona a tabela de avisos e a view que separa os ativos dos
-- expirados. Não altera nada do que já existe.
--
-- Rode no SQL Editor do Supabase. É segura para rodar mais de uma vez.
-- =============================================

BEGIN;

CREATE TABLE IF NOT EXISTS avisos (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo text NOT NULL,
  mensagem text NOT NULL,
  tipo text NOT NULL DEFAULT 'info' CHECK (tipo IN ('info', 'atencao', 'urgente')),
  fixado boolean NOT NULL DEFAULT false,
  -- NULL = sem validade, o aviso fica ativo até ser removido
  data_expiracao date,
  created_at timestamptz DEFAULT now()
);

-- Separa ativos de expirados em um único lugar, para que o dashboard
-- e o admin usem exatamente a mesma regra.
CREATE OR REPLACE VIEW avisos_com_status
WITH (security_invoker = on) AS
SELECT
  a.*,
  (a.data_expiracao IS NULL OR a.data_expiracao >= CURRENT_DATE) AS ativo
FROM avisos a;

GRANT SELECT ON avisos_com_status TO anon, authenticated;

ALTER TABLE avisos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Leitura pública - avisos" ON avisos;
CREATE POLICY "Leitura pública - avisos" ON avisos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin - avisos" ON avisos;
CREATE POLICY "Admin - avisos" ON avisos
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

-- Ordenação padrão do dashboard: fixados primeiro, depois mais recentes
CREATE INDEX IF NOT EXISTS idx_avisos_ordem      ON avisos(fixado DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_avisos_expiracao  ON avisos(data_expiracao);

COMMIT;
