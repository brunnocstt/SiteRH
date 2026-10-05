-- =====================================================================
-- SiteRH — Fase 2: Colaboradores, organograma e documentos
-- Projeto principal (iueakatarwkvaoomhhah), schema "rh".
--
-- Regras de produto (decididas com o Bruno, 2026-10):
--  * Sem salário. Sem EPI/ASO (não são do RH). Sem contrato, holerite ou atestado.
--  * Único tipo de arquivo no app: PDF assinado de ENTREGA DE UNIFORME e
--    CERTIFICADO DE TREINAMENTO. Bucket privado, 5 MB, só application/pdf.
--  * Documento só é lido por editor/admin do RH (leitor/diretoria não vê assinatura).
--  * Todo acesso a documento fica registrado (rh.documentos_acessos).
--  * Documento nunca é apagado de fato: exclusão lógica, só admin.
-- A identidade vem de public.pessoas/contas e o acesso de public.acessos_app.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Colaboradores (nomes e cadastro vêm do principal, sem duplicar)
-- ---------------------------------------------------------------------
create or replace function rh.colaboradores()
returns table (
  id uuid, nome text, matricula text, cargo text, centro_custo text,
  filial_id uuid, gestor_imediato_id uuid, gestor boolean,
  avatar_url text, admissao date, inativo boolean
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.nome, p.matricula, p.cargo, p.centro_custo,
         p.filial_id, p.gestor_imediato_id, coalesce(p.gestor, false),
         p.avatar_url, p.admissao,
         (coalesce(p.acesso_bloqueado, false) or coalesce(p.ativo, true) = false)
  from public.pessoas p
  where rh.pode_ler()
  order by p.nome
$$;

-- ---------------------------------------------------------------------
-- Documentos
-- ---------------------------------------------------------------------
create type rh.tipo_documento as enum ('entrega_uniforme', 'certificado_treinamento');

create table rh.documentos (
  id             uuid primary key default gen_random_uuid(),
  pessoa_id      uuid not null references public.pessoas(id) on delete restrict,
  tipo           rh.tipo_documento not null,
  data_documento date not null default current_date,
  descricao      text check (descricao is null or length(descricao) <= 500),  -- itens entregues / nome do curso
  arquivo_path   text not null unique check (arquivo_path like pessoa_id::text || '/%'),
  arquivo_nome   text not null check (length(arquivo_nome) between 1 and 200),
  tamanho_bytes  integer not null check (tamanho_bytes between 1 and 5242880),
  sha256         text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  enviado_por    uuid not null default auth.uid(),
  enviado_em     timestamptz not null default now(),
  excluido_em    timestamptz,
  excluido_por   uuid
);
create index on rh.documentos (pessoa_id, data_documento desc);

create table rh.documentos_acessos (
  id           bigint generated always as identity primary key,
  documento_id uuid not null references rh.documentos(id),
  quem         uuid not null default auth.uid(),
  quando       timestamptz not null default now(),
  acao         text not null check (acao in ('abrir','baixar'))
);
create index on rh.documentos_acessos (documento_id, quando desc);

alter table rh.documentos         enable row level security;
alter table rh.documentos_acessos enable row level security;

-- só editor/admin enxerga e envia; só admin faz exclusão lógica
create policy ler     on rh.documentos for select to authenticated using (rh.pode_editar());
create policy incluir on rh.documentos for insert to authenticated
  with check (rh.pode_editar() and enviado_por = auth.uid() and excluido_em is null);
create policy excluir on rh.documentos for update to authenticated
  using (rh.e_admin()) with check (rh.e_admin());

create policy registrar on rh.documentos_acessos for insert to authenticated
  with check (rh.pode_editar() and quem = auth.uid());
create policy ler       on rh.documentos_acessos for select to authenticated using (rh.e_admin());

grant select, insert, update on rh.documentos         to authenticated;
grant select, insert         on rh.documentos_acessos to authenticated;

-- ---------------------------------------------------------------------
-- Arquivos: bucket privado, só PDF, 5 MB
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('rh-documentos', 'rh-documentos', false, 5242880, array['application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = 5242880, allowed_mime_types = array['application/pdf'];

create policy rh_documentos_ler on storage.objects for select to authenticated
  using (bucket_id = 'rh-documentos' and rh.pode_editar());
create policy rh_documentos_enviar on storage.objects for insert to authenticated
  with check (bucket_id = 'rh-documentos' and rh.pode_editar());
-- sem policy de update/delete: arquivo enviado não muda nem some pelo cliente

revoke execute on all functions in schema rh from public, anon;
grant  execute on function rh.colaboradores() to authenticated;
