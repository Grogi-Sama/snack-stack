param(
    [int]$Port = 8791,
    [string]$RootDir = (Split-Path -Parent $PSScriptRoot),
    [switch]$Public
)

Add-Type -AssemblyName System.Net.HttpListener -ErrorAction SilentlyContinue

$mimeMap = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
}

$listener = New-Object System.Net.HttpListener
if ($Public) {
    $listener.Prefixes.Add("http://+:$Port/")
} else {
    $listener.Prefixes.Add("http://localhost:$Port/")
}
$listener.Start()
if ($Public) {
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1 -ExpandProperty IPAddress)
    Write-Output "Serving $RootDir on http://localhost:$Port/ and http://${lanIp}:$Port/ (phone: use the LAN address)"
} else {
    Write-Output "Serving $RootDir on http://localhost:$Port/"
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        try {
            $relPath = [Uri]::UnescapeDataString($request.Url.AbsolutePath)
            if ($relPath -eq "/") { $relPath = "/prototype/index.html" }
            $fullPath = Join-Path $RootDir ($relPath -replace "^/", "")
            $fullPath = [System.IO.Path]::GetFullPath($fullPath)

            if (-not $fullPath.StartsWith([System.IO.Path]::GetFullPath($RootDir))) {
                $response.StatusCode = 403
                $response.Close()
                continue
            }

            if (Test-Path $fullPath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
                $mime = $mimeMap[$ext]
                if (-not $mime) { $mime = "application/octet-stream" }
                $bytes = [System.IO.File]::ReadAllBytes($fullPath)
                $response.ContentType = $mime
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
                $msg = [System.Text.Encoding]::UTF8.GetBytes("Not found: $relPath")
                $response.OutputStream.Write($msg, 0, $msg.Length)
            }
        } catch {
            $response.StatusCode = 500
        } finally {
            $response.Close()
        }
    }
} finally {
    $listener.Stop()
}
