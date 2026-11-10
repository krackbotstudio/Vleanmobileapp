[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$SdkPath = 'C:\Users\Karthik\Documents\ChatGPT\karthik\tools\flutter',
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$FlutterArguments
)
$ErrorActionPreference = 'Stop'
$dartExecutable = Join-Path $SdkPath 'bin\cache\dart-sdk\bin\dart.exe'
$toolSnapshot = Join-Path $SdkPath 'bin\cache\flutter_tools.snapshot'
if (-not (Test-Path -LiteralPath $toolSnapshot)) {
  throw 'Flutter tool snapshot is missing. Initialize your Flutter SDK first or provide -SdkPath.'
}
Push-Location $PSScriptRoot
try {
  & $dartExecutable $toolSnapshot --no-version-check --suppress-analytics @FlutterArguments
  $toolExitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $toolExitCode
