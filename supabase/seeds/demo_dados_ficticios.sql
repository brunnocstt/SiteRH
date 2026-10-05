-- =====================================================================
-- DADOS FICTÍCIOS (DEMO) para ver como o app se apresenta.
-- Tudo marcado com "[DEMO]" e removível com limpar_demo.sql.
-- Vagas e candidatos são inventados. Treinamentos e uniformes usam colaboradores
-- reais SÓ porque a tabela exige uma pessoa existente — os eventos são fictícios.
-- =====================================================================

-- ---------------- Recrutamento: ~90 vagas em 13 meses ----------------
do $$
declare
  filiais uuid[]; gestores uuid[];
  cargos text[] := array['Consultor de Negócios','Mecânico III','Analista Administrativo','Auxiliar de Peças','Vendedor Governo','Estoquista','Instrutor Top Drive','Analista Financeiro Jr','Assistente de Pós-Vendas','Coordenador de Vendas','Técnico de Garantia','Recepcionista','Mecânico Mecatrônica','Analista de Qualidade'];
  areas  text[] := array['Vendas Varejo','Assistência Técnica','Administrativo e Financeiro','Peças','Vendas Governo','Expedição e Estoque','PDI','Garantia'];
  nomes  text[] := array['Rafael Moura','Camila Teixeira','Bruno Alencar','Juliana Prado','Thiago Nogueira','Patrícia Lemos','Diego Fontes','Larissa Campos','Marcelo Viana','Fernanda Rocha','Gustavo Peixoto','Aline Siqueira','Henrique Duarte','Vanessa Pinto','Leandro Barros','Priscila Melo'];
  i int; r float; v_id bigint; ab date; fim date; dur int; st rh.status_vaga; etapas rh.status_vaga[] := array['solicitada','divulgacao','triagem','entrevistas','aprovacao','admissao']::rh.status_vaga[];
  k int; ult int; filial uuid; hoje date := current_date; inicio timestamptz; fimts timestamptz; n int; j int;
