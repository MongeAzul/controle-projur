<#
  Converte a planilha "Controle PROJUR 2026.xlsx" em documentos JSON para o banco de dados do sistema.

  Uso:
    powershell -ExecutionPolicy Bypass -File scripts\importar-planilha.ps1 -Path "C:\caminho\Controle PROJUR 2026.xlsx"

  Gera, na pasta seed\ (ignorada pelo Git, pois contém dados reais):
    p0001.json ... pNNNN.json  um documento por processo (aba "Controle")
    f1.json ... fN.json        um documento por período de férias (aba "Férias e Recessos")
    all.js                     todos os dados num arquivo só, para testar a página localmente

  A coluna "Descrição" é separada em descrição do pedido + andamentos datados
  (trechos no formato "- dd/mm/aaaa: texto"). A coluna "Número do Processo" é
  dividida em números classificados: interno, protocolo CMFOR360, CNJ, MP ou outro.
  Não precisa de Python nem Node: lê o .xlsx direto com o .NET do Windows.
#>
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'seed')
)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$utf8 = New-Object System.Text.UTF8Encoding($false)
$z = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Path))
function ReadEntry($name) { $e = $z.Entries | Where-Object { $_.FullName -eq $name }; $r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close(); return $t }
[xml]$ss = ReadEntry 'xl/sharedStrings.xml'
$strings = @(); foreach ($si in $ss.sst.si) { $strings += $si.InnerText }
function SheetRows($sheet) {
  [xml]$sh = ReadEntry "xl/worksheets/$sheet.xml"
  foreach ($row in $sh.worksheet.sheetData.row) {
    $h = @{}
    foreach ($c in $row.c) {
      $v = $c.v
      if ($c.t -eq 's') { $v = $strings[[int]$v] } elseif ($c.t -eq 'inlineStr') { $v = $c.is.InnerText }
      $h[($c.r -replace '\d', '')] = ("$v" -replace '\s+', ' ').Trim()
    }
    $h['_r'] = [int]$row.r
    [pscustomobject]$h
  }
}
function OaDate($v) { if ($v -match '^\d+(\.\d+)?$') { return [DateTime]::FromOADate([double]$v).ToString('yyyy-MM-dd') } return $null }
function BrDate($s) {
  $p = $s -split '/'; $y = [int]$p[2]; if ($y -lt 100) { $y += 2000 }
  try { return (Get-Date -Year $y -Month ([int]$p[1]) -Day ([int]$p[0])).ToString('yyyy-MM-dd') } catch { return $null }
}
function Numeros($txt) {
  $out = @()
  foreach ($t in ($txt -split '\s+e\s+|,|;')) {
    $t = $t.Trim(); if (-not $t -or $t -match '^s/?n$') { continue }
    $tipo = 'outro'
    if ($t -match '^\d{20}$') { $tipo = 'protocolo' }
    elseif ($t -match '^\d{7}-\d{2}\.\d{4}\.\d\.\d{2}\.\d{4}$') { $tipo = 'cnj' }
    elseif ($t -match '^\d{1,5}/\d{4}$') { $tipo = 'interno' }
    elseif ($t -match '^\d{2}\.\d{4}\.\d+-\d$') { $tipo = 'mp' }
    $out += [ordered]@{ tipo = $tipo; valor = $t }
  }
  return , $out
}
function Andamentos($txt) {
  $rx = [regex]'(?:^|[\s;.,])-\s*(\d{1,2}/\d{1,2}/\d{2,4})\s*:?\s*'
  $ms = $rx.Matches($txt)
  if ($ms.Count -eq 0) { return @{ descricao = $txt.Trim(' ', '-', ';'); andamentos = @() } }
  $desc = $txt.Substring(0, $ms[0].Index).Trim(' ', '-', ';')
  $and = @()
  for ($i = 0; $i -lt $ms.Count; $i++) {
    $start = $ms[$i].Index + $ms[$i].Length
    $end = if ($i + 1 -lt $ms.Count) { $ms[$i + 1].Index } else { $txt.Length }
    $t = $txt.Substring($start, $end - $start).Trim(' ', '-', ';')
    $and += [ordered]@{ data = (BrDate $ms[$i].Groups[1].Value); texto = $t }
  }
  return @{ descricao = $desc; andamentos = $and }
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
$procs = @(); $ferias = @()
foreach ($r in (SheetRows 'sheet1')) {
  if ($r._r -eq 1 -or (-not $r.B -and -not $r.F)) { continue }
  $seq = [int][double]$r.A
  $parsed = Andamentos "$($r.F)"
  $chegada = OaDate $r.E
  $ult = $chegada
  foreach ($a in $parsed.andamentos) { if ($a.data -and (-not $ult -or $a.data -gt $ult)) { $ult = $a.data } }
  $doc = [ordered]@{
    seq = $seq; tipo = $r.B; numeros = (Numeros "$($r.C)"); numeroTexto = $r.C
    responsavel = $r.D; chegada = $chegada; descricao = $parsed.descricao
    andamentos = $parsed.andamentos; situacao = $(if ($r.G) { $r.G } else { 'Em análise' })
    prazo = $null; atualizadoEm = $ult; origem = 'planilha'
  }
  $id = 'p{0:D4}' -f $seq
  $json = $doc | ConvertTo-Json -Depth 6 -Compress
  [IO.File]::WriteAllText((Join-Path $OutDir "$id.json"), $json, $utf8)
  $procs += '"' + $id + '":' + $json
}
$i = 0
foreach ($r in (SheetRows 'sheet4')) {
  if ($r._r -lt 5 -or -not $r.B) { continue }
  $i++
  $json = [ordered]@{ pessoa = $r.B; inicio = (OaDate $r.C); fim = (OaDate $r.E); tipo = $r.F } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $OutDir "f$i.json"), $json, $utf8)
  $ferias += $json.Insert(1, '"_id":"f' + $i + '",')
}
$z.Dispose()
[IO.File]::WriteAllText((Join-Path $OutDir 'all.js'), 'window.__SEED={procs:{' + ($procs -join ',') + '},ferias:[' + ($ferias -join ',') + ']};', $utf8)
"processos: $($procs.Count), férias: $i -> $OutDir"
