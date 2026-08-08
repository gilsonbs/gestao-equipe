-- Quantidade de entregas a domicílio por mês
CREATE TABLE IF NOT EXISTS entregas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  quantidade integer NOT NULL DEFAULT 0 CHECK (quantidade >= 0),
  created_at timestamptz DEFAULT now(),
  UNIQUE(mes, ano)
);

ALTER TABLE entregas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leitura pública - entregas" ON entregas
  FOR SELECT USING (true);

CREATE POLICY "Admin - entregas" ON entregas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_entregas_mes_ano ON entregas(mes, ano);
