# Controle PROJUR

Sistema de controle de processos e demandas da **Procuradoria Jurídica (PROJUR) da Câmara Municipal de Fortaleza**. Substitui a planilha "Controle PROJUR 2026".

- **Página:** GitHub Pages, servindo `index.html` (só código, nenhum dado).
- **Dados e login:** Supabase (PostgreSQL). Só e-mails cadastrados na tabela `membros` entram.

## O que o sistema faz

- **Painel**: processos em aberto, recebidos e finalizados no período, tempo mediano de tramitação, processos parados há mais de 30 dias e prazos próximos. Gráficos de entradas e finalizações por mês, de recebidos por tipo e de carga por responsável, e uma lista do que precisa de atenção.
- **Processos**: busca em todos os campos e andamentos, filtros por tipo, responsável e situação, e exportação em CSV.
- **Ficha do processo**: dados, números classificados (interno, protocolo CMFOR360, CNJ, MP), prazo e linha do tempo de andamentos. Sugere o próximo número livre de Parecer e de Despacho e avisa quando um número já consta em outro processo.
- **Equipe**: carga atual e produção no ano por pessoa, e cadastro de férias e recessos. Quem estiver ausente aparece sinalizado na distribuição.
- **Acesso e histórico**: login por e-mail e senha, papéis de editor e leitor, e registro de toda inclusão, alteração e exclusão com o e-mail de quem fez (tabela `historico`).
- **Tempo real**: mudanças feitas por uma pessoa aparecem nas telas abertas das outras.

## Estrutura do repositório

```
index.html                       a aplicação (HTML, CSS e JavaScript; usa supabase-js pela CDN jsDelivr)
config.js                        endereço e chave pública do projeto Supabase
supabase/schema.sql              tabelas, regras de acesso (RLS), histórico e tempo real
scripts/importar-planilha.ps1    converte a planilha .xlsx em JSON (pasta seed/)
scripts/gerar-sql-importacao.ps1 gera seed/importacao.sql para carregar os dados no Supabase
scripts/servidor-local.ps1       servidor local para testar antes de publicar
```

A pasta `seed/` e qualquer `.xlsx` ou `.csv` ficam **fora do repositório** pelo `.gitignore`, porque contêm dados reais de processos e de pessoas (LGPD).

## Colocar no ar (uma vez)

### 1. Supabase

1. Crie uma conta em https://supabase.com e um projeto. Escolha a região **South America (São Paulo)** e guarde a senha do banco.
2. Abra **SQL Editor > New query**, cole o conteúdo de `supabase/schema.sql` e clique em **Run**.
3. Em **Authentication > Sign In / Providers**, desative **Allow new users to sign up**. Assim só entra quem você criar.
4. Em **Authentication > URL Configuration**, coloque o endereço do GitHub Pages em **Site URL** (ex.: `https://mongeazul.github.io/controle-projur/`). Isso faz o link de "Esqueci minha senha" voltar para o sistema.
5. Para cada pessoa da equipe:
   - em **Authentication > Users > Add user > Create new user**, informe o e-mail e uma senha provisória e marque **Auto Confirm User**;
   - em **Table Editor > membros > Insert row**, informe o mesmo e-mail, o nome e o papel (`editor` ou `leitor`).
6. Em **Project Settings > API**, copie a **Project URL** e a chave **anon public** para o `config.js`. Nunca use a chave `service_role`.

### 2. Dados da planilha

```powershell
powershell -ExecutionPolicy Bypass -File scripts\importar-planilha.ps1 -Path "C:\caminho\Controle PROJUR 2026.xlsx"
powershell -ExecutionPolicy Bypass -File scripts\gerar-sql-importacao.ps1
```

Abra `seed\importacao.sql`, copie tudo e rode numa nova consulta do **SQL Editor** do Supabase. O resultado mostra quantos processos, pessoas e períodos de férias foram carregados. O script pode ser rodado de novo sem duplicar nada.

### 3. GitHub Pages

O GitHub Pages só funciona com repositório **público** no plano gratuito. Com repositório privado, é preciso o GitHub Pro. Mesmo com o repositório público, os dados continuam protegidos: ficam no Supabase, atrás do login.

1. No GitHub, abra **Settings > Pages**.
2. Em **Source**, escolha **Deploy from a branch**, branch `main`, pasta `/ (root)`, e clique em **Save**.
3. Em um ou dois minutos, o sistema fica em `https://mongeazul.github.io/controle-projur/`.

## Banco de dados

| Tabela | Uso | Campos principais |
|---|---|---|
| `processos` | processos e demandas | `id`, `seq` (Id numérico, gerado pelo banco), `tipo`, `numeros` (jsonb), `responsavel`, `chegada`, `prazo`, `situacao`, `descricao`, `andamentos` (jsonb `[{data, texto}]`), `atualizado_em`, `finalizado_em`, `origem` |
| `equipe` | pessoas que recebem processos | `id`, `nome`, `ativo` |
| `ferias` | férias e recessos | `id`, `pessoa`, `inicio`, `fim`, `tipo` |
| `membros` | quem pode entrar | `email`, `nome`, `papel` (`editor` ou `leitor`) |
| `historico` | registro automático de alterações | `tabela`, `registro_id`, `acao`, `antes`, `depois`, `email`, `em` |

As regras de acesso estão em `supabase/schema.sql`:

- sem login, nada é visível;
- membros leem tudo;
- só quem tem papel `editor` inclui, altera ou exclui;
- a página nunca altera `membros` nem `historico`.

## Testar localmente

```powershell
powershell -ExecutionPolicy Bypass -File scripts\servidor-local.ps1
```

Abra http://localhost:8765. Com o `config.js` preenchido, a página usa o banco real e o mesmo login.

## Próximas etapas

- Tela de histórico de alterações por processo
- Prazos em dias úteis, descontando feriados municipais e recessos, com alertas por e-mail
- Excluir e vincular processos ("anexado ao processo X")
- Anexos (PDFs de pareceres e despachos) no Supabase Storage
- Consulta automática de processos judiciais pelo número CNJ (API pública DataJud do CNJ)

## Versão anterior

A primeira versão rodava como Artifact no claude.ai (https://claude.ai/artifact/Eyk9aXhZSAzZ5gmFV74Q92), com banco próprio. Está no histórico do Git (commit `4ef4795`, `app/projur.html`). Depois da migração, deixe de usá-la para não ter dados em dois lugares.
