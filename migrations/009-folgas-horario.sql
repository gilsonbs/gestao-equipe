-- Adiciona suporte a mudanças de horário na tabela folgas
-- Novo tipo 'horario' e coluna observacao para a nota (ex: "11h CX")

ALTER TABLE folgas
  ADD COLUMN IF NOT EXISTS observacao text;

ALTER TABLE folgas
  DROP CONSTRAINT IF EXISTS folgas_tipo_check;

ALTER TABLE folgas
  ADD CONSTRAINT folgas_tipo_check
  CHECK (tipo IN ('folga', 'ferias', 'horario'));