begin
  select array_agg(id) into filiais from public.filiais where coalesce(ativo, true);
  select array_agg(id) into gestores from public.pessoas where gestor and not coalesce(acesso_bloqueado, false);
  for i in 1..90 loop
    r := random();
    filial := case when random() < 0.5 then (select id from public.filiais where nome ilike '%betim%' order by codigo limit 1) else filiais[1 + floor(random() * array_length(filiais, 1))::int] end;
    if r < 0.28 then            -- aberta
      ab := hoje - case when random() < 0.65 then (2 + floor(random() * 26))::int else (31 + floor(random() * 65))::int end;
      st := etapas[1 + floor(random() * 6)::int];
      insert into rh.vagas (cargo, area, filial_id, gestor_id, quantidade, tipo, status, data_abertura, observacoes)
      values (cargos[1 + floor(random() * array_length(cargos, 1))::int], areas[1 + floor(random() * array_length(areas, 1))::int], filial,
              gestores[1 + floor(random() * array_length(gestores, 1))::int], 1 + (random() < 0.15)::int,
              case when random() < 0.7 then 'substituicao' else 'aumento_quadro' end, st, ab, '[DEMO] dados fictícios')
      returning id into v_id;
      ult := array_position(etapas, st);
    elsif r < 0.86 then         -- encerrada
      dur := 9 + floor(random() * 58)::int;
      ab := hoje - dur - floor(random() * 380)::int;
      insert into rh.vagas (cargo, area, filial_id, gestor_id, quantidade, tipo, status, data_abertura, data_fechamento, origem_id, candidato_aprovado, observacoes)
      values (cargos[1 + floor(random() * array_length(cargos, 1))::int], areas[1 + floor(random() * array_length(areas, 1))::int], filial,
              gestores[1 + floor(random() * array_length(gestores, 1))::int], 1,
              case when random() < 0.7 then 'substituicao' else 'aumento_quadro' end, 'encerrada', ab, ab + dur,
              (select id from rh.origens order by random() limit 1), nomes[1 + floor(random() * array_length(nomes, 1))::int], '[DEMO] dados fictícios')
      returning id into v_id;
      ult := 7;
    else                        -- cancelada
      dur := 5 + floor(random() * 35)::int;
      ab := hoje - dur - floor(random() * 360)::int;
      insert into rh.vagas (cargo, area, filial_id, gestor_id, quantidade, tipo, status, data_abertura, data_cancelamento, motivo_cancelamento_id, observacoes)
      values (cargos[1 + floor(random() * array_length(cargos, 1))::int], areas[1 + floor(random() * array_length(areas, 1))::int], filial,
              gestores[1 + floor(random() * array_length(gestores, 1))::int], 1, 'substituicao', 'cancelada', ab, ab + dur,
              (select id from rh.motivos_cancelamento order by random() limit 1), '[DEMO] dados fictícios')
      returning id into v_id;
      ult := 8;
    end if;

    -- refaz o histórico de etapas com datas coerentes (o gatilho gravou só "agora")
    delete from rh.vaga_historico where vaga_id = v_id;
    inicio := ab::timestamptz + interval '9 hours';
    select case when status = 'encerrada' then (data_fechamento::timestamptz + interval '16 hours')
                when status = 'cancelada' then (data_cancelamento::timestamptz + interval '16 hours') else now() end
      into fimts from rh.vagas where id = v_id;
    n := least(ult, 7);
    if ult = 8 then n := 1 + floor(random() * 4)::int; end if;   -- cancelada: chegou até uma etapa intermediária
    insert into rh.vaga_historico (vaga_id, status_de, status_para, mudou_em)
      values (v_id, null, 'solicitada', inicio);
    for j in 2..n loop
      insert into rh.vaga_historico (vaga_id, status_de, status_para, mudou_em)
      values (v_id, case when j = 2 then 'solicitada' else etapas[j - 1] end,
              case when j <= 6 then etapas[j] else 'encerrada' end,
              inicio + (fimts - inicio) * ((j - 1)::float / n));
    end loop;
    if ult = 8 then
      insert into rh.vaga_historico (vaga_id, status_de, status_para, mudou_em) values (v_id, etapas[n], 'cancelada', fimts);
    end if;
  end loop;
end $$;

-- ---------------- Treinamentos ----------------
insert into rh.cursos (nome, categoria, obrigatorio, carga_horaria, validade_meses, modalidade) values
  ('[DEMO] Integração', 'Geral', true, 4, null, 'presencial'),
  ('[DEMO] NR-12 Segurança em máquinas', 'Segurança', false, 8, 12, 'presencial'),
  ('[DEMO] Direção defensiva', 'Segurança', false, 8, 24, 'hibrido'),
  ('[DEMO] Atendimento ao cliente', 'Comportamental', false, 6, 12, 'online'),
  ('[DEMO] Mecatrônica Nível 1', 'Técnico', false, 40, 24, 'hibrido'),
  ('[DEMO] Mecânico Master — Módulo A', 'Técnico', false, 60, 36, 'presencial');

insert into rh.trilhas (nome, descricao) values
  ('[DEMO] Mecânico Master', 'Formação completa de mecânico'),
  ('[DEMO] Mecânico Mecatrônica', 'Especialização em mecatrônica');
insert into rh.trilha_cursos (trilha_id, curso_id, ordem)
  select t.id, c.id, x.ordem from (values ('[DEMO] Mecânico Master','[DEMO] Mecânico Master — Módulo A',1), ('[DEMO] Mecânico Master','[DEMO] NR-12 Segurança em máquinas',2),
                                          ('[DEMO] Mecânico Mecatrônica','[DEMO] Mecatrônica Nível 1',1), ('[DEMO] Mecânico Mecatrônica','[DEMO] NR-12 Segurança em máquinas',2)) as x(t, c, ordem)
  join rh.trilhas t on t.nome = x.t join rh.cursos c on c.nome = x.c;

