# Identidade, bancos e regras de produto — Deva/IVECO

Esta é a referência mais importante pra decidir ONDE um app novo vive e COMO ele autentica. Atualizada em 2026-10 (PM já migrado; TopDealer migrado; Ferramentaria e Padrões ainda em projetos Supabase próprios).

## Regra de ouro: UMA identidade, SEMPRE no projeto principal

O projeto principal é **`iueakatarwkvaoomhhah`** ("AlbusData Mainscreen", organização "Albus Data", região sa-east-1). Ele é a **única fonte de verdade de identidade**: quem a pessoa é, e-mail, senha, foto, filial, área, gestor, nível no Hub e a quais apps ela tem acesso.

**Qualquer login de qualquer app, em qualquer projeto Supabase, passa por esse banco principal.** Isso vale MESMO que os dados do app morem em outro projeto: os bancos precisam conversar entre si, e a conversa é sempre "o satélite pergunta pro principal quem é a pessoa e o que ela pode", nunca o contrário e nunca uma segunda base de usuários como fonte de verdade.

Proibido, em qualquer app novo (ou ao migrar um existente):
- tela de login própria, "criar conta", "esqueci minha senha" ou "alterar senha" dentro do app — tudo isso é do Hub;
- tabela de usuários própria como fonte de verdade (pode existir um **espelho somente-leitura** com `pessoa_id`);
- upload/troca de foto de perfil dentro do app — a foto é única e só o Hub grava;
- tela de gestão de usuários/acessos dentro do app — **gestão de gente é Hub-only** (o app só tem o item de menu "Voltar ao Hub" no lugar de "Meu perfil/Alterar senha").

## Modelo de dados central (projeto principal)

| Tabela | Papel |
|---|---|
| `auth.users` | login (e-mail + senha). `id` é a chave de tudo |
| `public.pessoas` | cadastro do funcionário: `nome, email, matricula, cargo, centro_custo, filial_id, gestor_imediato_id, gestor (bool), acesso_bloqueado, avatar_url, papel_hub_inicial`. **`acesso_bloqueado` = "Inativo" na interface** (funcionário desligado) — nunca escreva "bloqueado" pro usuário |
| `public.contas` | liga login à pessoa: `id = auth.users.id`, `pessoa_id`, `papel_hub`, `must_change_password`. RLS só de leitura: o cliente NÃO escreve aqui |
| `public.filiais` | `codigo` (5 dígitos), `nome`. A matrícula completa = `0`+código da filial (6 dígitos) + 6 dígitos do número, ex. Betim 55003 → `055003000745` |
| `public.pessoa_filiais` | filial(is) da pessoa (hoje: a filial da casa) |
| `public.acessos_app` | **modelo novo de acesso por app**: `(pessoa_id, app, nivel)`. Apps novos usam ESTE, não tabela de membros própria |
| `<schema>.perfis` | modelo antigo (TopDealer `topdealer.perfis`, PM `pm.perfis`): `perfis.id = auth.users.id = contas.id` |

Regras da identidade:
- `auth.users.id = public.contas.id = <app>.perfis.id`. Um app que precise de dados próprios da pessoa guarda `pessoa_id` (ou o id da conta) e **nunca** duplica nome/e-mail/foto como verdade.
- **`papel_hub`** (em `contas`): `proprietario` / `co_proprietario` / `admin_geral` (acesso total), `admin_area` (só a própria linha + colegas de equipe; chefe só leitura + redefinir senha), `usuario`. O papel no Hub **manda no alcance de pessoas**, mesmo que a pessoa tenha nível alto dentro de um app.
- **Teto de filial:** quem não tem acesso total só concede/cadastra filiais em que ele mesmo tem acesso. Vale em TODO app presente e futuro que tenha filial.
- **Gestor imediato** só pode ser alguém com `pessoas.gestor = true` (a marca é posta sozinha por trigger quando alguém vira gestor de outra pessoa).
- **Foto:** `public.pessoas.avatar_url` (bucket público `avatars`). Cada app que mostrar foto lê dela (ou recebe cópia somente-leitura por trigger, como `pm.perfis.avatar_url`). CSP precisa de `img-src ... https://iueakatarwkvaoomhhah.supabase.co`.
- **Texto de interface:** centro de custo exibido com a primeira letra maiúscula por palavra (siglas PDI/CRM/SGI/SESMT/TI em caixa alta); cargo idem; "Inativo", não "bloqueado".

## Onde um app novo vive: decisão

**Padrão: schema novo no projeto principal** (`create schema <app>`, tabelas + RLS), com acesso via `public.acessos_app`. É assim porque login, pessoa, filial, foto e e-mails já estão lá — zero sincronização.

Considere **projeto separado (satélite)** só se pelo menos um destes for verdade, e justifique:
1. **Volume de arquivos grande** (fotos/PDFs crescendo em GB/ano). O principal está no plano Free (1 GB de storage, sem backup, pausa por inatividade) — ver o plano antes; Pro resolve folga.
2. **Dados sensíveis que exigem isolamento real** (ex.: LGPD pesada). Num mesmo projeto, a service role das Edge Functions do Hub alcança todos os schemas, e quem tem as chaves do projeto vê tudo.
3. **Carga/CPU própria** que atrapalharia o Hub (login de todo mundo mora lá).
4. **Dono diferente** (outra organização/conta Supabase por exigência externa).

