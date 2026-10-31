# Controle PROJUR

Sistema de controle de processos e demandas da **Procuradoria Jurídica (PROJUR) da Câmara Municipal de Fortaleza**. Substitui a planilha "Controle PROJUR 2026".

O sistema publicado (acesso restrito a quem recebeu o link): https://claude.ai/artifact/Eyk9aXhZSAzZ5gmFV74Q92

## O que o sistema faz

- **Painel**: processos em aberto, recebidos e finalizados no período, tempo mediano de tramitação, processos parados há mais de 30 dias e prazos próximos. Gráficos de entradas e finalizações por mês, de recebidos por tipo e de carga por responsável, e uma lista do que precisa de atenção.
- **Processos**: busca em todos os campos e andamentos, filtros por tipo, responsável e situação, e exportação em CSV.
- **Ficha do processo**: dados, números classificados (interno, protocolo CMFOR360, CNJ, MP), prazo e linha do tempo de andamentos. Sugere o próximo número livre de Parecer e de Despacho e avisa quando um número já consta em outro processo.
- **Equipe**: carga atual e produção no ano por pessoa, e cadastro de férias e recessos. Quem estiver ausente aparece sinalizado na distribuição.

## Estrutura do repositório

```
app/projur.html               a aplicação inteira (HTML, CSS e JavaScript sem dependências)
scripts/importar-planilha.ps1 converte a planilha .xlsx em documentos JSON para o banco
scripts/servidor-local.ps1    servidor local para testar a página
.claude/launch.json           atalho do servidor local para o Claude Code
```

A pasta `seed/` (dados convertidos) e qualquer `.xlsx` ou `.csv` ficam **fora do repositório** pelo `.gitignore`, porque contêm dados reais de processos e de pessoas (LGPD).

## Como funciona

A página roda como um Artifact no claude.ai com três capacidades:

- `db`: banco de dados compartilhado com as coleções abaixo;
- `user`: informa se quem está vendo pode alterar os dados;
- `downloads`: permite a exportação em CSV.

| Coleção | Documento | Campos principais |
|---|---|---|
| `processos` | `p0001`… (importados) ou id aleatório (novos) | `seq`, `tipo`, `numeros[{tipo, valor}]`, `responsavel`, `chegada`, `prazo`, `situacao`, `descricao`, `andamentos[{data, texto}]`, `atualizadoEm`, `finalizadoEm`, `origem` |
| `equipe` | nome da pessoa sem acentos (`luis-humberto`) | `nome`, `ativo` |
| `ferias` | id aleatório | `pessoa`, `inicio`, `fim`, `tipo` |

As datas são gravadas como texto `aaaa-mm-dd`. As situações possíveis são: Em análise, Acompanhando, Esperando, Prazo aberto e Finalizado.

**Quem pode alterar:** quem recebe o link com nível **Colaborador** (Contributor) ou acima. Visualizadores só consultam e exportam.

## Importar a planilha

```powershell
powershell -ExecutionPolicy Bypass -File scripts\importar-planilha.ps1 -Path "C:\caminho\Controle PROJUR 2026.xlsx"
```

O script lê as abas "Controle" e "Férias e Recessos" e não precisa de Python nem Node. Ele separa a coluna "Descrição" em pedido + andamentos datados (trechos `- dd/mm/aaaa: texto`) e gera os arquivos em `seed/`. A carga no banco do Artifact foi feita com o Claude (ferramenta ArtifactData), em lotes de 50 documentos.

## Testar localmente

```powershell
powershell -ExecutionPolicy Bypass -File scripts\servidor-local.ps1
```

Abra http://localhost:8765. Fora do claude.ai não há banco de dados. Para ver a página com os dados importados, rode o script de importação e cole no console do navegador (F12):

```js
await new Promise((ok) => { const s = document.createElement("script"); s.src = "seed/all.js"; s.onload = ok; document.head.appendChild(s); });
S.procs = new Map(Object.entries(__SEED.procs)); S.ferias = __SEED.ferias; S.loaded = true; status(""); render();
```

## Publicar uma nova versão

Edite `app/projur.html` e peça ao Claude Code para republicar no mesmo endereço do Artifact acima. Os dados do banco são mantidos entre versões.

## Próximas etapas

- Prazos em dias úteis, descontando feriados municipais e recessos, com alertas
- Histórico de quem alterou o quê (auditoria)
- Excluir e vincular processos ("anexado ao processo X")
- Anexos (PDFs de pareceres e despachos)
- Consulta automática de processos judiciais pelo número CNJ (API pública DataJud do CNJ)
- Migração para um servidor da Câmara (Next.js + PostgreSQL), se for preciso sair do claude.ai
