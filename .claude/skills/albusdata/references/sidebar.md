# Sidebar (menu lateral) — Deva/IVECO

Fonte: `SiteTopDealer/index.html`, versão final depois de 3 rodadas de debug de um bug real de "pulo" do ícone/avatar ao colapsar/expandir o menu. **Leia a seção "O bug que já resolvemos" antes de mexer nisso** — é fácil reintroduzir o mesmo problema por um caminho diferente.

Esse arquivo documenta a sintaxe do **Dialeto A** (CSS-classes — ver `dialects.md`). Se o app que você está construindo/revisando é React-inline (PM, Padrões — Dialeto B), a ESTRUTURA e os VALORES abaixo (medidas, cores, raios) ainda valem — só a sintaxe muda pra `style={{...}}` por componente em vez de classe CSS. Ver o exemplo real do Dialeto B em `dialects.md`.

## HTML

```html
<aside class="sidebar" id="sidebar">
  <div class="s-logo">
    <button class="btn-toggle-menu" id="menu-toggle"><!-- ícone hambúrguer --></button>
    <div class="logo-full-wrap">
      <svg class="logo-mark" viewBox="0 0 183 15"><use href="#i-logo-ivecodeva"/></svg>
    </div>
  </div>

  <div class="s-nav">
    <a class="s-link active" data-page="dashboard">
      <span class="ico"><!-- svg do ícone --></span>
      <span class="s-label">Dashboard</span>
    </a>
    <!-- repetir .s-link pra cada item de menu -->
  </div>

  <div class="s-foot">
    <button class="s-user-btn" id="s-user-btn">
      <span class="s-user-avatar" id="s-user-avatar-ico">A</span>
      <span class="s-user-name" id="s-user-name-lbl">Nome da pessoa</span>
    </button>
  </div>
</aside>

<!-- dropdown de logout, ancorado no sidebar -->
<div class="s-user-dropdown" id="s-user-dropdown">
  <button class="s-user-dd-item danger" onclick="logout()">Sair</button>
</div>
```

## CSS completo

