# SiteRH

App de RH do Portal Estratégia de Negócio (Deva/IVECO). Segue a skill `albusdata` (`.claude/skills/albusdata/`).

**Fase 1 — Recrutamento e Seleção:** painel de vagas (abertas, fora do SLA, críticas, tempo médio de fechamento, rankings por filial/gestor/cargo/fonte, motivos de cancelamento), lista de vagas com filtros, cadastro e edição pelo RH, histórico de etapas e exportação para Excel/PDF com registro de quem exportou.

## Arquitetura

- HTML + JS puro, sem build (dialeto A da skill). Publicado pelo GitHub Pages a cada push na `main`.
- Banco: schema `rh` no projeto Supabase principal (`iueakatarwkvaoomhhah`). Sem tabela de usuários própria: identidade em `public.contas`/`pessoas`, acesso em `public.acessos_app` (`app = 'rh'`, níveis `admin`, `editor`, `leitor`).
- Login só pelo Hub (Fase 2): sem sessão, o app manda para `deva.albusdata.com.br`.
- **Nada de salário** no schema `rh`.

## Colocar no ar

1. Rodar `supabase/migrations/001_rh_recrutamento.sql` no SQL Editor do projeto principal.
2. Settings → API → **Exposed schemas**: incluir `rh`.
3. Dar acesso em `public.acessos_app` (ex.: Patricia `admin`, Marcos `editor`).
4. Hub: card do app em `APPS`, `rh` em `APPS_GENERICOS`/`APP_NIVEIS`, `APP_INFO` do e-mail de acesso e linha em `apps_catalogo`.
5. GitHub Pages (Settings → Pages → branch `main`) com o domínio `rhdeva.albusdata.com.br` (arquivo `CNAME`) e um registro DNS CNAME `gestaorhdeva` → `brunnocstt.github.io`. Precisa ser subdomínio de `albusdata.com.br` para enxergar o cookie de sessão do Hub.
