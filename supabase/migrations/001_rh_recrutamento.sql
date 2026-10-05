-- =====================================================================
-- SiteRH — Fase 1: Recrutamento e Seleção
-- Projeto principal (iueakatarwkvaoomhhah), schema próprio "rh".
--
-- Antes de rodar:
--   Tipos conferidos em 2026-10-05: pessoas.id, filiais.id, contas.id/pessoa_id
--   e acessos_app.pessoa_id são uuid; filiais.codigo é text.
--   Depois de rodar: Settings → API → Exposed schemas → incluir "rh".
--
-- Identidade (skill albusdata): nenhuma tabela de usuários aqui.
-- Quem é a pessoa vem de public.contas/pessoas; o que ela pode vem de
-- public.acessos_app (app = 'rh'). Níveis: admin, editor, leitor.
-- Nada de salário neste schema.
-- =====================================================================

create schema if not exists rh;
grant usage on schema rh to authenticated;

-- ---------------------------------------------------------------------
-- Acesso
-- ---------------------------------------------------------------------

-- pessoa_id de quem está logado (null se não tiver conta ou estiver Inativo)
create or replace function rh.minha_pessoa()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select c.pessoa_id
  from public.contas c
  join public.pessoas p on p.id = c.pessoa_id
  where c.id = auth.uid()
    and coalesce(p.acesso_bloqueado, false) = false
$$;

-- nível no app RH de quem está logado: 'admin' | 'editor' | 'leitor' | null
create or replace function rh.meu_nivel()
returns text
language sql stable security definer set search_path = ''
as $$
  select a.nivel
  from public.acessos_app a
  where a.pessoa_id = rh.minha_pessoa()
    and a.app = 'rh'
  limit 1
$$;

create or replace function rh.pode_ler()   returns boolean language sql stable set search_path = '' as $$ select rh.meu_nivel() in ('admin','editor','leitor') $$;
create or replace function rh.pode_editar() returns boolean language sql stable set search_path = '' as $$ select rh.meu_nivel() in ('admin','editor') $$;
create or replace function rh.e_admin()    returns boolean language sql stable set search_path = '' as $$ select rh.meu_nivel() = 'admin' $$;

-- ---------------------------------------------------------------------
-- Configuração (linha única)
-- ---------------------------------------------------------------------
create table rh.config (
  id            smallint primary key default 1 check (id = 1),
  sla_dias      int not null default 30 check (sla_dias > 0),
  dias_critica  int not null default 60 check (dias_critica > 0),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid()
);
insert into rh.config (id) values (1);

-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
create table rh.origens (
  id    smallint generated always as identity primary key,
  nome  text not null unique,
  ativo boolean not null default true
);
insert into rh.origens (nome) values
  ('Indicação'), ('LinkedIn'), ('Indeed'), ('Site da empresa'),
  ('Banco de talentos'), ('Recrutamento interno'), ('Agência / consultoria'), ('Outros');

create table rh.motivos_cancelamento (
  id    smallint generated always as identity primary key,
  nome  text not null unique,
  ativo boolean not null default true
);
insert into rh.motivos_cancelamento (nome) values
  ('Vaga congelada pelo gestor'), ('Orçamento não aprovado'), ('Remanejamento interno'),
  ('Reestruturação da área'), ('Desistência do candidato aprovado'), ('Outros');

-- ---------------------------------------------------------------------
-- Vagas
-- ---------------------------------------------------------------------
create type rh.status_vaga as enum (
  'solicitada', 'divulgacao', 'triagem', 'entrevistas',
  'aprovacao', 'admissao', 'encerrada', 'cancelada'
);

create table rh.vagas (
  id                      bigint generated always as identity primary key,
  cargo                   text not null check (length(trim(cargo)) > 0),
  area                    text,
  filial_id               uuid not null references public.filiais(id),
  gestor_id               uuid references public.pessoas(id),
  quantidade              int not null default 1 check (quantidade between 1 and 99),
  tipo                    text not null default 'substituicao' check (tipo in ('substituicao','aumento_quadro')),
  status                  rh.status_vaga not null default 'solicitada',
  data_abertura           date not null default current_date,
  data_fechamento         date,
  data_cancelamento       date,
  motivo_cancelamento_id  smallint references rh.motivos_cancelamento(id),
  origem_id               smallint references rh.origens(id),  -- de onde veio o candidato aprovado
  candidato_aprovado      text,                                -- só o nome; nada de CPF/contato
  observacoes             text,
  criado_em               timestamptz not null default now(),
  criado_por              uuid default auth.uid(),
  atualizado_em           timestamptz not null default now(),
  atualizado_por          uuid default auth.uid(),

  constraint vaga_cancelada_tem_motivo check (status <> 'cancelada' or motivo_cancelamento_id is not null),
  constraint vaga_datas_coerentes check (
    (data_fechamento   is null or data_fechamento   >= data_abertura) and
    (data_cancelamento is null or data_cancelamento >= data_abertura)
  )
);
create index on rh.vagas (status);
create index on rh.vagas (filial_id);
create index on rh.vagas (gestor_id);
create index on rh.vagas (data_abertura);

-- Histórico de etapas: escrito só pelo gatilho, nunca pelo cliente.
create table rh.vaga_historico (
  id           bigint generated always as identity primary key,
  vaga_id      bigint not null references rh.vagas(id) on delete cascade,
  status_de    rh.status_vaga,
  status_para  rh.status_vaga not null,
  mudou_em     timestamptz not null default now(),
  mudou_por    uuid default auth.uid()
);
create index on rh.vaga_historico (vaga_id, mudou_em);

