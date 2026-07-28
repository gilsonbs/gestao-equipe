# Gestão de Equipe

Dashboard interno para acompanhamento de equipe de farmácia: metas, vendas,
folgas e férias, aniversários e produtos mais vendidos.

O dashboard é **público** (leitura sem login) e o painel administrativo exige
autenticação. Construído em [Astro](https://astro.build) com
[Supabase](https://supabase.com) como banco, publicado em GitHub Pages.

- **Dashboard:** https://gilsonbs.github.io/gestao-equipe/
- **Admin:** https://gilsonbs.github.io/gestao-equipe/admin/

## Como funciona

O site é totalmente estático: o build gera HTML e o navegador conversa
diretamente com o Supabase usando a chave pública (`anon`). Não há servidor
próprio. Quem protege os dados é o Row Level Security do Postgres — leitura
liberada para todos, escrita apenas para usuários autenticados.

## Configuração inicial

### 1. Criar o banco no Supabase

Crie um projeto em [supabase.com](https://supabase.com), abra o **SQL Editor**
e execute o conteúdo de [`schema.sql`](./schema.sql). Isso cria as tabelas, a
view de desempenho, as políticas de RLS e os índices.

> **Já rodou uma versão anterior do schema?** Não execute o `schema.sql` de
> novo — isso apagaria os dados. Rode
> [`migrations/001-separa-metas-vendas.sql`](./migrations/001-separa-metas-vendas.sql),
> que converte o banco preservando o que já foi lançado.
>
> Para descobrir em que versão o banco está, veja
> [`migrations/diagnostico.sql`](./migrations/diagnostico.sql).

### 2. Criar o usuário administrador

O login do painel usa e-mail e senha, mas o schema **não** cria nenhum usuário.
No painel do Supabase: **Authentication → Users → Add user**, e preencha
e-mail e senha. Marque **Auto Confirm User** — sem isso o Supabase aguarda a
confirmação por e-mail e o login falha, exibindo apenas "E-mail ou senha
incorretos", sem indicar a causa real.

Repita para cada pessoa que precisar de acesso ao admin.

### 2.1. Desabilitar o cadastro público (obrigatório)

Em **Authentication → Sign In / Providers → Email**, desligue
**"Allow new users to sign up"**.

Isso não é opcional. O Supabase habilita o cadastro por e-mail por padrão, e
embora o app não tenha tela de cadastro, o endpoint `/auth/v1/signup` continua
acessível com a chave `anon` — que é pública e vai embutida no JavaScript do
site. Como as políticas de escrita liberam qualquer sessão autenticada:

```sql
USING ((select auth.role()) = 'authenticated')
```

...qualquer pessoa que encontrasse o site poderia criar a própria conta e
passar a editar funcionários, metas e vendas. Com o cadastro desligado,
existem apenas as contas criadas manualmente no painel.

Note que **não há distinção de permissão entre usuários do admin**: toda conta
autenticada pode escrever em todas as tabelas. Se um dia for preciso separar
papéis — quem só lança vendas de quem edita funcionários —, isso exige uma
tabela de perfis e políticas de RLS por papel.

### 3. Rodar localmente

Requer Node 22.12 ou superior.

```bash
npm install
cp .env.example .env
```

Preencha o `.env` com os valores de **Project Settings → API** no Supabase:

```
PUBLIC_SUPABASE_URL=https://seu-projeto.supabase.co
PUBLIC_SUPABASE_ANON_KEY=sua-chave-anon-publica
```

Depois:

```bash
npm run dev
```

A chave `anon` é pública por natureza — ela vai embutida no JavaScript
entregue ao navegador. Não confunda com a `service_role`, que **nunca** deve
aparecer neste projeto.

### 4. Configurar o deploy

Em **Settings → Secrets and variables → Actions**, crie os secrets:

| Secret | Valor |
|---|---|
| `PUBLIC_SUPABASE_URL` | URL do projeto Supabase |
| `PUBLIC_SUPABASE_ANON_KEY` | Chave `anon` pública |

Em **Settings → Pages → Build and deployment**, defina
**Source: GitHub Actions** — e não "Deploy from a branch". O sinal de que
está correto é o campo de branch desaparecer da tela.

Com a opção errada, o GitHub tenta construir o repositório com Jekyll, que
não entende arquivos `.astro` e falha com *"Invalid YAML front matter"*. E se
o Pages não estiver configurado como GitHub Actions, o job `deploy` termina
em segundos sem executar nenhum passo, porque o ambiente `github-pages` não
pode ser resolvido.

A partir daí, todo push na `main` dispara build e publicação.

## Comandos

| Comando | O que faz |
|---|---|
| `npm run dev` | Servidor de desenvolvimento em `localhost:4321` |
| `npm run check` | Verificação de tipos (`astro check`) |
| `npm run build` | Gera o site estático em `dist/` |
| `npm run preview` | Serve o build local para conferência |

## Modelo de dados

| Tabela | Guarda |
|---|---|
| `funcionarios` | Nome, cargo, data de nascimento, ativo/inativo |
| `metas` | Meta mensal pactuada por funcionário |
| `vendas_funcionario` | Valor efetivamente vendido por funcionário no mês |
| `vendas_loja` | Faturamento total da loja no mês |
| `folgas` | Folgas e férias, com data de início e fim |
| `produtos_top` | Produtos mais vendidos, com substância e categoria |

Meta e venda são tabelas **separadas** de propósito: um funcionário pode ter
meta sem ter vendido, ou vender sem ter meta definida. A view
`desempenho_mensal` junta as duas e calcula o percentual de atingimento.
Quando não há meta, o percentual é `NULL` — assim quem vendeu sem meta não
entra no cálculo da média do dashboard.

Tanto `metas` quanto `vendas_funcionario` têm
`UNIQUE(funcionario_id, mes, ano)`: existe no máximo um registro de cada por
funcionário por mês.

## Estrutura

```
src/
├── layouts/AdminLayout.astro   Casca do admin: menu lateral e proteção de rota
├── lib/
│   ├── supabase.ts             Cliente do Supabase e tipos das tabelas
│   └── dates.ts                Helpers de data (intervalo do mês, formatação)
├── pages/
│   ├── index.astro             Dashboard público
│   ├── 404.astro
│   └── admin/                  Login e telas de CRUD
└── styles/global.css           Design system: variáveis, botões, cards, tabelas
```

## Importar produtos por CSV

A tela **Top Produtos** aceita importação de planilha. O arquivo precisa ter
cabeçalho, e a única coluna obrigatória é `nome`:

```csv
nome,substancia,categoria,quantidade,mes,ano
Dipirona 500mg,Dipirona Monoidratada,Analgésico,320,4,2025
```

Vírgula e ponto e vírgula funcionam como separador. O arquivo é lido como
UTF-8 — se os acentos aparecerem quebrados, salve a planilha nesse formato
antes de importar.
