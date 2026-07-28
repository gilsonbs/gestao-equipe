import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Funcionario = {
  id: string;
  nome: string;
  cargo: string | null;
  data_nascimento: string | null;
  ativo: boolean;
  created_at: string;
};

export type Meta = {
  id: string;
  funcionario_id: string;
  mes: number;
  ano: number;
  valor_meta: number;
  valor_realizado: number;
  funcionarios?: { nome: string; cargo: string | null };
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
  tipo: 'folga' | 'ferias';
  funcionarios?: { nome: string };
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

