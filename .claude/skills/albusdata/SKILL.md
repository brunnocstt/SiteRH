---
name: albusdata
description: "O padrão visual, de identidade e de bancos dos apps internos da Deva/IVECO (Hub/Portal Estratégia de Negócio, TopDealer, PM e os próximos), identidade ÚNICA no projeto Supabase principal (todo login de todo app passa por ele, mesmo com banco próprio em outro projeto), decisão schema novo no principal vs projeto separado, modelo de pessoas/contas/acessos, cores, sidebar, logo, login compartilhado por cookie em *.albusdata.com.br e padrão de modal. USE SEMPRE que Bruno pedir app/site novo do grupo Deva (inclusive analisar escopo), migrar app pro Hub, tela de login, menu lateral, modal, mexer em usuários/acessos/foto/senha, auditar app existente, integrar com o Hub (deva.albusdata.com.br) ou debugar sessão/login — mesmo sem dizer \"padrão\" ou \"skill\"."
---

# Padrão de apps Deva/IVECO

Todo app novo do grupo (e qualquer revisão de um existente) deve nascer batendo com o Hub (`SiteHub`) e o TopDealer (`SiteTopDealer`), que são as duas referências vivas e já testadas em produção. Essa skill existe porque esses padrões foram decididos e depurados a duras penas ao longo de várias sessões — reinventar do zero a cada app novo é como a gente ia perdendo tempo e consistência antes de existir isso aqui.

**Regra de ouro: os arquivos de referência abaixo contêm código REAL, copiado direto do Hub/TopDealer em produção — não são exemplos ilustrativos.** Copie os blocos literalmente e adapte só o que precisa mudar por app (nome do app, ícones do menu, cor de destaque se houver variação de marca, schema do Supabase). Se em algum momento notar que o Hub ou o TopDealer mudaram e esses arquivos de referência ficaram desatualizados, releia o código-fonte real deles antes de copiar algo daqui — nunca confie cegamente numa referência que pode ter ficado velha.

## Quando usar cada referência

| Preciso de... | Leia |
|---|---|
| **Onde o app vive (schema no principal vs projeto separado), modelo de pessoas/contas/acessos, como bancos diferentes conversam, regras de produto (login/senha/foto/usuários só no Hub), checklist de app novo, operação (deploy, segredos, e-mail)** | `references/identidade-e-bancos.md` — **leia primeiro em qualquer app novo** |
| Cores, tipografia, tokens CSS (`--accent`, `--ink`, etc.), CSP | `references/design-tokens.md` |
| Menu lateral (sidebar) completo — desktop colapsável + mobile bottom-nav | `references/sidebar.md` |
| Login compartilhado, cookie entre subdomínios, tela de boot (evita flash de login), regra do `?next=` | `references/auth-integration.md` |
| Modal (qualquer popup/dialog) | `references/modal-pattern.md` |
| Logo IVECO/Deva (SVG) | `references/logo.md` |
| **Entender qual "sintaxe" o app usa antes de aplicar qualquer padrão acima** | `references/dialects.md` |

## Dois dialetos, um padrão só

Antes de aplicar qualquer coisa das outras referências, identifique o dialeto do app: **CSS-classes** (Hub, TopDealer — `:root{ --accent:... }` + `.s-link`/`.s-nav`) ou **React-inline** (PM, Padrões — `const BLUE="#1955FF"` + `style={{...}}` por componente, sem build step). Os VALORES (cores, medidas, raios) são idênticos nos dois; só a sintaxe muda. Ver `references/dialects.md` antes de propor qualquer diff que troque a sintaxe de um app existente — trocar dialeto sem necessidade é ruído, não melhoria.

## Regra de identidade (vale pra TODO app, sem exceção)

**Todo login vai pro banco principal** (`iueakatarwkvaoomhhah`), mesmo que o app guarde os dados dele em outro projeto Supabase — nesse caso os bancos conversam: o app de outro projeto autentica no principal e consulta o principal pra saber quem é a pessoa e o que ela pode. Nunca crie base de usuários própria, tela de login/senha própria, upload de foto próprio nem gestão de usuários dentro do app. Detalhes, modelo de dados e o desenho de "satélite" em `references/identidade-e-bancos.md`.

**Antes de escrever uma linha de um app novo:** decida onde ele vive (schema novo no principal é o padrão; projeto separado só com motivo — volume de arquivos, dado sensível, carga, dono diferente). Se o Bruno mandar um escopo, a primeira entrega é essa análise, com números, não código.

## Checklist rápido pra um app NOVO

0. Ler `identidade-e-bancos.md`, decidir onde o app vive e seguir o "Checklist: adicionar um app novo ao ecossistema" de lá (Hub `APPS`, `acessos_app`, e-mail de acesso, catálogo `apps_catalogo`).
1. Copiar os tokens CSS de `design-tokens.md` pro `:root` do novo app.
2. Copiar o CSP de `design-tokens.md`, trocando `connect-src`/`img-src` pra incluir o projeto principal `iueakatarwkvaoomhhah` (auth, fotos) e, se houver, o projeto próprio do app.
3. Copiar a sidebar inteira de `sidebar.md` (HTML + CSS + JS de toggle), trocar só os itens de menu (ícones/labels/páginas). O menu do avatar tem **"Voltar ao Hub"** (e "Sair"), nunca "Meu perfil"/"Alterar senha".
4. Copiar o logo de `logo.md`.
5. Copiar o adaptador de cookie + regras de redirect de `auth-integration.md`. O app **já nasce Fase 2** (Hub como única porta de entrada, sem tela de login própria).
6. Qualquer modal que o app precisar: usar o padrão de `modal-pattern.md` desde o início — NUNCA `overflow-y:auto` direto num elemento com `border-radius`, NUNCA dois scrolls aninhados, e a scrollbar sempre afastada dos cantos arredondados.

## Checklist rápido pra AUDITAR um app existente

Vá item por item comparando com as referências:
- [ ] Os tokens CSS batem com `design-tokens.md`, ou o app tem cores/fontes "quase iguais mas não exatamente"?
- [ ] A sidebar usa a mesma estrutura (`.s-nav`, `.s-link .ico` com posição absoluta fixa, `.s-user-avatar` sem regra especial de recentralizar ao colapsar)? Esse foi um bug real, gastou 3 rodadas de debug — qualquer sidebar que "recentraliza" o ícone/avatar ao colapsar/expandir provavelmente tem o mesmo bug.
- [ ] Login e logout redirecionam pro Hub sem `?next=` (decisão deliberada — ver `auth-integration.md`), ou o app ainda tem tela de login própria sobrevivendo por engano? (Padrões e Ferramentaria ainda são exceções DELIBERADAS: projetos separados, em fila — não "corrigir" de surpresa.)
- [ ] Sobrou no app algo que é do Hub: troca de senha, upload de foto, gestão de usuários, tabela de usuários própria como verdade? Tudo isso deve apontar pro Hub ("Voltar ao Hub").
- [ ] A foto vem de `pessoas.avatar_url` e o texto de interface segue as regras (Inativo, centro de custo capitalizado)?
- [ ] Existe uma tela de boot/spinner antes de decidir mostrar login ou app, ou a tela de login "pisca" a cada F5 pra quem já está logado?
- [ ] Todo modal usa `.modal-card` (moldura, `overflow:hidden`) + `.modal-card-scroll` (o único scroll, com scrollbar fina customizada), ou tem `overflow-y:auto` direto em algo com `border-radius`?

Reporte o que achar divergente e pergunte antes de sair mudando produção — alguns apps ainda não migraram pro Hub de propósito (fila deliberada, não esquecimento).
