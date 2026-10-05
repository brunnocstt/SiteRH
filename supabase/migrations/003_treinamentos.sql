-- =====================================================================
-- SiteRH — Fase 3: Treinamentos
-- Projeto principal (iueakatarwkvaoomhhah), schema "rh".
--
-- Modelo flexível (a Patricia ainda vai ajustar trilhas/matriz):
--   cursos            catálogo (obrigatório p/ todos, carga horária, validade, modalidade)
--   trilhas           formações/especialidades (ex.: Mecânico Master, Mecatrônica) = conjunto de cursos
--   pessoa_trilhas    em qual trilha cada colaborador está (e nível)
--   exigencias        curso obrigatório para um CARGO (caixa alta)
--   turmas            agenda (data, local, instrutor, capacidade)
--   turma_participantes  quem foi designado; status até aprovado/reprovado
--   conclusoes        histórico de quem concluiu o quê (gerado ao aprovar, ou manual)
-- "O que cada um precisa fazer" = obrigatório p/ todos + exigência do cargo + cursos
-- das trilhas em que a pessoa está "cursando"; a situação (ok, vencendo, vencido,
-- pendente) sai de rh.situacao_treinamentos().
-- Regras de acesso: catálogo só admin; operação (turmas, designação, conclusão) editor/admin;
-- leitura para todo o RH. Sem salário, sem dado de saúde.
-- =====================================================================

alter table rh.config add column dias_alerta_vencimento int not null default 60
  check (dias_alerta_vencimento between 1 and 365);

create type rh.modalidade as enum ('presencial', 'online', 'hibrido');

create table rh.cursos (
  id             int generated always as identity primary key,
  nome           text not null unique check (length(trim(nome)) > 0),
  categoria      text,
  obrigatorio    boolean not null default false,        -- obrigatório para TODO colaborador ativo
  carga_horaria  numeric(5,1) not null default 0 check (carga_horaria between 0 and 999),
  validade_meses int check (validade_meses is null or validade_meses between 1 and 120),  -- null = não vence
  modalidade     rh.modalidade not null default 'presencial',
  ativo          boolean not null default true
);

create table rh.trilhas (
  id        int generated always as identity primary key,
  nome      text not null unique check (length(trim(nome)) > 0),
  descricao text,
  ativo     boolean not null default true
);

create table rh.trilha_cursos (
  trilha_id int not null references rh.trilhas(id) on delete cascade,
  curso_id  int not null references rh.cursos(id)  on delete cascade,
  ordem     int not null default 1,
  primary key (trilha_id, curso_id)
);

create table rh.pessoa_trilhas (
  pessoa_id    uuid not null references public.pessoas(id) on delete restrict,
  trilha_id    int  not null references rh.trilhas(id),
  nivel        text,
  status       text not null default 'cursando' check (status in ('cursando', 'concluida')),
  desde        date not null default current_date,
  concluida_em date,
  primary key (pessoa_id, trilha_id),
  check ((status = 'concluida') = (concluida_em is not null))
);

create table rh.exigencias (
  id       int generated always as identity primary key,
  curso_id int  not null references rh.cursos(id) on delete cascade,
  cargo    text not null check (length(trim(cargo)) > 0 and cargo = upper(cargo)),
  unique (curso_id, cargo)
);

create table rh.turmas (
  id          int generated always as identity primary key,
  curso_id    int  not null references rh.cursos(id),
  inicio      date not null,
  fim         date,
  horario     text,
  local       text,
  instrutor   text,
  capacidade  int check (capacidade is null or capacidade between 1 and 999),
  status      text not null default 'agendada' check (status in ('agendada', 'realizada', 'cancelada')),
  observacoes text,
  criado_por  uuid default auth.uid(),
  criado_em   timestamptz not null default now(),
  check (fim is null or fim >= inicio)
);
create index on rh.turmas (inicio);
create index on rh.turmas (curso_id);

create table rh.turma_participantes (
  turma_id     int  not null references rh.turmas(id) on delete cascade,
  pessoa_id    uuid not null references public.pessoas(id) on delete restrict,
  status       text not null default 'convocado'
               check (status in ('convocado', 'confirmado', 'presente', 'ausente', 'aprovado', 'reprovado')),
  nota         numeric(4,1) check (nota is null or nota between 0 and 100),
  designado_por uuid default auth.uid(),
  designado_em  timestamptz not null default now(),
  primary key (turma_id, pessoa_id)
);
create index on rh.turma_participantes (pessoa_id);

