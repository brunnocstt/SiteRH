# Os dois dialetos de implementação — Deva/IVECO

Confirmado direto no código-fonte de **todos os quatro apps atuais** (Hub, TopDealer, ProjectManagementSite/PM, SitePadroes): existe UM padrão visual (cores, medidas, comportamento), mas DUAS sintaxes diferentes pra implementá-lo. Não confunda "dialeto diferente" com "padrão diferente" — os números batem entre os dois; só a forma de escrever o CSS muda.

## Dialeto A — CSS-classes (Hub, TopDealer)

`:root{ --accent:#1955FF; ... }` + classes reutilizáveis (`.s-nav`, `.s-link`, `.s-user-avatar`, etc.) num `<style>` global. É o que os outros arquivos de referência dessa skill (`design-tokens.md`, `sidebar.md`, `modal-pattern.md`) documentam por padrão.

## Dialeto B — React inline (ProjectManagementSite, SitePadroes)

Sem `:root` vars, sem classes CSS de componente. Em vez disso:
- Cor de marca como constante JS solta no topo do arquivo: `const BLUE = "#1955FF";` (confirmado em ambos, mesmo valor hex do Dialeto A — é o MESMO token, só sem virar variável CSS).
- Componentes React (JSX inline no HTML, sem build step) estilizados via `style={{...}}` direto em cada elemento, não classe.

Exemplo real (`SitePadroes/index.html`, sidebar):

```jsx
const W = collapsed ? 56 : 240; // mesmas medidas do Dialeto A (--sidebar-w/--sidebar-w-min)

<aside style={{
  width:W, flexShrink:0, background:"#0A0A0B",
  display:"flex", flexDirection:"column",
  overflow:"hidden", position:"sticky", top:0, zIndex:30,
}}>
  {/* item de nav */}
  <button style={{
    width:"100%", display:"block", height:40,
    paddingLeft:52, paddingRight:10,
    borderRadius:9, border:"none", cursor:"pointer",
    background: ativo ? "rgba(25,85,255,0.14)" : "transparent",
    color: ativo ? "#fff" : "rgb(113,113,122)",
  }}>
    <span style={{position:"absolute", left:14, top:"50%",
      transform:"translateY(-50%)", width:28, height:28,
      display:"flex", alignItems:"center", justifyContent:"center"}}>
      <Icon color={ativo ? BLUE : "currentColor"}/>
    </span>
    <span style={{opacity: collapsed ? 0 : 1}}>{label}</span>
  </button>
</aside>
```

`paddingLeft:52`, `borderRadius:9`, `rgba(25,85,255,.14)` de tint ativo, `#0A0A0B` de fundo — todos idênticos ao Dialeto A. O ícone também usa `position:absolute; left:14` igual ao `.s-link .ico` do Dialeto A.

## O avatar do rodapé: duas técnicas válidas pro mesmo princípio

O bug documentado em `sidebar.md` (avatar "pulando" ao colapsar/expandir) foi resolvido de formas *sintaticamente* diferentes nos dois dialetos — mas pelo mesmo princípio de fundo. Não trate a técnica do Dialeto A (`position:absolute`) como "a" solução; é uma de duas.

**Dialeto A (Hub/TopDealer):** avatar em `position:absolute; left:14px`, sem NENHUMA regra especial pro estado colapsado — o mesmo `left` nos dois estados.

**Dialeto B (PM/Padrões, os dois de forma independente):** avatar como primeiro filho de uma `flex` row cujo `padding`/`gap` NUNCA muda entre colapsado e expandido:

```jsx
<button style={{width:"100%", display:"flex", alignItems:"center", gap:10,
  padding:"6px 10px 6px 11px", /* fixo nos dois estados */ }}>
  <Avatar size={34}/>
  <div style={{flex:1, minWidth:0, overflow:"hidden", whiteSpace:"nowrap",
    opacity: collapsed ? 0 : 1, transition:"opacity 0.15s ease"}}>
    {nome}
  </div>
</button>
```

Quando colapsa, o `div` do nome não muda de padding nem de posição — só fica com `opacity:0` (some visualmente, mas ainda ocupa layout até o container encolher pelo `overflow:hidden`/`width` do `<aside>` pai). O Avatar, sendo o primeiro item da `flex` row com `gap`/`padding` fixos, nunca se desloca.

**O princípio geral (o que realmente importa, independente do dialeto):** o elemento fixo (avatar, ícone) nunca deve ter sua própria geometria (posição, padding do pai imediato) condicionada ao estado colapsado/expandido. Só o que soma/some é o rótulo de texto ao lado, via `opacity` (ou `display:none`, mas `opacity` evita reflow). Se você pegar um app de qualquer dialeto e ver uma regra tipo `if (collapsed) { /* muda posição ou padding do avatar/ícone */ }`, é sinal de bug — não importa se é uma classe CSS condicional ou um `style={{...: collapsed ? X : Y}}` no padding/position do próprio elemento fixo.

## Qual dialeto usar num app novo?

Se o app novo vai ser HTML+JS puro sem build step (como Hub/TopDealer) → Dialeto A, siga `sidebar.md`/`design-tokens.md` normalmente.

Se o app novo já nasce em React com JSX inline (como PM/Padrões, sem bundler) → Dialeto B é aceitável E já tem precedente funcionando em produção — não é preciso forçar `:root` vars/classes CSS num contexto React inline só pra "bater" com o Dialeto A. O que importa é que os VALORES (cores, medidas, raios) sejam os mesmos, documentados em `design-tokens.md`, e que o princípio de "geometria do elemento fixo não muda entre estados" seja respeitado — não a sintaxe exata.

## Antes de mexer num app existente

Primeiro identifique o dialeto: `grep -n ":root{" arquivo.html` (Dialeto A tem, Dialeto B não) ou `grep -n "const BLUE" arquivo.html` (Dialeto B tem essa constante solta, Dialeto A não costuma ter). Isso evita propor um diff que troca `style={{}}` por classe CSS (ou vice-versa) sem necessidade — mudança de sintaxe que não muda comportamento nenhum é só ruído no diff e risco de regressão à toa.
