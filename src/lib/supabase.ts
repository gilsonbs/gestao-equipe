import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Funcionario = {
  id: string;
  nome: string;
  cargo: string | null;
  contato?: string | null;
  data_nascimento: string | null;
  carga_horaria_semanal?: number;
  limite_diario?: number;
  dias_indisponiveis?: number[];
  observacoes_restricao?: string | null;
  ativo: boolean;
  created_at: string;
};

export type ModeloTurno = {
  id: string;
  nome: string;
  hora_inicio: string;
  hora_fim: string;
  cor: string;
  eh_folga: boolean;
  ativo: boolean;
  created_at?: string;
};

export type StatusTurno = 'scheduled' | 'confirmed' | 'completed' | 'swapped' | 'absent';

export type EscalaTurno = {
  id: string;
  funcionario_id: string;
  modelo_turno_id: string | null;
  data: string;
  observacao: string | null;
  status: StatusTurno;
  publicado: boolean;
  created_at?: string;
  modelos_turno?: ModeloTurno | null;
  funcionarios?: { nome: string; cargo: string | null };
};

export type StatusTroca = 'pending' | 'approved' | 'rejected';

export type TrocaTurno = {
  id: string;
  turno_origem_id: string;
  solicitante_id: string;
  alvo_funcionario_id: string;
  turno_alvo_id: string | null;
  motivo: string | null;
  status: StatusTroca;
  respondido_em: string | null;
  created_at: string;
  solicitante?: { nome: string; cargo: string | null };
  alvo?: { nome: string; cargo: string | null };
  turno_origem?: EscalaTurno;
  turno_alvo?: EscalaTurno | null;
};

export type HistoricoEscala = {
  id: string;
  acao: string;
  descricao: string;
  funcionario_id: string | null;
  data_referencia: string | null;
  created_at: string;
  funcionarios?: { nome: string } | null;
};

export type Meta = {
  id: string;
  funcionario_id: string;
  mes: number;
  ano: number;
  valor_meta: number;
  funcionarios?: { nome: string; cargo: string | null };
};

export type VendaFuncionario = {
  id: string;
  funcionario_id: string;
  mes: number;
  ano: number;
  valor: number;
  funcionarios?: { nome: string };
};

/** Linha da view `desempenho_mensal` (meta + realizado combinados). */
export type DesempenhoMensal = {
  funcionario_id: string;
  /** NULL quando o funcionário tem venda mas nenhuma meta no período. */
  meta_id: string | null;
  /** NULL quando o funcionário tem meta mas nenhuma venda no período. */
  venda_id: string | null;
  nome: string;
  cargo: string | null;
  mes: number;
  ano: number;
  valor_meta: number;
  valor_realizado: number;
  /** NULL quando não há meta definida para o período. */
  percentual: number | null;
};

export type MetaLoja = {
  id: string;
  mes: number;
  ano: number;
  valor_meta: number;
};

/** Linha da view `desempenho_loja` (meta da loja + total vendido no mês). */
export type DesempenhoLoja = {
  mes: number;
  ano: number;
  valor_meta: number;
  /** Soma de todos os lançamentos de vendas_loja no período. */
  valor_realizado: number;
  /** NULL quando não há meta definida para o mês. */
  percentual: number | null;
};

export type VendaLoja = {
  id: string;
  mes: number;
  ano: number;
  valor_total: number;
};

export type Folga = {
  id: string;
  funcionario_id: string;
  data_inicio: string;
  data_fim: string;
  tipo: 'folga' | 'ferias' | 'horario';
  observacao?: string | null;
  funcionarios?: { nome: string };
};

export type Aviso = {
  id: string;
  titulo: string;
  mensagem: string;
  tipo: 'info' | 'atencao' | 'urgente';
  fixado: boolean;
  /** NULL = sem prazo, o aviso fica no ar até ser removido. */
  data_expiracao: string | null;
  created_at: string;
};

/** Linha da view `avisos_com_status`. */
export type AvisoComStatus = Aviso & {
  /** false quando data_expiracao já passou. */
  ativo: boolean;
};

export type ProdutoTop = {
  id: string;
  nome: string;
  substancia: string | null;
  categoria: string | null;
  quantidade: number | null;
  mes: number | null;
  ano: number | null;
};


