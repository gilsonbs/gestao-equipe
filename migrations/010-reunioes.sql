-- Reuniões da equipe com tópicos de pauta
-- Execute no Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS reunioes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo text NOT NULL,
  data date NOT NULL,
  descricao text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reunioes_topicos (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reuniao_id uuid NOT NULL REFERENCES reunioes(id) ON DELETE CASCADE,
  ordem integer NOT NULL DEFAULT 0,
  texto text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE reunioes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE reunioes_topicos ENABLE ROW LEVEL SECURITY;

-- Leitura pública (dashboard sem login)
CREATE POLICY "Leitura pública - reunioes"         ON reunioes         FOR SELECT USING (true);
CREATE POLICY "Leitura pública - reunioes_topicos" ON reunioes_topicos FOR SELECT USING (true);

-- Escrita apenas para usuários autenticados
CREATE POLICY "Admin - reunioes" ON reunioes
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - reunioes_topicos" ON reunioes_topicos
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

-- Índices
CREATE INDEX IF NOT EXISTS idx_reunioes_data            ON reunioes(data DESC);
CREATE INDEX IF NOT EXISTS idx_reunioes_topicos_reuniao ON reunioes_topicos(reuniao_id, ordem);
