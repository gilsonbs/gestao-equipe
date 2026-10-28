import type { EscalaTurno, Funcionario, ModeloTurno, StatusTurno } from './supabase';

export const DIAS_SEMANA_CURTO = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
export const DIAS_SEMANA_LONGO = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];

export const MESES_NOME = [
  '',
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

export const MESES_CURTO = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

export const STATUS_TURNO_META: Record<
  StatusTurno,
  { label: string; shortLabel: string; badgeClass: string; dotColor: string; icon: string }
> = {
  scheduled: {
    label: 'Agendado',
    shortLabel: 'Agendado',
    badgeClass: 'badge-info',
    dotColor: '#0284c7',
    icon: '🗓️',
  },
  confirmed: {
    label: 'Confirmado',
    shortLabel: 'Confirmado',
    badgeClass: 'badge-success',
    dotColor: '#059669',
    icon: '✓',
  },
  completed: {
    label: 'Concluído',
    shortLabel: 'Concluído',
    badgeClass: 'badge-success',
    dotColor: '#059669',
    icon: '✅',
  },
  swapped: {
    label: 'Trocado',
    shortLabel: 'Trocado',
    badgeClass: 'badge-warning',
    dotColor: '#d97706',
    icon: '🔄',
  },
  absent: {
    label: 'Falta / Atestado',
    shortLabel: 'Ausente',
    badgeClass: 'badge-danger',
    dotColor: '#e11d48',
    icon: '⚠️',
  },
};

export type WeekDayInfo = {
  iso: string;
  date: Date;
  dayNum: number;
  monthNum: number;
  yearNum: number;
  dow: number; // 0 = Dom .. 6 = Sáb
  dowShort: string;
  dowFull: string;
  isToday: boolean;
};

export function toISODate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Retorna a segunda-feira da semana da data informada. */
export function getMonday(d: Date = new Date()): Date {
  const copy = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const day = copy.getDay(); // 0 (Dom) a 6 (Sáb)
  const diff = day === 0 ? -6 : 1 - day;
  copy.setDate(copy.getDate() + diff);
  return copy;
}

/** Gera os 7 dias da semana (Segunda a Domingo) a partir da segunda-feira base. */
export function getWeekDays(monday: Date): WeekDayInfo[] {
  const hojeIso = toISODate(new Date());
  const days: WeekDayInfo[] = [];
  for (let i = 0; i < 7; i++) {
    const dt = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i);
    const iso = toISODate(dt);
    const dow = dt.getDay();
    days.push({
      iso,
      date: dt,
      dayNum: dt.getDate(),
      monthNum: dt.getMonth() + 1,
      yearNum: dt.getFullYear(),
      dow,
      dowShort: DIAS_SEMANA_CURTO[dow],
      dowFull: DIAS_SEMANA_LONGO[dow],
      isToday: iso === hojeIso,
    });
  }
  return days;
}

/** Formata o cabeçalho do seletor de semana (ex: "16 a 22 de Outubro"). */
export function formatWeekRangeLabel(days: WeekDayInfo[]): string {
  if (!days.length) return '';
  const first = days[0];
  const last = days[days.length - 1];
  const d1 = String(first.dayNum).padStart(2, '0');
  const d2 = String(last.dayNum).padStart(2, '0');
  if (first.monthNum === last.monthNum) {
    return `${d1} a ${d2} de ${MESES_NOME[first.monthNum]}`;
  }
  return `${d1} de ${MESES_CURTO[first.monthNum]} a ${d2} de ${MESES_CURTO[last.monthNum]}`;
}

/** Converte "07:00" ou "07:30:00" para horas decimais (7.0, 7.5). */
export function parseTimeHours(timeStr: string | null | undefined): number {
  if (!timeStr) return 0;
  const parts = timeStr.split(':').map(Number);
  const h = parts[0] || 0;
  const m = parts[1] || 0;
  return h + m / 60;
}