-- exigências por cargo (cargos que existem no cadastro)
insert into rh.exigencias (curso_id, cargo)
  select (select id from rh.cursos where nome = '[DEMO] NR-12 Segurança em máquinas'), cg
  from (select distinct upper(trim(cargo)) cg from public.pessoas where cargo ilike '%mecanic%') s on conflict do nothing;
insert into rh.exigencias (curso_id, cargo)
  select (select id from rh.cursos where nome = '[DEMO] Atendimento ao cliente'), cg
  from (select distinct upper(trim(cargo)) cg from public.pessoas where cargo ilike '%consultor de neg%' or cargo ilike '%vendedor%') s on conflict do nothing;
insert into rh.exigencias (curso_id, cargo)
  select (select id from rh.cursos where nome = '[DEMO] Direção defensiva'), cg
  from (select distinct upper(trim(cargo)) cg from public.pessoas where cargo ilike '%instrutor%') s on conflict do nothing;

-- mecânicos nas trilhas
insert into rh.pessoa_trilhas (pessoa_id, trilha_id, nivel)
  select x.id, (select id from rh.trilhas where nome = case when x.rn % 2 = 0 then '[DEMO] Mecânico Master' else '[DEMO] Mecânico Mecatrônica' end limit 1),
         (array['Nível I','Nível II','Nível III'])[1 + (x.rn % 3)]
  from (select p.id, row_number() over (order by p.id) rn from public.pessoas p
        where p.cargo ilike '%mecanic%' and not coalesce(p.acesso_bloqueado, false)) x on conflict do nothing;

-- histórico de conclusões (mistura de em dia / vencendo / vencido)
insert into rh.conclusoes (pessoa_id, curso_id, data_conclusao, origem)
  select p.id, (select id from rh.cursos where nome = '[DEMO] Integração'), current_date - (30 + floor(random() * 1500))::int, 'manual'
  from public.pessoas p where not coalesce(p.acesso_bloqueado, false) and random() < 0.82;
insert into rh.conclusoes (pessoa_id, curso_id, data_conclusao, origem)
  select p.id, c.id, current_date - (15 + floor(random() * 480))::int, 'manual'
  from public.pessoas p join rh.exigencias e on e.cargo = upper(trim(p.cargo)) join rh.cursos c on c.id = e.curso_id
  where not coalesce(p.acesso_bloqueado, false) and random() < 0.7;
insert into rh.conclusoes (pessoa_id, curso_id, data_conclusao, origem)
  select p.id, (select id from rh.cursos where nome = '[DEMO] Mecatrônica Nível 1'), current_date - (60 + floor(random() * 600))::int, 'manual'
  from public.pessoas p where p.cargo ilike '%mecanic%' and not coalesce(p.acesso_bloqueado, false) and random() < 0.5;

-- turmas: 4 realizadas (aprovados geram conclusão) e 4 futuras (só convocados)
insert into rh.turmas (curso_id, inicio, fim, horario, local, instrutor, capacidade, status, observacoes)
  select c.id, current_date + x.dias, current_date + x.dias, '08h às 17h', x.local, x.instrutor, x.cap, case when x.dias < 0 then 'realizada' else 'agendada' end, '[DEMO]'
  from (values ('[DEMO] NR-12 Segurança em máquinas', -75, 'Sala de treinamento Betim', 'Instrutor Externo A', 15),
               ('[DEMO] Direção defensiva', -40, 'Auditório BH', 'Instrutor Externo B', 20),
               ('[DEMO] Atendimento ao cliente', -18, 'Online', 'Instrutor Interno', 30),
               ('[DEMO] Integração', -6, 'Sala de treinamento Betim', 'RH', 12),
               ('[DEMO] NR-12 Segurança em máquinas', 9, 'Sala de treinamento Betim', 'Instrutor Externo A', 10),
               ('[DEMO] Mecatrônica Nível 1', 21, 'Oficina Betim', 'Montadora', 8),
               ('[DEMO] Direção defensiva', 34, 'Auditório Juiz de Fora', 'Instrutor Externo B', 20),
               ('[DEMO] Atendimento ao cliente', 48, 'Online', 'Instrutor Interno', 30)) as x(curso, dias, local, instrutor, cap)
  join rh.cursos c on c.nome = x.curso;
