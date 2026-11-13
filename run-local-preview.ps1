[CmdletBinding()]
param([switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$projectFolder = $PSScriptRoot
$runFolder = Join-Path $projectFolder '.local-run'
New-Item -ItemType Directory -Path $runFolder -Force | Out-Null
$dartExecutable = 'C:\Users\Karthik\Documents\ChatGPT\karthik\tools\flutter\bin\cache\dart-sdk\bin\dart.exe'
$toolSnapshot = 'C:\Users\Karthik\Documents\ChatGPT\karthik\tools\flutter\bin\cache\flutter_tools.snapshot'
$proxyScript = Join-Path $projectFolder 'tool\local_api_proxy.mjs'
$nodeExecutable = (Get-Command node -ErrorAction Stop).Source

function Stop-ManagedProcess([string]$label, [string]$expectedExecutable) {
    $pidFile = Join-Path $runFolder "$label-process.txt"
    if (-not (Test-Path -LiteralPath $pidFile)) { return }
    $managedPid = 0
    if (-not [int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$managedPid)) { throw "Invalid $label process record." }
    $process = Get-Process -Id $managedPid -ErrorAction SilentlyContinue
    if ($null -ne $process) {
        $recordTime = (Get-Item -LiteralPath $pidFile).LastWriteTime
        if ($process.Path -ne $expectedExecutable -or [math]::Abs(($process.StartTime - $recordTime).TotalSeconds) -gt 15) {
            throw "The saved $label process no longer matches this preview. No process was stopped."
        }
        # dart.exe starts a dartvm.exe child which owns the web server.
        # Stop the complete preview process tree before replacing it.
        try {
            & taskkill /PID $managedPid /T /F 2>$null | Out-Null
        } catch {
            $process.Kill()
        }
        $process.WaitForExit(5000) | Out-Null
    }
}

function Stop-PortListener([int]$port) {
    try {
        $lines = netstat -ano | Select-String ":$port\s+.*LISTENING\s+(\d+)"
        foreach ($line in $lines) {
            $pidMatch = $line.Matches[0].Groups[1].Value
            if ($pidMatch) {
                & taskkill /PID ([int]$pidMatch) /T /F 2>$null | Out-Null
            }
        }
    } catch { }
}

Stop-ManagedProcess 'flutter' $dartExecutable
Stop-ManagedProcess 'proxy' $nodeExecutable
Stop-PortListener 8780
Stop-PortListener 8781

$proxy = Start-Process -FilePath $nodeExecutable -ArgumentList 'tool\local_api_proxy.mjs' -WorkingDirectory $projectFolder -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $runFolder 'proxy-output.log') -RedirectStandardError (Join-Path $runFolder 'proxy-error.log') -PassThru
$proxy.Id | Set-Content -LiteralPath (Join-Path $runFolder 'proxy-process.txt')

# Release avoids the debug web-server blank page (DWDS / Dart Debug extension
# and the Flutter engine view-insets assert that can kill the first frame).
$dartArguments = @($toolSnapshot, '--no-version-check', '--suppress-analytics', 'run', '--release', '-d', 'web-server',
    '--web-hostname', '127.0.0.1', '--web-port', '8780', '--dart-define=API_BASE_URL=http://127.0.0.1:8781/api')
$flutter = Start-Process -FilePath $dartExecutable -ArgumentList $dartArguments -WorkingDirectory $projectFolder -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $runFolder 'flutter-output.log') -RedirectStandardError (Join-Path $runFolder 'flutter-error.log') -PassThru
$flutter.Id | Set-Content -LiteralPath (Join-Path $runFolder 'flutter-process.txt')

$ready = $false
$flutterLog = Join-Path $runFolder 'flutter-output.log'
for ($attempt = 0; $attempt -lt 120; $attempt++) {
    if ($flutter.HasExited -or $proxy.HasExited) { break }
    $served = $false
    if (Test-Path -LiteralPath $flutterLog) {
        $served = [bool](Select-String -LiteralPath $flutterLog -Pattern 'is being served' -Quiet -ErrorAction SilentlyContinue)
    }
    try {
        $site = Invoke-WebRequest -Uri 'http://127.0.0.1:8780/' -UseBasicParsing -TimeoutSec 2
        $bundle = Invoke-WebRequest -Uri 'http://127.0.0.1:8780/main.dart.js' -UseBasicParsing -TimeoutSec 2
        $health = Invoke-WebRequest -Uri 'http://127.0.0.1:8781/api/branding/public/Vclean' -UseBasicParsing -TimeoutSec 2
        $bundleReady = $bundle.StatusCode -eq 200 -and $bundle.RawContentLength -gt 50000
        if ($served -and $site.StatusCode -eq 200 -and $bundleReady -and $health.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch { }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    Get-Content -LiteralPath (Join-Path $runFolder 'flutter-error.log') -Tail 15 -ErrorAction SilentlyContinue
    Get-Content -LiteralPath (Join-Path $runFolder 'proxy-error.log') -Tail 15 -ErrorAction SilentlyContinue
    throw 'The local preview has not started. See .local-run for details.'
}
if (-not $NoBrowser) {
    Start-Process -FilePath 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ArgumentList @('--new-window','http://127.0.0.1:8780/')
}
Write-Output 'Vclean is running locally at http://127.0.0.1:8780/'