/** Formata "07:00:00" -> "07h" ou "07:30:00" -> "07h30". */
export function formatTimeShort(timeStr: string | null | undefined): string {
  if (!timeStr) return '';
  const parts = timeStr.split(':');
  const hh = (parts[0] ?? '00').padStart(2, '0');
  const mm = parts[1] ?? '00';
  return mm === '00' ? `${hh}h` : `${hh}h${mm}`;
}

/** Calcula a duração em horas de um modelo de turno (suporta virada de noite ex: 22h-06h = 8h). */
export function calcShiftHours(modelo?: ModeloTurno | null): number {
  if (!modelo || modelo.eh_folga) return 0;
  const ini = parseTimeHours(modelo.hora_inicio);
  const fim = parseTimeHours(modelo.hora_fim);
  if (ini === 0 && fim === 0) return 0;
  let diff = fim - ini;
  if (diff <= 0) diff += 24;
  return Math.round(diff * 100) / 100;
}

export type InterjornadaAlert = {
  funcionarioId: string;
  funcionarioNome: string;
  dataAnterior: string;
  dataAtual: string;
  turnoAnteriorNome: string;
  turnoAtualNome: string;
  descansoHoras: number;
};

export type CargaHorariaAlert = {
  funcionarioId: string;
  funcionarioNome: string;
  horasAlocadas: number;
  limiteSemanal: number;
  excesso: number;
};

export type RestricaoAlert = {
  funcionarioId: string;
  funcionarioNome: string;
  data: string;
  dowNome: string;
  turnoNome: string;
};

export type SubdimensionamentoAlert = {
  data: string;
  dowNome: string;
  motivo: string;
  nivel: 'danger' | 'warning';
};

export type CellValidationFlag = {
  interjornadaHoras?: number;
  turnoAnteriorNome?: string;
  restricaoDia?: boolean;
  estouroDiario?: boolean;
};

export type ValidationResult = {
  interjornadaAlerts: InterjornadaAlert[];
  cargaHorariaAlerts: CargaHorariaAlert[];
  restricaoAlerts: RestricaoAlert[];
  subdimensionamentoAlerts: SubdimensionamentoAlert[];
  horasPorFuncionario: Map<string, number>;
  cellFlags: Map<string, CellValidationFlag>;
  totalAlerts: number;
};

/**
 * Executa todas as validações automáticas da grade semanal:
 * 1. Descanso mínimo interjornada de 11h entre turnos consecutivos
 * 2. Estouro de carga horária semanal contratual e limite diário
 * 3. Alocação em dia de indisponibilidade/restrição individual
 * 4. Subdimensionamento de equipe (ex: dia sem Farmacêutico/RT ou sem Caixa/Balcão)
 */
