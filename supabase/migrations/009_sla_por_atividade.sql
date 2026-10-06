-- =====================================================================
-- SiteRH — Fase 9: SLA só conta enquanto a vaga está com o RH
--
-- Fluxo do workflow: o solicitante abre o chamado -> consultora de RH analisa -> (em vagas não orçadas)
-- diretor de RH, vice-presidência e/ou diretor local aprovam. O tempo parado em etapas de OUTRAS áreas
-- não conta no SLA do RH. Cada atividade do workflow diz quem é o responsável e se conta no SLA.
-- O site só enxerga a atividade no momento da importação; por isso cada mudança de atividade
-- observada fecha um intervalo e abre outro (rh.vaga_atividades). Quanto mais frequente a
-- importação, mais exato o cálculo.
-- =====================================================================

alter table rh.atividade_etapa
  add column responsavel text,
  add column conta_sla boolean not null default true;

update rh.atividade_etapa set responsavel = 'Solicitante',      conta_sla = false where atividade = 'ABRIR_CHAMADO';
update rh.atividade_etapa set responsavel = 'Consultor de RH',  conta_sla = true  where atividade = 'ANALISAR_CHAMADO_CONSULTOR_RH';
update rh.atividade_etapa set responsavel = 'Diretor de RH',    conta_sla = false where atividade = 'ANALISAR_CHAMADO_DIRETOR_RH';

create table rh.vaga_atividades (
  id        bigint generated always as identity primary key,
  vaga_id   bigint not null references rh.vagas(id) on delete cascade,
  atividade text not null,
  desde     date not null,
  ate       date,
  check (ate is null or ate >= desde)
);
create index on rh.vaga_atividades (vaga_id, desde);
alter table rh.vaga_atividades enable row level security;
create policy ler on rh.vaga_atividades for select to authenticated using (rh.pode_ler());
grant select on rh.vaga_atividades to authenticated;     -- escrita só pela função de importação

-- vagas já importadas antes desta migração: assume a atividade atual desde a abertura
insert into rh.vaga_atividades (vaga_id, atividade, desde, ate)
select v.id, v.atividade_atual, v.data_abertura, coalesce(v.data_fechamento, v.data_cancelamento)
  from rh.vagas v
 where v.processo is not null and v.atividade_atual is not null
   and not exists (select 1 from rh.vaga_atividades a where a.vaga_id = v.id);

create or replace function rh.importar_processos(p_linhas jsonb, p_arquivos text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  r jsonb; v rh.vagas%rowtype; fil uuid; motivo smallint;
  proc bigint; v_tipo text; st text; novo_status rh.status_vaga; v_abertura date; fim date; qtd int; v_cargo text; cargo_o text; atv text;
  orc boolean; vig date; existe boolean; fechou boolean;
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
    fechou := st <> 'aberta';
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
    if fil is null then sem_filial := sem_filial + 1; continue; end if;
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
      update rh.vaga_historico set mudou_em = v_abertura::timestamptz + interval '9 hours'
       where vaga_id = v.id and status_de is null;
      -- sem histórico anterior: assume a atividade atual desde a abertura
      if atv is not null then
        insert into rh.vaga_atividades (vaga_id, atividade, desde, ate) values (v.id, atv, v_abertura, case when fechou then fim end);
      end if;
      novas := novas + 1;
    elsif (v.status, v.quantidade, v.cargo, v.cargo_origem, v.filial_id, v.atividade_atual, v.orcado, v.data_vigencia, v.data_abertura, v.origem_processo)
          is not distinct from (novo_status, qtd, v_cargo, cargo_o, fil, atv, orc, vig, v_abertura, v_tipo) then
      iguais := iguais + 1;
    else
      -- mudou de atividade (ou foi concluída/cancelada): fecha o intervalo aberto e, se ainda corre, abre o novo
      if v.atividade_atual is distinct from atv or fechou or v.status in ('encerrada','cancelada') then
        update rh.vaga_atividades set ate = greatest(desde, case when fechou then fim else current_date end)
         where vaga_id = v.id and ate is null;
        if not fechou and atv is not null then
          insert into rh.vaga_atividades (vaga_id, atividade, desde) values (v.id, atv, current_date);
        end if;
      end if;
      update rh.vagas set cargo = v_cargo, quantidade = qtd, filial_id = fil, status = novo_status, data_abertura = v_abertura,
             data_fechamento = case when novo_status = 'encerrada' then coalesce(v.data_fechamento, fim) end,
             data_cancelamento = case when novo_status = 'cancelada' then coalesce(v.data_cancelamento, fim) end,
             motivo_cancelamento_id = case when novo_status = 'cancelada' then coalesce(v.motivo_cancelamento_id, motivo) end,
             origem_processo = v_tipo, atividade_atual = atv, orcado = orc, cargo_origem = cargo_o, data_vigencia = vig
       where id = v.id;
      atualizadas := atualizadas + 1;
    end if;
  end loop;

  select count(*) into ausentes from rh.vagas
   where processo is not null and status not in ('encerrada','cancelada') and processo <> all (ids);

  resumo := jsonb_build_object('novas', novas, 'atualizadas', atualizadas, 'iguais', iguais, 'sem_filial', sem_filial, 'ausentes', ausentes);
  insert into rh.importacoes (arquivos, resumo) values (left(p_arquivos, 500), resumo);
  return resumo;
end $$;

revoke execute on function rh.importar_processos(jsonb, text) from public, anon;
grant execute on function rh.importar_processos(jsonb, text) to authenticated;
