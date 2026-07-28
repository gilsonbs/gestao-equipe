-- =============================================
-- Schema: Gestão de Equipe
-- Execute no Supabase SQL Editor
-- =============================================

-- Funcionários
CREATE TABLE IF NOT EXISTS funcionarios (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  cargo text,
  data_nascimento date,
  ativo boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Metas mensais (também armazena valor realizado/vendas por funcionário)
CREATE TABLE IF NOT EXISTS metas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor_meta numeric(12,2) NOT NULL DEFAULT 0,
  valor_realizado numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(funcionario_id, mes, ano)
);

-- Vendas totais da loja
CREATE TABLE IF NOT EXISTS vendas_loja (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor_total numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Folgas e Férias
CREATE TABLE IF NOT EXISTS folgas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  data_inicio date NOT NULL,
  data_fim date NOT NULL,
  tipo text NOT NULL CHECK (tipo IN ('folga', 'ferias')),
  created_at timestamptz DEFAULT now(),
  CONSTRAINT data_valida CHECK (data_fim >= data_inicio)
);

-- Top Produtos
CREATE TABLE IF NOT EXISTS produtos_top (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  substancia text,
  categoria text,
  quantidade integer,
  mes integer CHECK (mes BETWEEN 1 AND 12),
  ano integer CHECK (ano >= 2020),
  created_at timestamptz DEFAULT now()
);

-- =============================================
-- Row Level Security (RLS)
-- =============================================

ALTER TABLE funcionarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE metas ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendas_loja ENABLE ROW LEVEL SECURITY;
ALTER TABLE folgas ENABLE ROW LEVEL SECURITY;
ALTER TABLE produtos_top ENABLE ROW LEVEL SECURITY;

-- Leitura pública (dashboard sem login)
CREATE POLICY "Leitura pública - funcionarios" ON funcionarios FOR SELECT USING (true);
CREATE POLICY "Leitura pública - metas" ON metas FOR SELECT USING (true);
CREATE POLICY "Leitura pública - vendas_loja" ON vendas_loja FOR SELECT USING (true);
CREATE POLICY "Leitura pública - folgas" ON folgas FOR SELECT USING (true);
CREATE POLICY "Leitura pública - produtos_top" ON produtos_top FOR SELECT USING (true);

-- Escrita apenas para usuários autenticados (admin)
CREATE POLICY "Admin - funcionarios" ON funcionarios FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admin - metas" ON metas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admin - vendas_loja" ON vendas_loja FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admin - folgas" ON folgas FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admin - produtos_top" ON produtos_top FOR ALL USING (auth.role() = 'authenticated');

-- =============================================
-- Índices para melhorar performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_metas_mes_ano ON metas(mes, ano);
CREATE INDEX IF NOT EXISTS idx_folgas_data_inicio ON folgas(data_inicio);
CREATE INDEX IF NOT EXISTS idx_produtos_top_nome ON produtos_top(nome);
CREATE INDEX IF NOT EXISTS idx_produtos_top_substancia ON produtos_top(substancia);
CREATE INDEX IF NOT EXISTS idx_funcionarios_ativo ON funcionarios(ativo);