export function validateWeekSchedule(
  funcionarios: Funcionario[],
  turnos: EscalaTurno[],
  modelosMap: Map<string, ModeloTurno>,
  weekDays: WeekDayInfo[]
): ValidationResult {
  const interjornadaAlerts: InterjornadaAlert[] = [];
  const cargaHorariaAlerts: CargaHorariaAlert[] = [];
  const restricaoAlerts: RestricaoAlert[] = [];
  const subdimensionamentoAlerts: SubdimensionamentoAlert[] = [];
  const horasPorFuncionario = new Map<string, number>();
  const cellFlags = new Map<string, CellValidationFlag>();

  const weekIsoSet = new Set(weekDays.map(d => d.iso));

  // Indexar turnos por funcionario_id -> data -> turno
  const turnosPorFunc = new Map<string, Map<string, EscalaTurno>>();
  for (const t of turnos) {
    if (!turnosPorFunc.has(t.funcionario_id)) {
      turnosPorFunc.set(t.funcionario_id, new Map());
    }
    turnosPorFunc.get(t.funcionario_id)!.set(t.data, t);
  }

  // 1, 2 e 3: Validações por colaborador
  for (const func of funcionarios) {
    const mapaDatas = turnosPorFunc.get(func.id) ?? new Map<string, EscalaTurno>();
    let somaSemana = 0;
    const indisponiveis = new Set<number>(func.dias_indisponiveis ?? []);
    const limiteDiario = func.limite_diario ?? 8;
    const limiteSemanal = func.carga_horaria_semanal ?? 44;

    // Ordenar todas as datas disponíveis para checar dias consecutivos (inclusive domingo anterior se vier na query)
    const datasOrdenadas = Array.from(mapaDatas.keys()).sort();

    for (let i = 0; i < datasOrdenadas.length; i++) {
      const iso = datasOrdenadas[i];
      const turno = mapaDatas.get(iso)!;
      const modelo = turno.modelos_turno ?? (turno.modelo_turno_id ? modelosMap.get(turno.modelo_turno_id) : null);
      const ehTrabalho = Boolean(modelo && !modelo.eh_folga && turno.status !== 'absent');
      const horas = ehTrabalho ? calcShiftHours(modelo) : 0;
      const key = `${func.id}_${iso}`;

      if (weekIsoSet.has(iso)) {
        somaSemana += horas;

        // Checar limite diário
        if (horas > limiteDiario) {
          const cur = cellFlags.get(key) ?? {};
          cur.estouroDiario = true;
          cellFlags.set(key, cur);
        }

        // Checar restrição individual de dia da semana
        if (ehTrabalho) {
          const [y, m, d] = iso.split('-').map(Number);
          const dow = new Date(y, m - 1, d).getDay();
          if (indisponiveis.has(dow)) {
            restricaoAlerts.push({
              funcionarioId: func.id,
              funcionarioNome: func.nome,
              data: iso,
              dowNome: DIAS_SEMANA_CURTO[dow],
              turnoNome: modelo!.nome,
            });
            const cur = cellFlags.get(key) ?? {};
            cur.restricaoDia = true;
            cellFlags.set(key, cur);
          }
        }
      }

      // Checar interjornada (< 11h) com o dia imediatamente anterior
      if (ehTrabalho && i > 0) {
        const prevIso = datasOrdenadas[i - 1];
        const [y1, m1, d1] = prevIso.split('-').map(Number);
        const [y2, m2, d2] = iso.split('-').map(Number);
        const diffDays = Math.round(
          (new Date(y2, m2 - 1, d2).getTime() - new Date(y1, m1 - 1, d1).getTime()) / 86400000
        );

        if (diffDays === 1 && weekIsoSet.has(iso)) {
          const prevTurno = mapaDatas.get(prevIso)!;
          const prevModelo =
            prevTurno.modelos_turno ?? (prevTurno.modelo_turno_id ? modelosMap.get(prevTurno.modelo_turno_id) : null);
          const prevEhTrabalho = Boolean(prevModelo && !prevModelo.eh_folga && prevTurno.status !== 'absent');

          if (prevEhTrabalho && prevModelo && modelo) {
            const ini1 = parseTimeHours(prevModelo.hora_inicio);
            const fim1 = parseTimeHours(prevModelo.hora_fim);
            const ini2 = parseTimeHours(modelo.hora_inicio);

            // Se fim1 <= ini1, o turno anterior virou a noite e terminou no dia atual às `fim1` horas
            const terminoRelativoMeiaNoite = fim1 <= ini1 ? fim1 : fim1 - 24;
            const descanso = Math.round((ini2 - terminoRelativoMeiaNoite) * 10) / 10;

            if (descanso < 11) {
              interjornadaAlerts.push({
                funcionarioId: func.id,
                funcionarioNome: func.nome,
                dataAnterior: prevIso,
                dataAtual: iso,
                turnoAnteriorNome: `${prevModelo.nome} (${formatTimeShort(prevModelo.hora_inicio)}-${formatTimeShort(prevModelo.hora_fim)})`,
                turnoAtualNome: `${modelo.nome} (${formatTimeShort(modelo.hora_inicio)}-${formatTimeShort(modelo.hora_fim)})`,
                descansoHoras: Math.max(0, descanso),
              });
              const cur = cellFlags.get(key) ?? {};
              cur.interjornadaHoras = Math.max(0, descanso);
              cur.turnoAnteriorNome = prevModelo.nome;
              cellFlags.set(key, cur);
            }
          }
        }
      }
    }

    somaSemana = Math.round(somaSemana * 10) / 10;
    horasPorFuncionario.set(func.id, somaSemana);

    if (somaSemana > limiteSemanal) {
      cargaHorariaAlerts.push({
        funcionarioId: func.id,
        funcionarioNome: func.nome,
        horasAlocadas: somaSemana,
        limiteSemanal,
        excesso: Math.round((somaSemana - limiteSemanal) * 10) / 10,
      });
    }
  }

  // 4. Validação de subdimensionamento por dia da semana
  const algumsTurnosNaSemana = turnos.some(t => weekIsoSet.has(t.data));
  if (algumsTurnosNaSemana && funcionarios.length > 0) {
    const normalizeRole = (cargo: string | null | undefined) =>
      (cargo ?? '')
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '');

    const temFarmaceuticoNaEquipe = funcionarios.some(f => {
      const c = normalizeRole(f.cargo);
      return c.includes('farmaceutic') || c.includes('rt') || c.includes('responsavel');
    });
    const temCaixaOuBalcaoNaEquipe = funcionarios.some(f => {
      const c = normalizeRole(f.cargo);
      return c.includes('caixa') || c.includes('balcao') || c.includes('atendente');
    });

    const funcMap = new Map(funcionarios.map(f => [f.id, f]));

    for (const day of weekDays) {
      const turnosDia = turnos.filter(t => t.data === day.iso);
      if (turnosDia.length === 0) continue; // Dia ainda não escalado

      const trabalhandoNoDia = turnosDia.filter(t => {
        const mod = t.modelos_turno ?? (t.modelo_turno_id ? modelosMap.get(t.modelo_turno_id) : null);
        return mod && !mod.eh_folga && t.status !== 'absent';
      });

      if (trabalhandoNoDia.length === 0) {
        subdimensionamentoAlerts.push({
          data: day.iso,
          dowNome: `${day.dowShort} (${String(day.dayNum).padStart(2, '0')}/${String(day.monthNum).padStart(2, '0')})`,
          motivo: 'Nenhum colaborador escalado em turno de trabalho (todos em folga/ausência).',
          nivel: 'danger',
        });
        continue;
      }

      if (temFarmaceuticoNaEquipe) {
        const temFarmNoDia = trabalhandoNoDia.some(t => {
          const f = funcMap.get(t.funcionario_id);
          const c = normalizeRole(f?.cargo);
          return c.includes('farmaceutic') || c.includes('rt') || c.includes('responsavel');
        });
        if (!temFarmNoDia) {
          subdimensionamentoAlerts.push({
            data: day.iso,
            dowNome: `${day.dowShort} (${String(day.dayNum).padStart(2, '0')}/${String(day.monthNum).padStart(2, '0')})`,
            motivo: 'Turno sem Farmacêutico / Responsável Técnico alocado.',
            nivel: 'danger',
          });
        }
      }

      if (temCaixaOuBalcaoNaEquipe) {
        const temCaixaNoDia = trabalhandoNoDia.some(t => {
          const f = funcMap.get(t.funcionario_id);
          const c = normalizeRole(f?.cargo);
          return c.includes('caixa') || c.includes('balcao') || c.includes('atendente');
        });
        if (!temCaixaNoDia) {
          subdimensionamentoAlerts.push({
            data: day.iso,
            dowNome: `${day.dowShort} (${String(day.dayNum).padStart(2, '0')}/${String(day.monthNum).padStart(2, '0')})`,
            motivo: 'Sem operador de Caixa / Balcão alocado no dia.',
            nivel: 'warning',
          });
        }
      }
    }
  }

  return {
    interjornadaAlerts,
    cargaHorariaAlerts,
    restricaoAlerts,
    subdimensionamentoAlerts,
    horasPorFuncionario,
    cellFlags,
    totalAlerts:
      interjornadaAlerts.length +
      cargaHorariaAlerts.length +
      restricaoAlerts.length +
      subdimensionamentoAlerts.length,
  };
}
