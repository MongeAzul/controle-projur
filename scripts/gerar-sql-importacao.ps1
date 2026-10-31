<#
  Gera seed\importacao.sql a partir dos arquivos JSON de seed\ (criados por importar-planilha.ps1).

  Uso:
    powershell -ExecutionPolicy Bypass -File scripts\gerar-sql-importacao.ps1

  Depois, no Supabase: SQL Editor > New query > cole o conteúdo de seed\importacao.sql > Run.
  O arquivo contém dados reais e fica fora do Git (pasta seed\ está no .gitignore).
  Pode ser rodado de novo: processos, equipe e férias com o mesmo id são atualizados, não duplicados.
#>
param([string]$SeedDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'seed'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
# Texto entre $j$...$j$ dispensa escapar aspas; a sequência $j$ não ocorre nos dados.
function Lit($json) { if ($json.Contains('$j$')) { throw 'Texto contém $j$' }; return '$j$' + $json + '$j$' }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('-- Importação gerada por scripts/gerar-sql-importacao.ps1 em ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
[void]$sb.AppendLine('begin;')

$procs = Get-ChildItem $SeedDir -Filter 'p*.json' | Sort-Object Name
[void]$sb.AppendLine('insert into public.processos (id, seq, tipo, numeros, numero_texto, responsavel, chegada, prazo, situacao, descricao, andamentos, atualizado_em, finalizado_em, origem)')
[void]$sb.AppendLine('select id, seq, tipo, numeros, numero_texto, responsavel, chegada, prazo, situacao, descricao, andamentos, atualizado_em, finalizado_em, origem')
[void]$sb.AppendLine('from jsonb_to_recordset(' + (Lit ('[' + (($procs | ForEach-Object {
  $o = [IO.File]::ReadAllText($_.FullName, $utf8) | ConvertFrom-Json
  $fin = $null; if ($o.situacao -eq 'Finalizado') { $fin = $o.atualizadoEm }
  [ordered]@{
    id = $_.BaseName; seq = $o.seq; tipo = $o.tipo; numeros = @($o.numeros); numero_texto = $o.numeroTexto
    responsavel = $(if ($o.responsavel) { $o.responsavel } else { $null }); chegada = $o.chegada; prazo = $o.prazo
    situacao = $o.situacao; descricao = $o.descricao; andamentos = @($o.andamentos)
    atualizado_em = $o.atualizadoEm; finalizado_em = $fin; origem = $o.origem
  } | ConvertTo-Json -Depth 6 -Compress
}) -join ',') + ']')) + ')')
[void]$sb.AppendLine('  as x(id text, seq int, tipo text, numeros jsonb, numero_texto text, responsavel text, chegada date, prazo date, situacao text, descricao text, andamentos jsonb, atualizado_em date, finalizado_em date, origem text)')
[void]$sb.AppendLine('on conflict (id) do update set seq = excluded.seq, tipo = excluded.tipo, numeros = excluded.numeros, numero_texto = excluded.numero_texto,')
[void]$sb.AppendLine('  responsavel = excluded.responsavel, chegada = excluded.chegada, prazo = excluded.prazo, situacao = excluded.situacao, descricao = excluded.descricao,')
[void]$sb.AppendLine('  andamentos = excluded.andamentos, atualizado_em = excluded.atualizado_em, finalizado_em = excluded.finalizado_em, origem = excluded.origem;')
[void]$sb.AppendLine("select setval(pg_get_serial_sequence('public.processos', 'seq'), (select max(seq) from public.processos));")

$nomes = @{}
foreach ($f in $procs) { $r = ([IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json).responsavel; if ($r) { $nomes[$r] = 1 } }
$ferias = Get-ChildItem $SeedDir -Filter 'f*.json' | Sort-Object Name
foreach ($f in $ferias) { $nomes[([IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json).pessoa] = 1 }
foreach ($n in ($nomes.Keys | Sort-Object)) {
  $id = ($n.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '').ToLower() -replace '[^a-z0-9]+', '-'
  [void]$sb.AppendLine("insert into public.equipe (id, nome) values ('$($id.Trim('-'))', '$($n -replace "'", "''")') on conflict (id) do nothing;")
}
foreach ($f in $ferias) {
  $o = [IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json
  [void]$sb.AppendLine("insert into public.ferias (id, pessoa, inicio, fim, tipo) values ('$($f.BaseName)', '$($o.pessoa -replace "'", "''")', '$($o.inicio)', '$($o.fim)', '$($o.tipo -replace "'", "''")') on conflict (id) do update set pessoa = excluded.pessoa, inicio = excluded.inicio, fim = excluded.fim, tipo = excluded.tipo;")
}
[void]$sb.AppendLine('commit;')
[void]$sb.AppendLine('select (select count(*) from public.processos) as processos, (select count(*) from public.equipe) as equipe, (select count(*) from public.ferias) as ferias;')
$out = Join-Path $SeedDir 'importacao.sql'
[IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
"processos: $($procs.Count), equipe: $($nomes.Count), férias: $($ferias.Count) -> $out ($([math]::Round((Get-Item $out).Length / 1KB)) KB)"