create table rh.conclusoes (
  id             bigint generated always as identity primary key,
  pessoa_id      uuid not null references public.pessoas(id) on delete restrict,
  curso_id       int  not null references rh.cursos(id),
  data_conclusao date not null,
  validade_ate   date,
  carga_horaria  numeric(5,1) not null default 0,
  turma_id       int references rh.turmas(id) on delete set null,
  origem         text not null default 'manual' check (origem in ('manual', 'turma')),
  documento_id   uuid references rh.documentos(id),
  registrado_por uuid default auth.uid(),
  registrado_em  timestamptz not null default now()
);
create index on rh.conclusoes (pessoa_id, curso_id, data_conclusao desc);

-- ---------------------------------------------------------------------
-- Gatilhos
-- ---------------------------------------------------------------------
-- conclusão: não aceita data futura; herda carga horária e calcula a validade pelo curso
create or replace function rh.tg_conclusoes()
returns trigger language plpgsql security definer set search_path = '' as $$
declare c record;
begin
  if new.data_conclusao > current_date then
    raise exception 'A data de conclusão não pode estar no futuro.';
  end if;
  select validade_meses, carga_horaria into c from rh.cursos where id = new.curso_id;
  if new.validade_ate is null and c.validade_meses is not null then
    new.validade_ate := (new.data_conclusao + make_interval(months => c.validade_meses))::date;
  end if;
  if coalesce(new.carga_horaria, 0) = 0 then new.carga_horaria := coalesce(c.carga_horaria, 0); end if;
  return new;
end $$;
create trigger conclusoes_antes before insert on rh.conclusoes for each row execute function rh.tg_conclusoes();

-- participante aprovado => conclusão registrada (uma vez por turma/pessoa)
create or replace function rh.tg_participante_aprovado()
returns trigger language plpgsql security definer set search_path = '' as $$
declare t record;
begin
  if new.status = 'aprovado' and (tg_op = 'INSERT' or old.status is distinct from 'aprovado') then
    select curso_id, coalesce(fim, inicio) as dia into t from rh.turmas where id = new.turma_id;
    if not exists (select 1 from rh.conclusoes where turma_id = new.turma_id and pessoa_id = new.pessoa_id) then
      insert into rh.conclusoes (pessoa_id, curso_id, data_conclusao, turma_id, origem, registrado_por)
      values (new.pessoa_id, t.curso_id, least(t.dia, current_date), new.turma_id, 'turma', auth.uid());
    end if;
  end if;
  return null;
end $$;
create trigger participante_aprovado after insert or update of status on rh.turma_participantes
  for each row execute function rh.tg_participante_aprovado();

-- ---------------------------------------------------------------------
-- Situação de cada colaborador x curso exigido
-- ---------------------------------------------------------------------
create or replace function rh.situacao_treinamentos()
returns table (pessoa_id uuid, curso_id int, motivo text, ultima_conclusao date, validade_ate date, situacao text)
language sql stable security definer set search_path = ''
as $$
  with ativos as (
    select p.id, upper(trim(coalesce(p.cargo, ''))) as cargo
    from public.pessoas p
    where coalesce(p.acesso_bloqueado, false) = false and coalesce(p.ativo, true)
  ),
  exig as (
    select a.id as pessoa_id, c.id as curso_id, 'Obrigatório para todos'::text as motivo
      from ativos a cross join rh.cursos c where c.ativo and c.obrigatorio
    union
    select a.id, e.curso_id, 'Obrigatório para o cargo'::text
      from ativos a join rh.exigencias e on e.cargo = a.cargo
      join rh.cursos c on c.id = e.curso_id and c.ativo
    union
    select pt.pessoa_id, tc.curso_id, ('Trilha: ' || t.nome)::text
      from rh.pessoa_trilhas pt
      join rh.trilhas t on t.id = pt.trilha_id and t.ativo
      join rh.trilha_cursos tc on tc.trilha_id = pt.trilha_id
      join rh.cursos c on c.id = tc.curso_id and c.ativo
      join ativos a on a.id = pt.pessoa_id
      where pt.status = 'cursando'
  ),
  uniq as (
    select e.pessoa_id, e.curso_id, string_agg(distinct e.motivo, ' · ') as motivo from exig e group by 1, 2
  ),
  ult as (
    select distinct on (k.pessoa_id, k.curso_id) k.pessoa_id, k.curso_id, k.data_conclusao, k.validade_ate
    from rh.conclusoes k order by k.pessoa_id, k.curso_id, k.data_conclusao desc, k.id desc
  )
  select u.pessoa_id, u.curso_id, u.motivo, l.data_conclusao, l.validade_ate,
    case when l.data_conclusao is null then 'pendente'
         when l.validade_ate is null then 'ok'
         when l.validade_ate < current_date then 'vencido'
         when l.validade_ate <= current_date + (select cfg.dias_alerta_vencimento from rh.config cfg where cfg.id = 1) then 'vencendo'
         else 'ok' end
  from uniq u left join ult l on l.pessoa_id = u.pessoa_id and l.curso_id = u.curso_id
  where rh.pode_ler()