insert into rh.turma_participantes (turma_id, pessoa_id, status, nota)
  select t.id, p.id, case when random() < 0.12 then 'ausente' when random() < 0.08 then 'reprovado' else 'aprovado' end, round((6 + random() * 4)::numeric, 1)
  from rh.turmas t join lateral (select id from public.pessoas where not coalesce(acesso_bloqueado, false) order by random() limit 8) p on true
  where t.observacoes = '[DEMO]' and t.status = 'realizada';
insert into rh.turma_participantes (turma_id, pessoa_id, status)
  select t.id, p.id, case when random() < 0.5 then 'confirmado' else 'convocado' end
  from rh.turmas t join lateral (select id from public.pessoas where not coalesce(acesso_bloqueado, false) order by random() limit 6) p on true
  where t.observacoes = '[DEMO]' and t.status = 'agendada';

-- ---------------- Entregas de uniforme ----------------
do $$
declare
  pid uuid; d uuid; quem uuid; n int := 0;
begin
  select id into quem from auth.users where email in (select email from public.pessoas where lower(nome) like 'bruno cesar%') limit 1;
  if quem is null then select id into quem from auth.users order by created_at limit 1; end if;
  for pid in select id from public.pessoas where not coalesce(acesso_bloqueado, false) order by random() limit 36 loop
    n := n + 1;
    if n <= 9 then          -- aguardando assinatura há muito tempo (alerta)
      insert into rh.entregas_uniforme (pessoa_id, data_entrega, quantidade, itens, status, gerada_em, observacoes)
      values (pid, current_date - (2 + (n % 6)), 2 + (n % 3), '2 camisas, 2 calças' || case when n % 2 = 0 then ', 1 jaqueta' else '' end, 'aguardando', now() - ((30 + n * 11) || ' hours')::interval, '[DEMO]');
    elsif n <= 14 then      -- aguardando, ainda dentro do prazo
      insert into rh.entregas_uniforme (pessoa_id, data_entrega, quantidade, itens, status, gerada_em, observacoes)
      values (pid, current_date, 2, '2 camisas', 'aguardando', now() - ((2 + n) || ' hours')::interval, '[DEMO]');
    elsif n <= 33 then      -- assinadas (o arquivo é fictício)
      insert into rh.documentos (pessoa_id, tipo, data_documento, descricao, arquivo_path, arquivo_nome, tamanho_bytes, sha256, enviado_por)
      values (pid, 'entrega_uniforme', current_date - (n * 6), '[DEMO] termo assinado', pid || '/demo-' || n || '.pdf', 'termo-assinado-demo.pdf', 1000, repeat('0', 64), quem)
      returning id into d;
      insert into rh.entregas_uniforme (pessoa_id, data_entrega, quantidade, itens, status, gerada_em, documento_id, assinado_em, observacoes)
      values (pid, current_date - (n * 6), 2 + (n % 4), '2 camisas, 2 calças', 'assinado', now() - ((n * 6) || ' days')::interval, d, now() - ((n * 6 - 1) || ' days')::interval, '[DEMO]');
    else                    -- canceladas
      insert into rh.entregas_uniforme (pessoa_id, data_entrega, quantidade, itens, status, gerada_em, cancelado_em, observacoes)
      values (pid, current_date - n, 1, null, 'cancelado', now() - (n || ' days')::interval, now() - (n || ' days')::interval, '[DEMO] lançada por engano');
    end if;
  end loop;
end $$;
