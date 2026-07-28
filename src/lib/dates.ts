/**
 * Retorna o intervalo completo de um mês no formato ISO (YYYY-MM-DD).
 *
 * O último dia é calculado, e não fixado em 31: datas como 2025-04-31
 * não existem e são rejeitadas pelo Postgres no cast para `date`,
 * fazendo a query falhar silenciosamente.
 */
export function intervaloDoMes(mes: number, ano: number) {
  const ultimoDia = new Date(ano, mes, 0).getDate();
  const mm = String(mes).padStart(2, '0');
  return {
    inicio: `${ano}-${mm}-01`,
    fim: `${ano}-${mm}-${String(ultimoDia).padStart(2, '0')}`,
  };
}

/** Formata uma data ISO (YYYY-MM-DD) como DD/MM/AAAA. */
export function formatarData(iso: string) {
  const [ano, mes, dia] = iso.split('-');
  return `${dia}/${mes}/${ano}`;
}
