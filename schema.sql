-- =============================================
-- Schema: Gestão de Equipe
-- Execute no Supabase SQL Editor em um banco NOVO.
--
-- ATENÇÃO: se você já executou uma versão anterior deste schema, NÃO
-- rode este arquivo — ele não migra nada, e recriar as tabelas apagaria
-- os dados já lançados. Use migrations/001-separa-metas-vendas.sql.
--
-- Em dúvida sobre a versão do seu banco? Rode migrations/diagnostico.sql.
-- =============================================

-- Funcionários
CREATE TABLE IF NOT EXISTS funcionarios (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  cargo text,
  contato text,
  data_nascimento date,
  carga_horaria_semanal integer NOT NULL DEFAULT 44,
  limite_diario integer NOT NULL DEFAULT 8,
  dias_indisponiveis integer[] NOT NULL DEFAULT '{}',
  observacoes_restricao text,
  ativo boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Metas mensais por funcionário (apenas o valor pactuado)
CREATE TABLE IF NOT EXISTS metas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor_meta numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(funcionario_id, mes, ano)
);

-- Vendas realizadas por funcionário (independente de haver meta)
CREATE TABLE IF NOT EXISTS vendas_funcionario (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor numeric(12,2) NOT NULL DEFAULT 0,
  num_atendimentos integer,
  created_at timestamptz DEFAULT now(),
  UNIQUE(funcionario_id, mes, ano)
);

-- Meta mensal de faturamento da loja
CREATE TABLE IF NOT EXISTS metas_loja (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor_meta numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(mes, ano)
);

-- Vendas totais da loja
CREATE TABLE IF NOT EXISTS vendas_loja (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  valor_total numeric(12,2) NOT NULL DEFAULT 0,
  num_atendimentos integer,
  data_venda date,
  created_at timestamptz DEFAULT now()
);

-- Folgas e Férias
CREATE TABLE IF NOT EXISTS folgas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  data_inicio date NOT NULL,
  data_fim date NOT NULL,
  tipo text NOT NULL CHECK (tipo IN ('folga', 'ferias', 'horario')),
  observacao text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT data_valida CHECK (data_fim >= data_inicio)
);

-- Top Produtos
CREATE TABLE IF NOT EXISTS produtos_top (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  codigo_produto bigint,
  nome text NOT NULL,
  substancia text,
  categoria text,
  laboratorio text,
  preco_custo numeric(10,2),
  preco_venda numeric(10,2),
  quantidade integer,
  mes integer CHECK (mes BETWEEN 1 AND 12),
  ano integer CHECK (ano >= 2020),
  created_at timestamptz DEFAULT now()
);

-- Escalas de trabalho praticadas na loja
CREATE TABLE IF NOT EXISTS escalas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  descricao text,
  dias_semana integer[] NOT NULL DEFAULT '{}',
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Quantidade de entregas a domicílio por mês
CREATE TABLE IF NOT EXISTS entregas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ano integer NOT NULL CHECK (ano >= 2020),
  quantidade integer NOT NULL DEFAULT 0 CHECK (quantidade >= 0),
  created_at timestamptz DEFAULT now(),
  UNIQUE(mes, ano)
);

-- Avisos para a equipe, exibidos no dashboard
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

-- =============================================
-- View de desempenho: junta meta + realizado
--
-- Um funcionário pode ter meta sem venda, venda sem meta, ou ambos.
-- Quando não há meta definida, o percentual é NULL (e não 0), para
-- que esses registros não distorçam a média de atingimento.
-- =============================================
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
  v.num_atendimentos,
  CASE
    WHEN COALESCE(v.num_atendimentos, 0) > 0
      THEN ROUND(COALESCE(v.valor, 0) / v.num_atendimentos, 2)::numeric(12,2)
    ELSE NULL
  END                                               AS ticket_medio,
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

