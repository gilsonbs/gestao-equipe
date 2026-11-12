-- Execute após a migration 011, no SQL Editor do Supabase.
-- Preserva registros manuais. A exportação é atômica e pode ser repetida.
BEGIN;

ALTER TABLE public.folgas
  ADD COLUMN IF NOT EXISTS escala_turno_id uuid
    REFERENCES public.escala_turnos(id) ON DELETE CASCADE;
CREATE UNIQUE INDEX IF NOT EXISTS folgas_escala_turno_unique
  ON public.folgas(escala_turno_id);

CREATE OR REPLACE FUNCTION public.exportar_escala_calendario(inicio date, fim date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  exportados integer;
  conflitos integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Faça login para exportar a escala.';
  END IF;
  IF inicio IS NULL OR fim IS NULL OR fim <> inicio + 6 THEN
    RAISE EXCEPTION 'Selecione um período de sete dias.';
  END IF;

  -- Serializa exportações para evitar duplicação em cliques simultâneos.
  PERFORM pg_advisory_xact_lock(721012);

  -- Remove apenas a exportação anterior desta semana. Registros manuais
  -- e férias nunca são alterados. Em caso de erro, a transação é revertida.
  DELETE FROM public.folgas f
  WHERE f.escala_turno_id IS NOT NULL
    AND (f.data_inicio BETWEEN inicio AND fim OR EXISTS (
      SELECT 1 FROM public.escala_turnos e
      WHERE e.id = f.escala_turno_id AND e.data BETWEEN inicio AND fim
    ));

  SELECT count(*) INTO conflitos
  FROM public.escala_turnos e
  JOIN public.modelos_turno m ON m.id = e.modelo_turno_id
  JOIN public.funcionarios p ON p.id = e.funcionario_id AND p.ativo
  WHERE e.data BETWEEN inicio AND fim AND e.publicado AND e.status <> 'absent'
    AND EXISTS (
      SELECT 1 FROM public.folgas f
      WHERE f.funcionario_id = e.funcionario_id
        AND f.escala_turno_id IS DISTINCT FROM e.id
        AND e.data BETWEEN f.data_inicio AND f.data_fim
    );

  INSERT INTO public.folgas
    (funcionario_id, data_inicio, data_fim, tipo, observacao, escala_turno_id)
  SELECT e.funcionario_id, e.data, e.data,
    CASE WHEN m.eh_folga THEN 'folga' ELSE 'horario' END,
    concat_ws(' — ',
      CASE WHEN m.eh_folga THEN m.nome
        ELSE m.nome || ': ' || to_char(m.hora_inicio, 'HH24:MI') || ' às ' ||
          to_char(m.hora_fim, 'HH24:MI') ||
          CASE WHEN m.hora_fim <= m.hora_inicio THEN ' (dia seguinte)' ELSE '' END
      END,
      nullif(btrim(e.observacao), ''), 'ShiftHub'),
    e.id
  FROM public.escala_turnos e
  JOIN public.modelos_turno m ON m.id = e.modelo_turno_id
  JOIN public.funcionarios p ON p.id = e.funcionario_id AND p.ativo
  WHERE e.data BETWEEN inicio AND fim AND e.publicado AND e.status <> 'absent'
    AND NOT EXISTS (
      SELECT 1 FROM public.folgas f
      WHERE f.funcionario_id = e.funcionario_id
        AND f.escala_turno_id IS DISTINCT FROM e.id
        AND e.data BETWEEN f.data_inicio AND f.data_fim
    )
  ON CONFLICT (escala_turno_id) DO UPDATE SET
    funcionario_id = EXCLUDED.funcionario_id,
    data_inicio = EXCLUDED.data_inicio, data_fim = EXCLUDED.data_fim,
    tipo = EXCLUDED.tipo, observacao = EXCLUDED.observacao;
  GET DIAGNOSTICS exportados = ROW_COUNT;

  INSERT INTO public.historico_escala (acao, descricao, data_referencia)
  VALUES ('exportacao_calendario',
    format('Calendário: %s registros exportados de %s a %s; %s conflitos preservados.',
      exportados, inicio, fim, conflitos), inicio);
  RETURN jsonb_build_object('exportados', exportados, 'conflitos', conflitos);
END;
$$;

REVOKE ALL ON FUNCTION public.exportar_escala_calendario(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exportar_escala_calendario(date, date) TO authenticated;

COMMIT;