Se não bate com nenhum, é schema no principal. Em dúvida, pergunte ao Bruno com número (tamanho estimado, sensibilidade, usuários).

## App satélite (projeto Supabase separado): como os bancos conversam

Ferramentaria e Padrões estão assim hoje (Ferramentaria deve migrar pro principal no começo do ano seguinte; Padrões fica separado). Padrão a seguir pra um satélite — **mecanismo ainda NÃO implementado em produção; validar no primeiro satélite que for integrado, e conferir na documentação atual do Supabase antes de prometer RLS entre projetos**:

1. **Autenticação:** o front do satélite autentica contra o projeto PRINCIPAL (mesmo cliente com URL/anon do principal e o cookie `sb-deva-auth`, ver `auth-integration.md`). A sessão é a do principal.
2. **Dados do satélite:** o PostgREST do satélite só valida JWT do próprio satélite. Então o acesso aos dados dele passa por **Edge Functions do satélite** que (a) verificam o JWT do principal (JWKS: `https://iueakatarwkvaoomhhah.supabase.co/auth/v1/.well-known/jwks.json`), (b) perguntam ao principal se a pessoa tem acesso ao app e com qual nível (função/consulta no principal), (c) só então leem/escrevem no banco do satélite com a service role dele, sempre filtrando por `pessoa_id` do principal.
3. **Cadastro de pessoas:** vive no principal. O satélite, se precisar fazer join, mantém um **espelho somente-leitura** (`pessoas_espelho`) alimentado por webhook/função do principal; nunca é editado no satélite.
4. **Hub:** o card do app satélite só aparece pra quem tem acesso depois que o Hub consegue checar isso (hoje Ferramentaria e Padrões ficam fora da tela inicial por esse motivo).
5. **Chaves e tokens:** cada projeto satélite tem a sua conta/organização Supabase; a tela Gestão de apps do Hub só mostra as chaves dele se existir o segredo `GESTAO_PAT_<ALIAS>` no principal (ou se a conta principal for convidada na organização do satélite).

## Checklist: adicionar um app novo ao ecossistema

1. Decidir schema-no-principal vs satélite (acima) e registrar a decisão.
2. Schema + tabelas + RLS; chave de pessoa = `pessoa_id`/`auth.users.id`; NÃO criar tabela de usuários própria.
3. Acesso: usar `public.acessos_app` (app novo = "genérico" na `hub-manage-access`: incluir em `APPS_GENERICOS` e em `APP_NIVEIS` no front do Hub, com os níveis do app e a hierarquia de quem concede o quê).
4. Hub (`SiteHub/index.html`): entrada em `APPS` (id, ícone, nome, url, `generico:true` se usar `acessos_app`); o e-mail de acesso concedido precisa do app em `_shared/email-acesso.ts` (`APP_INFO`).
5. Gestão de apps (`public.apps_catalogo`): inserir o app (nome, URL, ref do projeto, conta Supabase, repositório).
6. Front do app: sidebar/modal/tokens/auth das outras referências; sem login próprio; item "Voltar ao Hub" no menu do avatar; foto vinda de `pessoas.avatar_url`.
7. CSP do app com os domínios do Supabase certo (`connect-src`, `img-src`).
8. Deploy: GitHub Pages por push na `main`; funções por CLI (ver abaixo).

## Operação (aprendizados que custaram caro)

- **Reverter completo na regressão:** se algo que funcionava quebrou (login, sessão), `git checkout` pro último commit bom na hora; não corrigir incremental em produção.
- **Edge Functions:** deploy por `npx supabase functions deploy <slug> --project-ref <ref> --use-api` a partir de uma pasta com `supabase/functions/<slug>/index.ts` e `_shared/`. O token (PAT `sbp_…`) entra só como variável de ambiente do comando, nunca em arquivo/commit/memória. Não coloque fontes de função dentro do repo de site (GitHub Pages publica o repo inteiro). Confira o slug real pela listagem (Bruno às vezes cria com nome diferente).
- **Segredos de função:** o Supabase NÃO aceita nome começando com `SUPABASE_`. Usar prefixo próprio (`GESTAO_PAT_…`, `ICLOUD_SMTP_PASSWORD`, `SMTP_USER`).
- **E-mail:** SMTP iCloud, login no Apple ID (`SMTP_USER`) com senha de app; remetente `nao-responda@albusdata.com.br`. Use `npm:nodemailer@6` — `denomailer` derruba o worker (503). Layout único dos e-mails em `_shared/email-layout.ts` (cabeçalho preto + logo + barra azul).
- **Senha padrão** do primeiro acesso: `Deva@<ano>` com troca obrigatória; reset de senha por código de 6 dígitos por e-mail (nunca link — filtros de e-mail corporativo clicam em links).
- **Nome do portal:** "Portal Estratégia de Negócio" (a área do Bruno). "Deva Veículos" e o logo "IVECO DEVA" permanecem.
- **Ao testar:** use usuários temporários falsos (criados pela Admin API, apagados no fim) — nunca se passe por pessoa real nem mexa em conta real pra testar.
- **Medidas antes de "corrigir" visual:** se um app parecer menor que outro, meça com `getBoundingClientRect()` nos dois; o zoom do navegador é guardado por site (Ctrl+0) e já enganou uma vez.