-- =============================================
-- View de desempenho da loja: meta do mês contra o total vendido.
--
-- vendas_loja não tem UNIQUE(mes, ano) — pode haver mais de um
-- lançamento no mesmo mês —, então o realizado é a SOMA do período.
-- =============================================
CREATE OR REPLACE VIEW desempenho_loja
WITH (security_invoker = on) AS
WITH vendas AS (
  SELECT mes, ano,
    SUM(valor_total)::numeric(12,2)  AS total,
    SUM(num_atendimentos)            AS total_atendimentos
  FROM vendas_loja
  GROUP BY mes, ano
)
SELECT
  COALESCE(m.mes, v.mes)                   AS mes,
  COALESCE(m.ano, v.ano)                   AS ano,
  COALESCE(m.valor_meta, 0)::numeric(12,2) AS valor_meta,
  COALESCE(v.total, 0)::numeric(12,2)      AS valor_realizado,
  v.total_atendimentos,
  CASE
    WHEN COALESCE(v.total_atendimentos, 0) > 0
      THEN ROUND(COALESCE(v.total, 0) / v.total_atendimentos, 2)::numeric(12,2)
    ELSE NULL
  END                                      AS ticket_medio,
  CASE
    WHEN COALESCE(m.valor_meta, 0) > 0
      THEN ROUND((COALESCE(v.total, 0) / m.valor_meta) * 100)
    ELSE NULL
  END                                      AS percentual
FROM metas_loja m
FULL OUTER JOIN vendas v
  ON m.mes = v.mes AND m.ano = v.ano;

GRANT SELECT ON desempenho_loja TO anon, authenticated;

-- =============================================
-- View de avisos: marca quais ainda estão vigentes, para que o
-- dashboard e o admin usem exatamente a mesma regra de expiração.
-- =============================================
CREATE OR REPLACE VIEW avisos_com_status
WITH (security_invoker = on) AS
SELECT
  a.*,
  (a.data_expiracao IS NULL OR a.data_expiracao >= CURRENT_DATE) AS ativo
FROM avisos a;

GRANT SELECT ON avisos_com_status TO anon, authenticated;

-- =============================================
-- Row Level Security (RLS)
-- =============================================

ALTER TABLE entregas            ENABLE ROW LEVEL SECURITY;
ALTER TABLE escalas             ENABLE ROW LEVEL SECURITY;
ALTER TABLE funcionarios        ENABLE ROW LEVEL SECURITY;
ALTER TABLE metas               ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendas_funcionario  ENABLE ROW LEVEL SECURITY;
ALTER TABLE metas_loja          ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendas_loja         ENABLE ROW LEVEL SECURITY;
ALTER TABLE folgas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE produtos_top        ENABLE ROW LEVEL SECURITY;
ALTER TABLE avisos              ENABLE ROW LEVEL SECURITY;

-- Leitura pública (dashboard sem login)
CREATE POLICY "Leitura pública - entregas"           ON entregas           FOR SELECT USING (true);
CREATE POLICY "Leitura pública - escalas"            ON escalas            FOR SELECT USING (true);
CREATE POLICY "Leitura pública - funcionarios"       ON funcionarios       FOR SELECT USING (true);
CREATE POLICY "Leitura pública - metas"              ON metas              FOR SELECT USING (true);
CREATE POLICY "Leitura pública - vendas_funcionario" ON vendas_funcionario FOR SELECT USING (true);
CREATE POLICY "Leitura pública - metas_loja"         ON metas_loja         FOR SELECT USING (true);
CREATE POLICY "Leitura pública - vendas_loja"        ON vendas_loja        FOR SELECT USING (true);
CREATE POLICY "Leitura pública - folgas"             ON folgas             FOR SELECT USING (true);
CREATE POLICY "Leitura pública - produtos_top"       ON produtos_top       FOR SELECT USING (true);
CREATE POLICY "Leitura pública - avisos"             ON avisos             FOR SELECT USING (true);

-- Escrita apenas para usuários autenticados (admin).
-- O (select ...) faz o Postgres avaliar a função uma vez por query
-- em vez de uma vez por linha.
CREATE POLICY "Admin - entregas" ON entregas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - escalas" ON escalas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - funcionarios" ON funcionarios
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - metas" ON metas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - vendas_funcionario" ON vendas_funcionario
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - metas_loja" ON metas_loja
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - vendas_loja" ON vendas_loja
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - folgas" ON folgas
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - produtos_top" ON produtos_top
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Admin - avisos" ON avisos
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

