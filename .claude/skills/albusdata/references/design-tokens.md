# Design tokens — Deva/IVECO

Fonte: `SiteHub/index.html` (Portal Deva), `:root` do `<style>` principal. Copiado verbatim.

## Tokens CSS

```css
:root{
  --canvas:#FFFFFF; --surface:#FFFFFF; --surface-2:#F1F5F9;
  --ink:#0F172A; --ink-soft:#334155; --muted:#64748B; --muted-2:#94A3B8;
  --line:#E2E8F0; --line-soft:#F1F5F9;
  --accent:#1955FF; --accent-hover:#123FCB; --accent-ink:#FFFFFF;
  --accent-soft:#EFF6FF; --accent-tint-10:#1955FF10;
  --good:#059669; --good-soft:#ECFDF5;
  --warn:#D97706; --warn-soft:#FFFBEB;
  --neutral-status:#64748B; --neutral-status-soft:#F1F5F9;
  --sidebar-bg:#0A0A0B; --sidebar-hover:#18181B;
  --sidebar-text:#71717A; --sidebar-text-hover:#D4D4D8;
  --sidebar-active-tint:rgba(25,85,255,.14); --sidebar-line:rgba(255,255,255,.07);
  --sidebar-popup-bg:#18181B; --sidebar-popup-border:rgba(255,255,255,.08);
  --badge-red:#EF4444;
  --shadow-card: 0 1px 2px rgba(15,23,42,.04), 0 10px 24px -16px rgba(15,23,42,.18);
  --shadow-lift: 0 6px 14px rgba(15,23,42,.06), 0 22px 40px -18px rgba(15,23,42,.24);
  --font-body:'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
  --r-btn:18px; --r-input:16px; --r-card:28px; --r-login:44px;
}
:root{ color-scheme: light; }
```

**Cantos bem arredondados, de propósito (visual "iOS/iPadOS moderno")** — decisão explícita do Bruno, vale pra todo app, não só pros tokens acima:
- Superfícies grandes (modal, card de login, cards de app, tabelas) ficam entre **22px e 44px** de raio — o login card, por ser a maior superfície isolada da tela, é o que chega mais perto do teto.
- Controles pequenos (botão de ícone, input, pill de nav) ficam entre **10px e 18px** — arredondado o bastante pra bater com o resto, mas sem virar uma bolha sem forma (um botão de 26px com raio de 44px vira só um círculo malfeito).
- Elementos que já eram pill/círculo (avatar, badge, toggle) continuam em `999px`/`50%` — não mexe nisso.
- Regra prática: raio cresce com o tamanho do elemento, nunca um valor fixo aplicado em tudo igual.

**Uso das cores principais:**
- `--accent` (`#1955FF`, azul Deva) — botões primários, links, item ativo do menu, foco. É A cor de marca — nunca trocar por outro azul "parecido".
- `--ink` / `--ink-soft` — texto principal / secundário sobre fundo claro.
- `--muted` / `--muted-2` — texto terciário, labels, placeholders.
- `--surface` / `--surface-2` — fundo de cards vs. fundo de hover/seção alternada.
- `--sidebar-bg` (`#0A0A0B`, quase preto) — SEMPRE a cor de fundo da sidebar, mesmo que o resto do app seja claro. Todos os apps atuais usam sidebar escura sobre conteúdo claro.
- `--good`/`--warn` — estados de sucesso/atenção (badges, toasts).

TopDealer usa as mesmas cores mas com nomes de variável um pouco diferentes (`--blue` em vez de `--accent`, `--bg`/`--t1`/`--t2`/`--t3` em vez de `--surface`/`--ink`/`--ink-soft`/`--muted`) — são o MESMO valor de cor, só nomenclatura mais antiga de antes desse padrão existir. Prefira a nomenclatura do Hub (`--accent`, `--ink`, etc.) em apps novos.

## Fonte

Google Fonts, "Plus Jakarta Sans", pesos 400/500/600/700/800:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
```

## Reset base

```css
*,*::before,*::after{ box-sizing:border-box; }
html,body{ margin:0; padding:0; }
body{ background:var(--canvas); color:var(--ink); font-family:var(--font-body); font-size:15px; line-height:1.5; -webkit-font-smoothing:antialiased; }
h1,h2,p{ margin:0; }
button, input{ font-family:inherit; color:inherit; }
a{ color:inherit; }
svg{ display:block; }
::selection{ background:var(--accent-soft); color:var(--ink); }
*:focus-visible{ outline:2px solid var(--accent); outline-offset:2px; border-radius:4px; }
@media (prefers-reduced-motion: reduce){ *{ transition:none !important; animation:none !important; } }
```

O `prefers-reduced-motion` global é importante — qualquer `@keyframes` custom que você adicionar (spinner de boot, fade de sidebar, etc.) já é automaticamente desligado pra quem pediu menos animação no SO, sem precisar duplicar a regra.

## Content-Security-Policy

Todo app tem esse meta tag no `<head>`, com `connect-src` apontando pro projeto Supabase daquele app especificamente (ou pro consolidado, se já migrado):

```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://challenges.cloudflare.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; connect-src 'self' https://SEU-PROJETO.supabase.co; img-src 'self' data: blob:; frame-src https://challenges.cloudflare.com; frame-ancestors 'none'; upgrade-insecure-requests;">
<meta http-equiv="X-Frame-Options" content="DENY">
<meta name="referrer" content="strict-origin-when-cross-origin">
```

Troque `SEU-PROJETO.supabase.co` pelo projeto real. Se o app usa Cloudflare Turnstile (captcha) no login, `challenges.cloudflare.com` já está liberado em `script-src`/`frame-src` acima.

## Dependências de script

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.47.10"></script>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
```

Fixar a versão do `supabase-js` (não usar `@2` solto) evita quebra silenciosa quando a lib lança uma major nova.
