-- =====================================================================
-- SiteRH — Fase 6: importação da planilha de processos (requisição de pessoal e movimentação)
--
-- O RH exporta do sistema de workflow uma planilha com TODOS os processos em andamento.
-- O site lê o arquivo no navegador, mostra uma prévia e envia as linhas já normalizadas
-- para rh.importar_processos(), que cria o que é novo e atualiza o que mudou (chave: nº do processo).
-- Campos que só existem no site (gestor, área, origem do candidato, observações) nunca são sobrescritos.
-- =====================================================================

alter table rh.vagas
  alter column filial_id drop not null,          -- a planilha de movimentação pode vir sem filial
  alter column tipo drop not null,               -- a planilha não informa substituição x aumento de quadro
  alter column tipo drop default,
  add column processo bigint unique,             -- nº do processo no sistema de origem
  add column origem_processo text not null default 'manual' check (origem_processo in ('manual','requisicao','movimentacao')),
  add column atividade_atual text,
  add column orcado boolean,
  add column cargo_origem text,                  -- movimentação: cargo atual (cargo = novo cargo)
  add column data_vigencia date;

insert into rh.motivos_cancelamento (nome) values ('Cancelada no sistema de origem') on conflict (nome) do nothing;

-- atividade do workflow -> etapa do funil no site (editável pelo RH na própria tela de importação)
create table rh.atividade_etapa (
  atividade text primary key,
  etapa     rh.status_vaga not null check (etapa not in ('encerrada','cancelada'))
);
insert into rh.atividade_etapa (atividade, etapa) values
  ('ABRIR_CHAMADO', 'solicitada'),
  ('ANALISAR_CHAMADO_CONSULTOR_RH', 'solicitada'),
  ('ANALISAR_CHAMADO_DIRETOR_RH', 'aprovacao');
alter table rh.atividade_etapa enable row level security;
create policy ler     on rh.atividade_etapa for select to authenticated using (rh.pode_ler());
create policy incluir on rh.atividade_etapa for insert to authenticated with check (rh.pode_editar());
create policy alterar on rh.atividade_etapa for update to authenticated using (rh.pode_editar()) with check (rh.pode_editar());
grant select, insert, update on rh.atividade_etapa to authenticated;

-- registro de cada importação (auditoria)
create table rh.importacoes (
  id       bigint generated always as identity primary key,
  quem     uuid default auth.uid(),
  quando   timestamptz not null default now(),
  arquivos text,
  resumo   jsonb not null
);
alter table rh.importacoes enable row level security;
create policy ler on rh.importacoes for select to authenticated using (rh.pode_editar());
grant select on rh.importacoes to authenticated;

