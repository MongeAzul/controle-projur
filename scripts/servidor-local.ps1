<#
  Servidor local mínimo para testar a página antes de enviar ao GitHub Pages (sem Node nem Python).

  Uso:
    powershell -ExecutionPolicy Bypass -File scripts\servidor-local.ps1
  e abra http://localhost:8765

  Serve os arquivos do repositório como o GitHub Pages serviria (index.html na raiz).
  Com o config.js preenchido, a página usa o banco real do Supabase.
#>
param([int]$Port = 8765)
$root = Split-Path -Parent $PSScriptRoot
$tipos = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.svg' = 'image/svg+xml'; '.png' = 'image/png' }
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "Servindo $root em http://localhost:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext()
  $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
  if (-not $p) { $p = 'index.html' }
  $f = Join-Path $root $p
  if ((Test-Path $f -PathType Leaf) -and (Resolve-Path $f).Path.StartsWith($root)) {
    $b = [IO.File]::ReadAllBytes($f)
    $ext = [IO.Path]::GetExtension($f).ToLower()
    $c.Response.ContentType = $(if ($tipos[$ext]) { $tipos[$ext] } else { 'application/octet-stream' })
    $c.Response.OutputStream.Write($b, 0, $b.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
