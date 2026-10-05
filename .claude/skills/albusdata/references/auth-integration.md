# Autenticação compartilhada — Deva/IVECO

Todo app do grupo compartilha UMA sessão de login através de um cookie no domínio `.albusdata.com.br`, gerenciada pelo Portal Deva (`deva.albusdata.com.br`, repo `SiteHub`) como hub central. Fonte: `SiteHub/index.html` e `SiteTopDealer/index.html`.

## O adaptador de cookie (idêntico em TODO app)

Por padrão o Supabase guarda a sessão no `localStorage`, que é isolado por origem/subdomínio — login feito em `deva.albusdata.com.br` não seria visto por `topdealerdeva.albusdata.com.br`. O fix é um `storage` customizado que usa cookie com `domain=.albusdata.com.br` em vez de `localStorage`:

```js
const DEVA_COOKIE_DOMAIN = '.albusdata.com.br';
const DEVA_STORAGE_KEY = 'sb-deva-auth';
function criarCookieStorage(domain){
  const emLocalhost = (location.hostname === 'localhost' || location.hostname === '127.0.0.1');
  const secure = (location.protocol === 'https:') ? '; Secure' : '';
  const dominio = emLocalhost ? '' : ('; domain=' + domain);
  function lerCookie(nome){
    const partes = ('; ' + document.cookie).split('; ' + nome + '=');
    if (partes.length < 2) return null;
    return decodeURIComponent(partes.pop().split(';').shift());
  }
  return {
    getItem: (key) => lerCookie(key),
    setItem: (key, value) => {
      document.cookie = key + '=' + encodeURIComponent(value) + dominio +
        '; path=/; max-age=' + (60*60*24*30) + '; SameSite=Lax' + secure;
    },
    removeItem: (key) => {
      document.cookie = key + '=' + dominio + '; path=/; max-age=0; SameSite=Lax' + secure;
    }
  };
}
```

**`DEVA_STORAGE_KEY` tem que ser EXATAMENTE `'sb-deva-auth'` em TODOS os apps.** Se um app usar uma storageKey diferente, ele lê/escreve um cookie diferente e a sessão simplesmente não é compartilhada — sem erro nenhum, só não funciona, o que é o pior tipo de bug pra debugar depois.

Uso no `createClient`:

```js
sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { storage: criarCookieStorage(DEVA_COOKIE_DOMAIN), storageKey: DEVA_STORAGE_KEY }
});
```

Se o app precisar de um schema Postgres não-`public` (caso de apps já migrados pro projeto consolidado, cada um no seu próprio schema), adiciona `db: { schema: 'nome_do_schema' }` no mesmo objeto de config. O schema precisa estar em "Exposed schemas" do projeto (API settings), senão o PostgREST responde que não existe.

**App em outro projeto Supabase (satélite):** a URL/anon do `createClient` de AUTENTICAÇÃO é sempre a do projeto principal (`iueakatarwkvaoomhhah`), com o mesmo cookie `sb-deva-auth`. Os dados do satélite NÃO são lidos direto com esse cliente: ver o desenho em `identidade-e-bancos.md` ("App satélite").

**Como obter a URL/chave do Supabase:** o TopDealer busca isso de uma Edge Function (`get-config`) em vez de hardcodar no HTML estático — evita expor a chave direto no código-fonte público, mesmo sendo uma chave "publishable"/anon (protegida por RLS, mas ainda assim). O Hub hardcoda direto. Qualquer uma das duas abordagens é aceitável; prefira `get-config` se o app for hospedado como site totalmente estático sem nenhum build step nem variável de ambiente.

## Duas fases: app com login próprio vs. app 100% dependente do Hub

Um app do grupo passa por duas fases ao longo do tempo:

**Fase 1 — app ainda não migrado pro Hub.** Tem tela de login própria, cria conta própria, mantém senha própria. Nessa fase, NÃO aplique a regra de "sem tela de login própria" abaixo — ela só faz sentido depois que o app depende 100% do Hub pra autenticação. Forçar um app fase 1 a redirecionar sem ter pra onde ir (Hub não conhece esse app ainda) quebra o login de todo mundo.

Estado real (atualizado em 2026-10): **TopDealer e PM já estão em Fase 2** (PM migrou pro projeto principal, no schema `pm`). **Ferramentaria e Padrões continuam em Fase 1 DE PROPÓSITO**: cada um tem projeto Supabase próprio (Ferramentaria deve migrar pro principal no começo do ano seguinte; Padrões fica em projeto separado e precisará do desenho de "app satélite" de `identidade-e-bancos.md` pra autenticar no principal). Isso é fila deliberada, não um bug pra "corrigir" de surpresa. Migrar um desses pra Fase 2 é um projeto à parte (schema + dados + contas + integração + conferência de que nenhum dado se perdeu), não um ajuste pontual de CSS/skill.