-- =============================================
-- Índices para melhorar performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_entregas_mes_ano            ON entregas(mes, ano);
CREATE INDEX IF NOT EXISTS idx_escalas_ativo              ON escalas(ativo);
CREATE INDEX IF NOT EXISTS idx_metas_mes_ano              ON metas(mes, ano);
CREATE INDEX IF NOT EXISTS idx_vendas_funcionario_mes_ano ON vendas_funcionario(mes, ano);
CREATE INDEX IF NOT EXISTS idx_metas_loja_mes_ano         ON metas_loja(mes, ano);
CREATE INDEX IF NOT EXISTS idx_vendas_loja_mes_ano        ON vendas_loja(mes, ano);
CREATE INDEX IF NOT EXISTS idx_folgas_data_inicio         ON folgas(data_inicio);
CREATE INDEX IF NOT EXISTS idx_produtos_top_nome          ON produtos_top(nome);
CREATE INDEX IF NOT EXISTS idx_produtos_top_substancia    ON produtos_top(substancia);
CREATE INDEX IF NOT EXISTS idx_funcionarios_ativo         ON funcionarios(ativo);
CREATE INDEX IF NOT EXISTS idx_avisos_ordem                ON avisos(fixado DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_avisos_expiracao            ON avisos(data_expiracao);

-- =============================================
-- ShiftHub: Gestão de Turnos, Matriz Semanal, Trocas e Auditoria
-- =============================================

CREATE TABLE IF NOT EXISTS modelos_turno (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome text NOT NULL,
  hora_inicio time NOT NULL DEFAULT '07:00',
  hora_fim time NOT NULL DEFAULT '15:00',
  cor text NOT NULL DEFAULT '#0284c7',
  eh_folga boolean NOT NULL DEFAULT false,
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

INSERT INTO modelos_turno (nome, hora_inicio, hora_fim, cor, eh_folga)
SELECT * FROM (VALUES
  ('Manhã',     '07:00'::time, '15:00'::time, '#0284c7', false),
  ('Tarde',     '14:00'::time, '22:00'::time, '#d97706', false),
  ('Noturno',   '22:00'::time, '06:00'::time, '#4f46e5', false),
  ('Comercial', '08:00'::time, '17:00'::time, '#059669', false),
  ('Folga',     '00:00'::time, '00:00'::time, '#64748b', true)
) AS v(nome, hora_inicio, hora_fim, cor, eh_folga)
WHERE NOT EXISTS (SELECT 1 FROM modelos_turno LIMIT 1);

CREATE TABLE IF NOT EXISTS escala_turnos (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  modelo_turno_id uuid REFERENCES modelos_turno(id) ON DELETE SET NULL,
  data date NOT NULL,
  observacao text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'swapped', 'absent')),
  publicado boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE (funcionario_id, data)
);

CREATE TABLE IF NOT EXISTS trocas_turno (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  turno_origem_id uuid NOT NULL REFERENCES escala_turnos(id) ON DELETE CASCADE,
  solicitante_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  alvo_funcionario_id uuid NOT NULL REFERENCES funcionarios(id) ON DELETE CASCADE,
  turno_alvo_id uuid REFERENCES escala_turnos(id) ON DELETE SET NULL,
  motivo text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  respondido_em timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS historico_escala (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  acao text NOT NULL,
  descricao text NOT NULL,
  funcionario_id uuid REFERENCES funcionarios(id) ON DELETE SET NULL,
  data_referencia date,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE modelos_turno    ENABLE ROW LEVEL SECURITY;
ALTER TABLE escala_turnos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE trocas_turno     ENABLE ROW LEVEL SECURITY;
ALTER TABLE historico_escala ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leitura pública - modelos_turno"    ON modelos_turno    FOR SELECT USING (true);
CREATE POLICY "Leitura pública - escala_turnos"    ON escala_turnos    FOR SELECT USING (true);
CREATE POLICY "Leitura pública - trocas_turno"     ON trocas_turno     FOR SELECT USING (true);
CREATE POLICY "Leitura pública - historico_escala" ON historico_escala FOR SELECT USING (true);

CREATE POLICY "Colaborador solicita troca" ON trocas_turno
  FOR INSERT WITH CHECK (status = 'pending');

CREATE POLICY "Registro de auditoria" ON historico_escala
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Colaborador registra justificativa em turno" ON escala_turnos
  FOR UPDATE USING (true)
  WITH CHECK (true);

CREATE POLICY "Admin - modelos_turno" ON modelos_turno
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Admin - escala_turnos" ON escala_turnos
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Admin - trocas_turno" ON trocas_turno
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Admin - historico_escala" ON historico_escala
  FOR ALL USING ((select auth.role()) = 'authenticated')
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_escala_turnos_data        ON escala_turnos(data);
CREATE INDEX IF NOT EXISTS idx_escala_turnos_funcionario ON escala_turnos(funcionario_id, data);
CREATE INDEX IF NOT EXISTS idx_trocas_turno_status       ON trocas_turno(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_historico_escala_created  ON historico_escala(created_at DESC);

