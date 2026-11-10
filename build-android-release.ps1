[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$keyFile = if ($env:D2W_KEY_PROPERTIES) { $env:D2W_KEY_PROPERTIES } else { Join-Path $projectRoot 'android\key.properties' }
if (-not (Test-Path -LiteralPath $keyFile)) {
  throw 'The upload key is required. Complete android/key.properties first.'
}
$previousJava = $env:JAVA_HOME
try {
  if (-not $env:JAVA_HOME) {
    $studioJava = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path -LiteralPath (Join-Path $studioJava 'bin\java.exe')) { $env:JAVA_HOME = $studioJava }
  }
  & (Join-Path $projectRoot 'flutter-local.ps1') -FlutterArguments @('build', 'appbundle', '--release')
  $buildExit = $LASTEXITCODE
  if ($buildExit -ne 0) { throw "Android build failed with exit code $buildExit." }
  Write-Output (Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab')
} finally {
  $env:JAVA_HOME = $previousJava
}