create or replace function rh.importar_processos(p_linhas jsonb, p_arquivos text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r jsonb; v rh.vagas%rowtype; fil uuid; motivo smallint;
  proc bigint; v_tipo text; st text; novo_status rh.status_vaga; v_abertura date; fim date; qtd int; v_cargo text; cargo_o text; atv text;
  orc boolean; vig date; existe boolean;
  novas int := 0; atualizadas int := 0; iguais int := 0; sem_filial int := 0; ausentes int; ids bigint[] := '{}'; resumo jsonb;
begin
  if not rh.pode_editar() then raise exception 'Sem permissão para importar.'; end if;
  if jsonb_typeof(p_linhas) is distinct from 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'Planilha vazia ou inválida.'; end if;
  if jsonb_array_length(p_linhas) > 5000 then raise exception 'Planilha grande demais (máximo de 5000 linhas).'; end if;
  select id into motivo from rh.motivos_cancelamento where nome = 'Cancelada no sistema de origem';

  for r in select * from jsonb_array_elements(p_linhas) loop
    proc := (r->>'processo')::bigint;
    if proc is null then raise exception 'Linha sem número de processo.'; end if;
    v_tipo := r->>'tipo_processo';
    if v_tipo not in ('requisicao','movimentacao') then raise exception 'Processo %: tipo desconhecido (%).', proc, v_tipo; end if;
    st := coalesce(r->>'status', 'aberta');
    if st not in ('aberta','encerrada','cancelada') then raise exception 'Processo %: status desconhecido (%).', proc, st; end if;
    novo_status := case st when 'encerrada' then 'encerrada'::rh.status_vaga when 'cancelada' then 'cancelada'::rh.status_vaga
                   else coalesce(nullif(r->>'etapa',''), 'solicitada')::rh.status_vaga end;
    if st = 'aberta' and novo_status in ('encerrada','cancelada') then raise exception 'Processo %: etapa inválida.', proc; end if;
    v_abertura := (r->>'abertura')::date;
    if v_abertura is null then raise exception 'Processo %: sem data de abertura.', proc; end if;
    fim := greatest(coalesce((r->>'encerramento')::date, current_date), v_abertura);
    qtd := least(greatest(coalesce((r->>'quantidade')::int, 1), 1), 99);
    v_cargo := left(coalesce(nullif(trim(r->>'cargo'), ''), '(não informado)'), 200);
    cargo_o := left(nullif(trim(r->>'cargo_origem'), ''), 200);
    atv := left(nullif(trim(r->>'atividade'), ''), 120);
    orc := (r->>'orcado')::boolean;
    vig := (r->>'vigencia')::date;
    select f.id into fil from public.filiais f where f.codigo = nullif(trim(r->>'filial_codigo'), '');
    if fil is null then sem_filial := sem_filial + 1; end if;
    ids := ids || proc;

    select * into v from rh.vagas where processo = proc;
    existe := found;
    if not existe then
      insert into rh.vagas (cargo, filial_id, quantidade, status, data_abertura, data_fechamento, data_cancelamento, motivo_cancelamento_id,
                            processo, origem_processo, atividade_atual, orcado, cargo_origem, data_vigencia, observacoes)
      values (v_cargo, fil, qtd, novo_status, v_abertura,
              case when novo_status = 'encerrada' then fim end, case when novo_status = 'cancelada' then fim end,
              case when novo_status = 'cancelada' then motivo end,
              proc, v_tipo, atv, orc, cargo_o, vig, 'Importada da planilha')
      returning * into v;
      -- a primeira etapa do histórico nasce na data de abertura do processo, não na do upload
      update rh.vaga_historico set mudou_em = v_abertura::timestamptz + interval '9 hours'
       where vaga_id = v.id and status_de is null;
      novas := novas + 1;
    elsif (v.status, v.quantidade, v.cargo, v.cargo_origem, v.filial_id, v.atividade_atual, v.orcado, v.data_vigencia, v.data_abertura, v.origem_processo)
          is not distinct from (novo_status, qtd, v_cargo, cargo_o, fil, atv, orc, vig, v_abertura, v_tipo) then
      iguais := iguais + 1;
    else
      update rh.vagas set cargo = v_cargo, quantidade = qtd, filial_id = fil, status = novo_status, data_abertura = v_abertura,
             data_fechamento = case when novo_status = 'encerrada' then coalesce(v.data_fechamento, fim) end,
             data_cancelamento = case when novo_status = 'cancelada' then coalesce(v.data_cancelamento, fim) end,
             motivo_cancelamento_id = case when novo_status = 'cancelada' then coalesce(v.motivo_cancelamento_id, motivo) end,
             origem_processo = v_tipo, atividade_atual = atv, orcado = orc, cargo_origem = cargo_o, data_vigencia = vig
       where id = v.id;
      atualizadas := atualizadas + 1;
    end if;
  end loop;

  -- processos que já estavam abertos no site, vieram de planilha antes e não aparecem nesta
  select count(*) into ausentes from rh.vagas
   where processo is not null and status not in ('encerrada','cancelada') and processo <> all (ids);

  resumo := jsonb_build_object('novas', novas, 'atualizadas', atualizadas, 'iguais', iguais, 'sem_filial', sem_filial, 'ausentes', ausentes);
  insert into rh.importacoes (arquivos, resumo) values (left(p_arquivos, 500), resumo);
  return resumo;
end $$;

revoke execute on function rh.importar_processos(jsonb, text) from public, anon;
grant execute on function rh.importar_processos(jsonb, text) to authenticated;