```css
:root{ --sidebar-w: 240px; --sidebar-w-min: 56px; }

.sidebar {
  width: var(--sidebar-w);
  background: #0A0A0B;
  display: flex;
  flex-direction: column;
  position: fixed;
  top: 0; left: 0;
  height: 100vh;
  z-index: 200;
  overflow: hidden;
  transition: width .24s cubic-bezier(.4,0,.2,1);
  flex-shrink: 0;
}
body.menu-fechado .sidebar { width: var(--sidebar-w-min); }

.s-logo {
  display: flex; align-items: center;
  height: 64px; flex-shrink: 0;
  border-bottom: 1px solid rgba(255,255,255,.07);
}
.btn-toggle-menu {
  width: 28px; height: 28px; margin-left: 14px; flex-shrink: 0;
  border-radius: 12px; border: none; background: transparent;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #A1A1AA; transition: background .15s, color .15s;
}
.btn-toggle-menu:hover { background: #18181B; color: #fff; }
.logo-full-wrap {
  margin-left: 14px; padding-right: 14px; flex: 1; min-width: 0;
  display: flex; align-items: center;
  opacity: 0; animation: sbFadeIn .22s ease .08s forwards;
  overflow: hidden;
}
.logo-full-wrap svg { max-width: 100%; height: auto; }
body.menu-fechado .logo-full-wrap { display: none !important; }

@keyframes sbFadeIn { to { opacity: 1; } }

.s-nav { flex:1; padding: 12px 0; overflow-y:auto; overflow-x:hidden; }

/* Nav items — ícone fixo à esq, texto anima */
.s-link {
  display: block; position: relative;
  width: 100%; height: 40px; padding-left: 52px; padding-right: 10px;
  border: none; border-radius: 14px; cursor: pointer;
  background: transparent; color: #71717A;
  font-size: 13px; font-weight: 500; text-align: left;
  text-decoration: none; line-height: 40px;
  white-space: nowrap; overflow: hidden;
  margin-bottom: 2px;
  transition: background .15s, color .15s;
}
.s-link:hover { background: #18181B; color: #D4D4D8; }
.s-link.active { background: rgba(25,85,255,.14); color: #fff; }
/* Barra azul vertical no item ativo */
.s-link.active::before {
  content: ''; position: absolute; left: 0; top: 50%;
  transform: translateY(-50%);
  width: 3px; height: 22px; border-radius: 0 4px 4px 0;
  background: #1955FF;
}
/* Ícone sempre visível na posição fixa */
.s-link .ico {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  width: 28px; height: 28px;
  display: flex; align-items: center; justify-content: center;
}
.s-link .ico svg { stroke: currentColor !important; }
.s-link.active .ico svg { stroke: #1955FF !important; }
/* Texto anima quando expande */
.s-link .s-label {
  opacity: 0; animation: sbFadeIn .22s ease .08s forwards;
}
body.menu-fechado .s-link .s-label { display: none; }

/* Rodapé do sidebar (user) -- sem padding lateral de propósito, igual
   .s-nav: assim o botão fica encostado nas bordas do sidebar exatamente
   como os itens de menu, e o avatar (absoluto, left:14px) cai na mesma
   posição de tela nos dois estados (aberto/fechado), sem precisar de
   nenhuma regra especial pra "recentralizar" quando fecha. */
.s-foot {
  padding: 8px 0; border-top: 1px solid rgba(255,255,255,.06); flex-shrink: 0;
}
.s-user-btn {
  display: block; /* <button> nasce inline-block por padrão -- isso deixa um
    respiro fantasma de baseline abaixo dele que muda de tamanho conforme o
    conteúdo interno (nome visível ou não), empurrando o avatar ~3px
    verticalmente entre os estados. .s-link (que nunca pula) já usa
    display:block; aqui precisa do mesmo. */
  width: 100%; height: 44px; padding-left: 52px; padding-right: 10px;
  border: none; border-radius: 14px; cursor: pointer;
  background: transparent; color: #71717A;
  font-size: 12px; font-weight: 500; text-align: left;
  line-height: 44px; white-space: nowrap; overflow: hidden;
  position: relative; transition: background .15s, color .15s;
}
.s-user-btn:hover { background: #18181B; color: #D4D4D8; }
.s-user-avatar {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  width: 28px; height: 28px; border-radius: 50%;
  background: var(--accent); color: #fff;
  font-size: 12px; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  line-height: 1;
}
.s-user-dd-sep { height: 1px; background: rgba(255,255,255,.08); margin: 4px 0; }
.s-user-name {
  opacity: 0; animation: sbFadeIn .22s ease .08s forwards;
}
body.menu-fechado .s-user-name { display: none; }

.s-user-dropdown {
  position: fixed; left: 8px; bottom: 60px;
  background: #18181B; border: 1px solid rgba(255,255,255,.08);
  border-radius: 20px; min-width: 200px;
  box-shadow: 0 16px 40px rgba(0,0,0,.4);
  padding: 6px; z-index: 500; display: none;
}
.s-user-dropdown.open { display: block; }
.s-user-dd-item {
  width: 100%; display: flex; align-items: center; gap: 10px;
  padding: 9px 12px; border-radius: 14px;
  border: none; background: transparent; cursor: pointer;
  color: #D4D4D8; font-size: 13px; font-weight: 500;
  text-align: left;
  transition: background .15s;
}
.s-user-dd-item:hover { background: rgba(255,255,255,.07); }
.s-user-dd-item.danger { color: #FCA5A5; }
.s-user-dd-item.danger:hover { background: rgba(220,38,38,.15); color: #fff; }

/* Conteúdo principal, empurrado pela largura da sidebar */
.main { flex: 1; margin-left: var(--sidebar-w-min); min-height: 100vh; display: flex; flex-direction: column; overflow: hidden; }
```

## JS de toggle

