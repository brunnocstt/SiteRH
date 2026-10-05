-- =====================================================================
-- SiteRH — Fase 4: Entregas de uniforme e configurações de alerta
--
-- Fluxo: o RH registra a entrega -> o app gera o PDF (termo) com nome, matrícula,
-- filial, data e quantidade -> imprime -> o colaborador assina -> o RH digitaliza e
-- anexa o PDF assinado. O PDF assinado é um rh.documentos (tipo entrega_uniforme),
-- vinculado à entrega. Entrega "aguardando" há mais de rh.config.horas_alerta_assinatura
-- horas vira alerta na tela de Uniformes.
-- =====================================================================

alter table rh.config add column horas_alerta_assinatura int not null default 24
  check (horas_alerta_assinatura between 1 and 720);

create table rh.entregas_uniforme (
  id             bigint generated always as identity primary key,
  pessoa_id      uuid not null references public.pessoas(id) on delete restrict,
  data_entrega   date not null,
  quantidade     int  not null check (quantidade between 1 and 99),
  itens          text check (itens is null or length(itens) <= 500),
  status         text not null default 'aguardando' check (status in ('aguardando', 'assinado', 'cancelado')),
  gerada_por     uuid default auth.uid(),
  gerada_em      timestamptz not null default now(),
  documento_id   uuid references rh.documentos(id),
  assinado_em    timestamptz,
  cancelado_em   timestamptz,
  observacoes    text check (observacoes is null or length(observacoes) <= 500),
  check ((status = 'assinado') = (documento_id is not null))
);
create index on rh.entregas_uniforme (pessoa_id, data_entrega desc);
create index on rh.entregas_uniforme (status, gerada_em);

-- valida: data não pode ser futura; o documento anexado tem de ser do mesmo colaborador e do tipo certo
create or replace function rh.tg_entregas_uniforme()
returns trigger language plpgsql security definer set search_path = '' as $$
declare d record;
begin
  if new.data_entrega > current_date then
    raise exception 'A data da entrega não pode estar no futuro.';
  end if;
  if new.documento_id is not null then
    select pessoa_id, tipo, excluido_em into d from rh.documentos where id = new.documento_id;
    if d.pessoa_id is distinct from new.pessoa_id or d.tipo is distinct from 'entrega_uniforme' or d.excluido_em is not null then
      raise exception 'O documento anexado não é um comprovante de uniforme deste colaborador.';
    end if;
    if new.assinado_em is null then new.assinado_em := now(); end if;
  end if;
  if new.status = 'cancelado' and new.cancelado_em is null then new.cancelado_em := now(); end if;
  return new;
end $$;
create trigger entregas_uniforme_antes before insert or update on rh.entregas_uniforme
  for each row execute function rh.tg_entregas_uniforme();

alter table rh.entregas_uniforme enable row level security;
create policy ler     on rh.entregas_uniforme for select to authenticated using (rh.pode_editar());
create policy incluir on rh.entregas_uniforme for insert to authenticated
  with check (rh.pode_editar() and gerada_por = auth.uid() and status = 'aguardando');
create policy alterar on rh.entregas_uniforme for update to authenticated
  using (rh.pode_editar()) with check (rh.pode_editar());
-- sem delete: entrega errada se cancela, não se apaga

grant select, insert, update on rh.entregas_uniforme to authenticated;

revoke execute on all functions in schema rh from public, anon;
