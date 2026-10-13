# اجرای ایجنت سئو روی ویندوز (برای Windows Task Scheduler)
#
# ۱) یک بار اجرا کن تا config.json ساخته شود:
#    .\run_seo_agent.ps1 -Init
# ۲) در Task Scheduler یک تسک روزانه بساز با اکشن:
#    Program: powershell.exe
#    Arguments: -ExecutionPolicy Bypass -File "C:\Users\Administrator\Desktop\azmoon-yar-seo\run_seo_agent.ps1"

param(
  [switch]$Init,
  [switch]$DryRun,
  [string]$Command = "run"
)

$root = $PSScriptRoot
$agent = Join-Path $root "agent\seo_agent.dart"

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  Write-Error "Dart پیدا نشد. Flutter/Dart SDK را نصب یا به PATH اضافه کن."
  exit 1
}

Push-Location $root
try {
  if ($Init) {
    dart run $agent init
  } elseif ($DryRun) {
    dart run $agent $Command
  } else {
    dart run $agent $Command
  }
} finally {
  Pop-Location
}