$$;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table rh.cursos               enable row level security;
alter table rh.trilhas              enable row level security;
alter table rh.trilha_cursos        enable row level security;
alter table rh.pessoa_trilhas       enable row level security;
alter table rh.exigencias           enable row level security;
alter table rh.turmas               enable row level security;
alter table rh.turma_participantes  enable row level security;
alter table rh.conclusoes           enable row level security;

-- catálogo: lê todo o RH, mexe só admin
create policy ler     on rh.cursos for select to authenticated using (rh.pode_ler());
create policy incluir on rh.cursos for insert to authenticated with check (rh.e_admin());
create policy alterar on rh.cursos for update to authenticated using (rh.e_admin()) with check (rh.e_admin());
create policy apagar  on rh.cursos for delete to authenticated using (rh.e_admin());

create policy ler     on rh.trilhas for select to authenticated using (rh.pode_ler());
create policy incluir on rh.trilhas for insert to authenticated with check (rh.e_admin());
create policy alterar on rh.trilhas for update to authenticated using (rh.e_admin()) with check (rh.e_admin());
create policy apagar  on rh.trilhas for delete to authenticated using (rh.e_admin());

create policy ler     on rh.trilha_cursos for select to authenticated using (rh.pode_ler());
create policy incluir on rh.trilha_cursos for insert to authenticated with check (rh.e_admin());
create policy alterar on rh.trilha_cursos for update to authenticated using (rh.e_admin()) with check (rh.e_admin());
create policy apagar  on rh.trilha_cursos for delete to authenticated using (rh.e_admin());

create policy ler     on rh.exigencias for select to authenticated using (rh.pode_ler());
create policy incluir on rh.exigencias for insert to authenticated with check (rh.e_admin());
create policy apagar  on rh.exigencias for delete to authenticated using (rh.e_admin());

-- operação: editor e admin
create policy ler     on rh.pessoa_trilhas for select to authenticated using (rh.pode_ler());
create policy incluir on rh.pessoa_trilhas for insert to authenticated with check (rh.pode_editar());
create policy alterar on rh.pessoa_trilhas for update to authenticated using (rh.pode_editar()) with check (rh.pode_editar());
create policy apagar  on rh.pessoa_trilhas for delete to authenticated using (rh.pode_editar());

create policy ler     on rh.turmas for select to authenticated using (rh.pode_ler());
create policy incluir on rh.turmas for insert to authenticated with check (rh.pode_editar());
create policy alterar on rh.turmas for update to authenticated using (rh.pode_editar()) with check (rh.pode_editar());
create policy apagar  on rh.turmas for delete to authenticated using (rh.e_admin());

create policy ler     on rh.turma_participantes for select to authenticated using (rh.pode_ler());
create policy incluir on rh.turma_participantes for insert to authenticated with check (rh.pode_editar());
create policy alterar on rh.turma_participantes for update to authenticated using (rh.pode_editar()) with check (rh.pode_editar());
create policy apagar  on rh.turma_participantes for delete to authenticated using (rh.pode_editar());

create policy ler     on rh.conclusoes for select to authenticated using (rh.pode_ler());
create policy incluir on rh.conclusoes for insert to authenticated with check (rh.pode_editar());
create policy apagar  on rh.conclusoes for delete to authenticated using (rh.e_admin());

grant select, insert, update, delete on rh.cursos, rh.trilhas, rh.trilha_cursos to authenticated;
grant select, insert, delete         on rh.exigencias to authenticated;
grant select, insert, update, delete on rh.pessoa_trilhas, rh.turmas, rh.turma_participantes to authenticated;
grant select, insert, delete         on rh.conclusoes to authenticated;

revoke execute on all functions in schema rh from public, anon;
grant  execute on function rh.situacao_treinamentos() to authenticated;