```js
document.getElementById('menu-toggle').addEventListener('click', function(){
  document.body.classList.toggle('menu-fechado');
});
```

`body` começa com a classe `menu-fechado` por padrão (sidebar colapsada ao carregar) — ver `<body class="menu-fechado">` no HTML do TopDealer.

## O bug que já resolvemos (não reintroduzir)

O avatar do usuário (e qualquer ícone fixo do menu) pulava de posição ao colapsar/expandir a sidebar. Levou 3 rodadas de debug pra achar a causa raiz de verdade:

1. **1ª tentativa (incompleta):** achamos que era um texto de versão (`.s-foot-ver`) mudando de `display:none` pra visível e empurrando o layout. Meio-resolvido com opacity em vez de display, mas o pulo continuou.
2. **2ª tentativa (ainda incompleta):** removemos o texto de versão inteiro. Pulo vertical sumiu, mas apareceu um pulo **horizontal** que estava mascarado antes.
3. **Causa raiz real:** o `.s-user-avatar` tinha uma regra especial `body.menu-fechado .s-user-avatar { position:static; transform:none; }` — uma tentativa de "recentralizar" o avatar quando a sidebar fica estreita. Isso é fundamentalmente diferente de como os ícones de menu (`.s-link .ico`) sempre funcionaram: eles são `position:absolute; left:14px` **nos dois estados, sem exceção**, e por isso nunca pulam.

**A lição, generalizada (vale pros dois dialetos, não só CSS `position:absolute`):** o elemento fixo da sidebar (ícone, avatar, badge) NUNCA deve ter sua própria geometria — posição, padding do container imediato, `left`/`gap` — condicionada ao estado colapsado/expandido. Só o rótulo de texto ao lado pode somar/sumir, via `opacity` (nunca mude o padding do container pra "compensar" o texto sumindo).

Nesse arquivo (Dialeto A, TopDealer/Hub) isso vira `position:absolute; left:14px` fixo nos dois estados, sem nenhuma regra `body.menu-fechado .algo { position:static; ... }` de "recentralizar". Se parece que precisa recentralizar, é sinal de que o padding lateral do container pai está diferente entre `.s-nav` e o container do elemento problemático (foi exatamente isso: `.s-foot` tinha padding lateral que `.s-nav` não tinha, deslocando o ponto de referência). Iguale os paddings dos containers-pai em vez de adicionar exceção de posicionamento no filho.

No Dialeto B (React-inline, PM/Padrões) o MESMO princípio aparece com outra sintaxe: o botão do avatar é uma `flex` row com `padding`/`gap` fixos nos dois estados, o Avatar é o primeiro filho (nunca se desloca), e só o `<div>` do nome ao lado tem `opacity: collapsed ? 0 : 1`. Funciona pelo mesmo motivo, sintaxe diferente — ver `dialects.md` pro código real desse caso.

Ao debugar um bug parecido: reproduza em um HTML isolado com o CSS REAL do arquivo (não uma aproximação escrita de memória), meça com `getBoundingClientRect()` nos dois estados, e confira **todos** os eixos (`top` E `left`) — um primeiro reparo que só olha um eixo pode "resolver" e deixar o outro escondido.

## Medidas de referência (conferidas lado a lado em 2026-10)

Hub, TopDealer e PM têm exatamente: sidebar **56px fechada / 240px aberta**; botão de menu 28px a 14px da borda; ícone 17px dentro de caixa 28px a `left:14px`; item de 40px de altura. Diferenças que existiam e foram igualadas: **logo expandida ~160px de largura** (TopDealer ~170, PM 159 via `height={13}`; a do Hub era 110px) e **avatar do rodapé 28–34px** (TD 28, PM 34, Hub 34; o centro do avatar fica no mesmo `x=28` do centro dos ícones). A barra azul de 3px do item ativo existe em **TODO** item ativo (inclusive "Configurações"), não só no primeiro.

