-- Migration 007: escalas de trabalho da loja
CREATE TABLE IF NOT EXISTS escalas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  descricao text,
  dias_semana integer[] NOT NULL DEFAULT '{}',
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE escalas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leitura pública - escalas" ON escalas
  FOR SELECT USING (true);

CREATE POLICY "Admin - escalas" ON escalas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_escalas_ativo ON escalas(ativo);
