<#
  Servidor local mínimo para testar a página sem publicar (sem Node nem Python).

  Uso:
    powershell -ExecutionPolicy Bypass -File scripts\servidor-local.ps1
  e abra http://localhost:8765

  Serve app\projur.html na raiz, envolvido no mesmo esqueleto HTML que o claude.ai
  acrescenta ao publicar, e os demais arquivos do repositório pelo caminho (ex.: /seed/all.js).
  Fora do claude.ai a página não tem banco de dados; veja no README como carregar os dados de teste.
#>
param([int]$Port = 8765)
$root = Split-Path -Parent $PSScriptRoot
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "Servindo $root em http://localhost:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext()
  $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
  if (-not $p) { $p = 'app/projur.html' }
  $f = Join-Path $root $p
  if ((Test-Path $f -PathType Leaf) -and (Resolve-Path $f).Path.StartsWith($root)) {
    $b = [IO.File]::ReadAllBytes($f)
    if ($f -like '*.html') {
      $c.Response.ContentType = 'text/html; charset=utf-8'
      $b = [Text.Encoding]::UTF8.GetBytes('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>' + [Text.Encoding]::UTF8.GetString($b) + '</body></html>')
    } else { $c.Response.ContentType = 'text/javascript; charset=utf-8' }
    $c.Response.OutputStream.Write($b, 0, $b.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