create or replace function rh.tg_vagas()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.atualizado_em  := now();
    new.atualizado_por := auth.uid();
    new.criado_em      := old.criado_em;   -- não deixa reescrever autoria
    new.criado_por     := old.criado_por;
  end if;

  -- datas de encerramento acompanham o status
  if new.status = 'encerrada' then
    new.data_fechamento := coalesce(new.data_fechamento, current_date);
  else
    new.data_fechamento := null;
  end if;
  if new.status = 'cancelada' then
    new.data_cancelamento := coalesce(new.data_cancelamento, current_date);
  else
    new.data_cancelamento := null;
    new.motivo_cancelamento_id := null;
  end if;
  return new;
end $$;

create trigger vagas_antes before insert or update on rh.vagas
  for each row execute function rh.tg_vagas();

create or replace function rh.tg_vagas_historico()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into rh.vaga_historico (vaga_id, status_de, status_para) values (new.id, null, new.status);
  elsif new.status is distinct from old.status then
    insert into rh.vaga_historico (vaga_id, status_de, status_para) values (new.id, old.status, new.status);
  end if;
  return null;
end $$;

create trigger vagas_depois after insert or update of status on rh.vagas
  for each row execute function rh.tg_vagas_historico();

-- ---------------------------------------------------------------------
-- Registro de exportações (LGPD: quem levou o quê)
-- ---------------------------------------------------------------------
create table rh.exportacoes (
  id        bigint generated always as identity primary key,
  quem      uuid not null default auth.uid(),
  quando    timestamptz not null default now(),
  formato   text not null check (formato in ('excel','pdf')),
  conteudo  text not null,
  filtros   jsonb
);

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table rh.config               enable row level security;
alter table rh.origens              enable row level security;
alter table rh.motivos_cancelamento enable row level security;
alter table rh.vagas                enable row level security;
alter table rh.vaga_historico       enable row level security;
alter table rh.exportacoes          enable row level security;

create policy ler     on rh.config for select to authenticated using (rh.pode_ler());
create policy alterar on rh.config for update to authenticated using (rh.e_admin()) with check (rh.e_admin());

create policy ler     on rh.origens for select to authenticated using (rh.pode_ler());
create policy incluir on rh.origens for insert to authenticated with check (rh.e_admin());
create policy alterar on rh.origens for update to authenticated using (rh.e_admin()) with check (rh.e_admin());

create policy ler     on rh.motivos_cancelamento for select to authenticated using (rh.pode_ler());
create policy incluir on rh.motivos_cancelamento for insert to authenticated with check (rh.e_admin());
create policy alterar on rh.motivos_cancelamento for update to authenticated using (rh.e_admin()) with check (rh.e_admin());

create policy ler     on rh.vagas for select to authenticated using (rh.pode_ler());
create policy incluir on rh.vagas for insert to authenticated with check (rh.pode_editar());
create policy alterar on rh.vagas for update to authenticated using (rh.pode_editar()) with check (rh.pode_editar());
create policy apagar  on rh.vagas for delete to authenticated using (rh.e_admin());

create policy ler on rh.vaga_historico for select to authenticated using (rh.pode_ler());
-- sem policy de insert/update/delete: só o gatilho escreve

create policy incluir on rh.exportacoes for insert to authenticated with check (rh.pode_ler() and quem = auth.uid());
create policy ler     on rh.exportacoes for select to authenticated using (rh.e_admin());

grant select, update                 on rh.config               to authenticated;
grant select, insert, update         on rh.origens              to authenticated;
grant select, insert, update         on rh.motivos_cancelamento to authenticated;
grant select, insert, update, delete on rh.vagas                to authenticated;
grant select                         on rh.vaga_historico       to authenticated;
grant select, insert                 on rh.exportacoes          to authenticated;

-- ---------------------------------------------------------------------
-- Leituras auxiliares (nomes vêm do principal, sem duplicar cadastro)
-- ---------------------------------------------------------------------

-- Quem sou eu no app (nome, foto, nível) — usado no rodapé da sidebar.
create or replace function rh.eu()
returns table (pessoa_id uuid, nome text, avatar_url text, nivel text)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.nome, p.avatar_url, rh.meu_nivel()
  from public.pessoas p
  where p.id = rh.minha_pessoa() and rh.meu_nivel() is not null
$$;

create or replace function rh.filiais()
returns table (id uuid, codigo text, nome text, ativo boolean)
language sql stable security definer set search_path = ''
as $$
  select f.id, f.codigo, f.nome, coalesce(f.ativo, true) from public.filiais f
  where rh.pode_ler()
  order by f.nome
$$;

create or replace function rh.gestores()
returns table (id uuid, nome text)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.nome from public.pessoas p
  where rh.pode_ler() and p.gestor = true and coalesce(p.acesso_bloqueado, false) = false
  order by p.nome
$$;

-- Histórico de uma vaga com o nome de quem mudou cada etapa.
create or replace function rh.historico_vaga(p_vaga_id bigint)
returns table (status_de rh.status_vaga, status_para rh.status_vaga, mudou_em timestamptz, mudou_por_nome text)
language sql stable security definer set search_path = ''
as $$
  select h.status_de, h.status_para, h.mudou_em, p.nome
  from rh.vaga_historico h
  left join public.contas c on c.id = h.mudou_por
  left join public.pessoas p on p.id = c.pessoa_id
  where h.vaga_id = p_vaga_id and rh.pode_ler()
  order by h.mudou_em, h.id
$$;

revoke execute on all functions in schema rh from public, anon;
grant  execute on function rh.eu(), rh.filiais(), rh.gestores(), rh.historico_vaga(bigint),
                           rh.meu_nivel(), rh.pode_ler(), rh.pode_editar(), rh.e_admin(), rh.minha_pessoa()
       to authenticated;