**Fase 2 — app já migrado, Hub é a única porta de entrada.** O app não tem MAIS tela de login própria nenhuma — nem formulário, nem botão "criar conta", nem "esqueci minha senha", nem "alterar senha". Todo mundo entra pelo Hub (e-mail + senha, ou "Entrar com Microsoft" quando o consentimento da SI sair). Essa é a fase de TopDealer e PM, e onde todo app novo que já nascer integrado deve começar direto. Detalhe do login do Hub: senha padrão `Deva@<ano>` no primeiro acesso com troca obrigatória feita no próprio Hub; reset por código de 6 dígitos por e-mail.

**Sessão vencida num app Fase 2:** os apps e o Hub compartilham o mesmo cookie e todos podem renovar o token. Se uma carga inicial falhar por sessão inválida (401/JWT), o app deve tentar `sb.auth.refreshSession()` uma vez e repetir; se a renovação falhar, redirecionar pro Hub. Nunca mostrar mensagem enganosa tipo "banco não configurado" — mostrar o motivo real do erro (ver `carregarBaseInicial` no TopDealer).

## Fase 2: login/logout sempre redireciona pro Hub, SEM `?next=`

Ao detectar que não há sessão válida (nem local, nem no cookie compartilhado), OU ao fazer logout, o app redireciona assim:

```js
window.location.replace('https://deva.albusdata.com.br');
```

**Decisão deliberada do Bruno: SEM `?next=` de propósito.** Uma versão anterior desse redirect passava `?next=` (URL de volta pro app), e o Hub reconhecia esse parâmetro pra mandar a pessoa direto de volta pro app assim que ela logasse — sem nem mostrar a tela do Hub. Bruno decidiu explicitamente MUDAR isso: quem entra direto pela URL de um app (ou desloga de dentro dele) deve cair no Hub, logar, e **precisar clicar no card do app** pra abrir — nunca ser jogado de volta sozinho. O objetivo é comportamental: acostumar todo mundo a usar o Hub como ponto de entrada único, não a URL direta de cada app.

Isso significa: se você reintroduzir um `?next=` nesse fluxo achando que está "melhorando a UX" (poupando um clique), está desfazendo uma decisão de produto deliberada. Não faça isso sem perguntar antes.

O mecanismo de `?next=` em si (ler `URLSearchParams`, validar que o hostname termina em `.albusdata.com.br` antes de aceitar redirecionar, pra nunca virar um open-redirect) ainda existe no código do Hub e é usado em outros contextos — só não é mais usado nesse fluxo específico de app→Hub.

## Boot-shell: evita o "flash" da tela de login

Problema real que já aconteceu: o HTML cru de um app nasce mostrando a tela de login por padrão. Só depois que o JS roda e confirma (via cookie compartilhado + uma consulta ao banco) que a pessoa JÁ está logada, é que a tela troca pro app de verdade. Nesse intervalo — que pode ser perceptível, não é instantâneo, principalmente se depender de uma consulta ao banco — a tela de login pisca visível pra quem já tem sessão válida, toda vez que ela recarrega a página.

**Fix:** uma tela neutra de "boot" (só um spinner, sem formulário nenhum) é o que aparece por padrão; a tela de login nasce ESCONDIDA (`hidden`), e só é mostrada explicitamente se/quando o app confirmar que realmente não há sessão.

```html
<div id="boot-shell" class="login-shell"><div class="boot-spinner"></div></div>
<div id="login-shell" class="login-shell" hidden>...</div>
```

```css
.boot-spinner{ width:32px; height:32px; border-radius:50%; border:3px solid var(--line-soft); border-top-color:var(--accent); animation:boot-spin .7s linear infinite; }
@keyframes boot-spin{ to{ transform:rotate(360deg); } }
```

```js
var bootShell = document.getElementById('boot-shell');
var loginShell = document.getElementById('login-shell');
// ...outras telas (appShell, etc.)

function esconderTodasAsTelas(){
  bootShell.hidden = true;
  loginShell.hidden = true;
  // ...esconder as outras também
}

sb.auth.onAuthStateChange(function(event, session){
  if (session) { showApp(session); } else { showLoginScreen(); }
});

function showLoginScreen(){
  esconderTodasAsTelas();
  loginShell.hidden = false;
}
```

**Ponto crítico:** se `showApp(session)` faz alguma consulta assíncrona ao banco antes de decidir o que mostrar (ex: checar se é admin, buscar nome/filial da pessoa), essa consulta deve rodar ENQUANTO o boot-shell ainda está visível — só chame `esconderTodasAsTelas()` DEPOIS que a consulta resolver, nunca antes. Se você esconder o boot-shell (ou mostrar a tela de login) antes da consulta terminar, o flash volta a acontecer, só que mascarado — vai parecer corrigido em testes rápidos (rede local, cache quente) e voltar a piscar em produção real com latência de rede.