**Se um app "parecer menor" que outro:** meça os dois com `getBoundingClientRect()` antes de mexer em CSS. Já aconteceu de ser só **zoom do navegador diferente por site** (Chrome/Edge guardam zoom por hostname; o Hub e os outros apps são hostnames diferentes) — tudo encolhia na mesma proporção (~0,89). Ctrl+0 no site resolve; não "ajuste a largura" por causa de uma queixa visual sem medir.

## Menu do avatar (todos os apps)

Itens: **"Voltar ao Hub"** (leva pra `https://deva.albusdata.com.br`) e **"Sair"**. Nunca "Meu perfil", "Alterar senha" ou "Trocar foto" dentro de um app — perfil, senha e foto são geridos só no Hub. No Hub o menu tem "Meu perfil" (foto) e "Sair".

## Responsivo (mobile)

Variante do Hub (confirmada): no celular/tablet o avatar sai da barra inferior e vira um botão **fixo no canto superior direito** (36px), sobre uma barra superior de 52px com a logo à esquerda; o menu do avatar abre logo abaixo dele (`position:fixed; top:58px; right:14px; max-width:calc(100vw - 28px)`), sempre dentro da tela — um popup posicionado em coordenadas do rodapé desktop "cortava pra fora da tela". A barra inferior fica só com as abas.

Abaixo de 768px de largura (ou landscape curto), a sidebar desktop some inteira e vira uma barra superior fixa + bottom nav:

```css
@media (max-width: 767px), (max-height: 768px) and (orientation: portrait) {
  .sidebar { display: none !important; }
  .main { margin-left: 0 !important; padding-top: 52px; padding-bottom: 74px; overflow-x: hidden; }
  .mobile-header { display: flex !important; }
  .mobile-bottom-nav { display: flex; }
}
```

```css
.mobile-header {
  display: none;
  position: fixed; top: 0; left: 0; right: 0;
  height: 52px; z-index: 200;
  align-items: center; justify-content: space-between;
  padding: 0 16px;
  background: var(--surface);
  border-bottom: 1px solid var(--line);
}
.mobile-avatar-btn {
  width: 36px; height: 36px; border-radius: 50%;
  border: none; background: var(--accent); color: #fff;
  font-size: 13px; font-weight: 700; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; line-height: 1;
}

.mobile-bottom-nav {
  display: none;
  position: fixed; bottom: 0; left: 0; right: 0;
  background: #fff; border-top: 1px solid #F1F5F9;
  box-shadow: 0 -2px 12px rgba(0,0,0,.05);
  z-index: 200;
  flex-direction: column;
}
.mobile-bottom-nav-row { display: flex; height: 64px; }
/* Reaproveita .s-link, só sobrescreve pra layout vertical (ícone em cima, label embaixo) */
.mobile-bottom-nav-row .s-link {
  flex: 1; min-width: 0; height: 100%;
  display: flex !important; flex-direction: column;
  align-items: center; justify-content: center; gap: 4px;
  padding: 0 !important; margin: 0 !important;
  background: transparent; color: #94A3B8;
  border-radius: 0; line-height: normal;
  font-size: 10px; font-weight: 700;
  position: relative;
}
.mobile-bottom-nav-row .s-link::before { display: none !important; }
.mobile-bottom-nav-row .s-link .ico {
  position: static !important; transform: none !important;
  width: 24px; height: 24px;
}
.mobile-bottom-nav-row .s-link .s-label {
  display: block !important; opacity: 1 !important; animation: none !important;
  font-size: 10px; font-weight: 700;
  max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  padding: 0 2px;
}
.mobile-bottom-nav-row .s-link.active { background: transparent; color: #1955FF; }
.mobile-nav-safe { height: max(10px, env(safe-area-inset-bottom)); flex-shrink: 0; }
```

O bottom nav reaproveita a mesma classe `.s-link` da sidebar desktop — os itens de menu no HTML são os MESMOS elementos (ou clones com o mesmo markup), só o CSS de contexto muda o layout de horizontal-com-label-ao-lado pra vertical-ícone-em-cima. Isso evita manter duas listas de menu divergentes.
