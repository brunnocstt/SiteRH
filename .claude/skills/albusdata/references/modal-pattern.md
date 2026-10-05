# Padrão de modal — Deva/IVECO

Fonte: `SiteHub/index.html` (`.modal-card`, `.modal-card-scroll`, usados em todos os modais do Hub: "Editar acesso", "Editar dados", "Adicionar pessoa", "Chaves" etc.). Esse padrão só chegou nessa forma depois de três bugs reais em produção — leia a seção "Por que essa estrutura" antes de "simplificar".

## Estrutura (HTML)

```html
<div class="modal-overlay" id="meu-modal" hidden>
  <div class="modal-card">
    <div class="modal-card-scroll">
      <div class="modal-head">
        <h2>Título do modal</h2>
        <button type="button" class="modal-close" id="meu-modal-close"><!-- ícone X --></button>
      </div>

      <!-- conteúdo do modal aqui -->

      <div class="modal-actions">
        <button type="button" class="btn btn-ghost">Cancelar</button>
        <button type="button" class="btn btn-primary">Salvar</button>
      </div>
    </div>
  </div>
</div>
```

Três camadas, cada uma com um papel único:
1. **`.modal-overlay`** — fundo escurecido, tela cheia, centraliza o card.
2. **`.modal-card`** — só a MOLDURA arredondada. Não rola. `overflow:hidden`.
3. **`.modal-card-scroll`** — onde o padding e o ÚNICO scroll de verdade do modal moram.

## CSS

```css
.modal-overlay{ position:fixed; inset:0; background:rgba(15,10,8,.45); z-index:300; display:flex; align-items:center; justify-content:center; padding:20px; }

/* a altura vem da própria tela do modal (overlay = área visível, com 20px de respiro), NÃO de 100vh:
   100vh pode ser maior que a janela real e o fim do conteúdo ficava cortado. */
.modal-card{ width:100%; max-width:420px; max-height:100%; display:flex; flex-direction:column; background:var(--surface); border-radius:32px; box-shadow:var(--shadow-lift); overflow:hidden; }
/* margin vertical = raio do canto (24px): a scrollbar começa/termina DEPOIS da curva do cartão, sem "poke" fora do arredondado.
   O padding lateral fica aqui; o respiro de cima/baixo é a própria margin. */
.modal-card-scroll{ flex:1 1 auto; min-height:0; overflow-y:auto; margin:24px 0; padding:0 24px; scrollbar-width:thin; scrollbar-color:var(--line-soft) transparent; }
.modal-card-scroll::-webkit-scrollbar{ width:9px; }
.modal-card-scroll::-webkit-scrollbar-track{ background:transparent; }
.modal-card-scroll::-webkit-scrollbar-thumb{ background-color:var(--line-soft); border-radius:999px; border:2.5px solid var(--surface); background-clip:padding-box; }
.modal-card-scroll::-webkit-scrollbar-thumb:hover{ background-color:var(--muted-2); }

.modal-head{ display:flex; align-items:center; justify-content:space-between; margin-bottom:18px; }
.modal-head h2{ font-size:1.1rem; font-weight:800; color:var(--ink); }
.modal-close{ all:unset; box-sizing:border-box; width:30px; height:30px; border-radius:12px; cursor:pointer; display:flex; align-items:center; justify-content:center; color:var(--muted); }
.modal-close:hover{ background:var(--surface-2); color:var(--ink); }
.modal-note{ font-size:.76rem; color:var(--muted-2); line-height:1.5; margin:4px 0 18px; }
.modal-actions{ display:flex; justify-content:flex-end; gap:10px; }
.modal-actions .btn{ width:auto; padding:11px 20px; }
```

## JS (abrir/fechar)

```js
var meuModal = document.getElementById('meu-modal');
function fecharMeuModal(){ meuModal.hidden = true; }
document.getElementById('meu-modal-close').addEventListener('click', fecharMeuModal);
meuModal.addEventListener('click', function(e){ if (e.target === meuModal) fecharMeuModal(); });
```

## Por que essa estrutura (dois bugs reais, não hipotéticos)

**Bug 1 — canto quadrado.** Um elemento com `border-radius` E `overflow-y:auto` ao mesmo tempo tem um problema visual real: a scrollbar nativa do navegador não respeita o raio do elemento em todos os navegadores/SOs — ela corta reto, deixando o canto onde ela fica (geralmente o direito) quadrado, enquanto o outro lado fica arredondado normalmente. Isso já aconteceu DUAS vezes nesse projeto: primeiro num checklist de filiais dentro de um modal, depois no próprio `.modal-card` inteiro quando o scroll "sobrou" nele.

**Fix:** nunca ponha `border-radius` + `overflow-y:auto` no MESMO elemento. Separe em dois: um de fora só com a moldura (`border-radius` + `overflow:hidden`, sem scroll próprio), um de dentro só com o scroll (`overflow-y:auto` + padding, sem `border-radius`). O de fora clipa (corta) visualmente o conteúdo do de dentro — incluindo a scrollbar — no formato arredondado certo, não importa como o navegador desenha a barra.

**Bug 2 — scroll dentro de scroll.** Numa correção anterior, o bug do canto foi resolvido dando esse tratamento de "moldura + scroll interno" pra uma SEÇÃO dentro do modal (um checklist longo), enquanto o modal inteiro TAMBÉM tinha seu próprio scroll (pra caber em telas pequenas). Resultado: dois scrolls aninhados, um dentro do outro — Bruno classificou isso, com razão, como "a pior UX que existe".

**Fix:** só pode existir UM scroll de verdade por modal. Se o modal inteiro já rola (`.modal-card-scroll`), nenhuma seção interna dele pode ter seu próprio `overflow-y:auto` — ela só cresce e empurra o conteúdo, e quem rola é sempre o modal como um todo. Se por algum motivo uma seção específica realmente precisar de scroll isolado (raro, e questionável — pergunte antes), pelo menos o resto do modal ao redor dela não pode rolar também.

**Bug 3 — scroll "vazando" do cartão (2026-10, visto na tela de chaves, com lista longa).** Duas causas juntas: (a) a altura do cartão/scroll era `calc(100vh - 40px)`, que pode ser MAIOR que a área visível da janela — o fim do conteúdo ficava cortado e a barra parecia sair do cartão; (b) a scrollbar corria o cartão inteiro, até os cantos arredondados, e a ponta dela aparecia fora da curva (mesmo com `overflow:hidden` na moldura, em alguns navegadores/SOs a ponta do thumb "pokeia" no canto). **Fix:** a altura vem do overlay (`max-height:100%` + `display:flex; flex-direction:column` no card, `flex:1; min-height:0` no scroller) e o scroller tem `margin:24px 0` (= raio do canto) pra a barra ficar inteira dentro da área reta do cartão. Se mudar o `border-radius` do card, mude a margin junto. Conferido medindo `getBoundingClientRect()` do card e do scroller (margem de 24px em cima e embaixo, último item visível ao rolar até o fim).

**Regra prática pra qualquer modal novo:** comece SEMPRE com a estrutura de três camadas acima. Não crie um scroll novo em nenhum elemento filho até ter certeza de que não existe outro scroll ativo nos ancestrais dele.
