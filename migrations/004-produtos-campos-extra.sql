-- Migration 004: campos extras em produtos_top para import da planilha Excel
ALTER TABLE produtos_top
  ADD COLUMN IF NOT EXISTS codigo_produto bigint,
  ADD COLUMN IF NOT EXISTS laboratorio    text,
  ADD COLUMN IF NOT EXISTS preco_custo    numeric(10,2),
  ADD COLUMN IF NOT EXISTS preco_venda    numeric(10,2);

CREATE INDEX IF NOT EXISTS idx_produtos_top_codigo     ON produtos_top(codigo_produto);
CREATE INDEX IF NOT EXISTS idx_produtos_top_laboratorio ON produtos_top(laboratorio);
