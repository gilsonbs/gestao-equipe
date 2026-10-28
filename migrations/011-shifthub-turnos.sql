-- =============================================
-- Migration 011: ShiftHub — Gestão de Turnos, Matriz Semanal, Trocas e Auditoria
-- IMPORTANTE: Cole TODO este conteúdo no Supabase SQL Editor e clique em "Run"
-- (certifique-se de que nenhum trecho específico esteja selecionado com o mouse,
-- pois o Supabase executa apenas o texto grifado quando há seleção ativa).
-- =============================================

BEGIN;

-- 1. Evoluir tabela de funcionários com campos operacionais de jornada e restrições
ALTER TABLE public.funcionarios
  ADD COLUMN IF NOT EXISTS contato text,
  ADD COLUMN IF NOT EXISTS carga_horaria_semanal integer NOT NULL DEFAULT 44,
  ADD COLUMN IF NOT EXISTS limite_diario integer NOT NULL DEFAULT 8,
  ADD COLUMN IF NOT EXISTS dias_indisponiveis integer[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS observacoes_restricao text;

-- 2. Modelos de Turnos Pré-configurados (shift_templates)
CREATE TABLE IF NOT EXISTS public.modelos_turno (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  hora_inicio time NOT NULL DEFAULT '07:00',
  hora_fim time NOT NULL DEFAULT '15:00',
  cor text NOT NULL DEFAULT '#0284c7',
  eh_folga boolean NOT NULL DEFAULT false,
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Semear turnos padrão caso a tabela esteja vazia
INSERT INTO public.modelos_turno (nome, hora_inicio, hora_fim, cor, eh_folga)
SELECT * FROM (VALUES
  ('Manhã',     '07:00'::time, '15:00'::time, '#0284c7', false),
  ('Tarde',     '14:00'::time, '22:00'::time, '#d97706', false),
  ('Noturno',   '22:00'::time, '06:00'::time, '#4f46e5', false),
  ('Comercial', '08:00'::time, '17:00'::time, '#059669', false),
  ('Folga',     '00:00'::time, '00:00'::time, '#64748b', true)
) AS v(nome, hora_inicio, hora_fim, cor, eh_folga)
WHERE NOT EXISTS (SELECT 1 FROM public.modelos_turno LIMIT 1);

-- 3. Escala Realizada / Alocada na Matriz Semanal (scheduled_shifts)
CREATE TABLE IF NOT EXISTS public.escala_turnos (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES public.funcionarios(id) ON DELETE CASCADE,
  modelo_turno_id uuid REFERENCES public.modelos_turno(id) ON DELETE SET NULL,
  data date NOT NULL,
  observacao text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'swapped', 'absent')),
  publicado boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE (funcionario_id, data)
);

-- 4. Solicitações de Troca de Turno (swap_requests)
CREATE TABLE IF NOT EXISTS public.trocas_turno (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  turno_origem_id uuid NOT NULL REFERENCES public.escala_turnos(id) ON DELETE CASCADE,
  solicitante_id uuid NOT NULL REFERENCES public.funcionarios(id) ON DELETE CASCADE,
  alvo_funcionario_id uuid NOT NULL REFERENCES public.funcionarios(id) ON DELETE CASCADE,
  turno_alvo_id uuid REFERENCES public.escala_turnos(id) ON DELETE SET NULL,
  motivo text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  respondido_em timestamptz,
  created_at timestamptz DEFAULT now()
);

-- 5. Histórico de Alterações de Escala para Auditoria
CREATE TABLE IF NOT EXISTS public.historico_escala (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  acao text NOT NULL,
  descricao text NOT NULL,
  funcionario_id uuid REFERENCES public.funcionarios(id) ON DELETE SET NULL,
  data_referencia date,
  created_at timestamptz DEFAULT now()
);

-- =============================================
-- Row Level Security (RLS)
-- =============================================
ALTER TABLE public.modelos_turno    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escala_turnos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trocas_turno     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historico_escala ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas caso o script seja reexecutado
DROP POLICY IF EXISTS "Leitura pública - modelos_turno" ON public.modelos_turno;
DROP POLICY IF EXISTS "Leitura pública - escala_turnos" ON public.escala_turnos;
DROP POLICY IF EXISTS "Leitura pública - trocas_turno" ON public.trocas_turno;
DROP POLICY IF EXISTS "Leitura pública - historico_escala" ON public.historico_escala;
DROP POLICY IF EXISTS "Colaborador solicita troca" ON public.trocas_turno;
DROP POLICY IF EXISTS "Registro de auditoria" ON public.historico_escala;
DROP POLICY IF EXISTS "Colaborador registra justificativa em turno" ON public.escala_turnos;
DROP POLICY IF EXISTS "Admin - modelos_turno" ON public.modelos_turno;
DROP POLICY IF EXISTS "Admin - escala_turnos" ON public.escala_turnos;
DROP POLICY IF EXISTS "Admin - trocas_turno" ON public.trocas_turno;
DROP POLICY IF EXISTS "Admin - historico_escala" ON public.historico_escala;

-- Leitura pública para que o dashboard exiba a grade e trocas
CREATE POLICY "Leitura pública - modelos_turno"    ON public.modelos_turno    FOR SELECT USING (true);
CREATE POLICY "Leitura pública - escala_turnos"    ON public.escala_turnos    FOR SELECT USING (true);
CREATE POLICY "Leitura pública - trocas_turno"     ON public.trocas_turno     FOR SELECT USING (true);
CREATE POLICY "Leitura pública - historico_escala" ON public.historico_escala FOR SELECT USING (true);

-- Colaboradores podem solicitar trocas pendentes e registrar histórico/justificativas pelo dashboard
CREATE POLICY "Colaborador solicita troca" ON public.trocas_turno
  FOR INSERT WITH CHECK (status = 'pending');

CREATE POLICY "Registro de auditoria" ON public.historico_escala
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Colaborador registra justificativa em turno" ON public.escala_turnos
  FOR UPDATE USING (true)
  WITH CHECK (true);

-- Escrita completa para usuários autenticados (Admin/Gestor)
CREATE POLICY "Admin - modelos_turno" ON public.modelos_turno
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Admin - escala_turnos" ON public.escala_turnos
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Admin - trocas_turno" ON public.trocas_turno
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Admin - historico_escala" ON public.historico_escala
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

-- =============================================
-- Índices
-- =============================================
CREATE INDEX IF NOT EXISTS idx_escala_turnos_data        ON public.escala_turnos(data);
CREATE INDEX IF NOT EXISTS idx_escala_turnos_funcionario ON public.escala_turnos(funcionario_id, data);
CREATE INDEX IF NOT EXISTS idx_trocas_turno_status       ON public.trocas_turno(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_historico_escala_created  ON public.historico_escala(created_at DESC);

COMMIT;
