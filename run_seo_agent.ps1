# اجرای خودکار ایجنت سئو — مناسب برای Windows Task Scheduler (مثلاً هر ۳ ساعت)
#
# مسئولیت‌ها:
#   ۱) هم‌گام‌سازی با آخرین تغییرات روی GitHub
#   ۲) اجرای کامل ایجنت (تولید/ساخت/ممیزی/IndexNow/گزارش)
#   ۳) ثبت تغییرات و انتشار روی GitHub -> انتشار خودکار GitHub Pages
#
# توکن (اختیاری اما توصیه‌شده) به دو شکل قابل تنظیم است:
#   a) متغیر محیطی کاربر:
#        setx AZMOON_SEO_TOKEN "ghp_..."
#   b) یا در Windows Credential Manager:
#        cmdkey /generic:git:https://github.com /user:meysamabs /pass:ghp_...
# بدون توکن، اسکریپت از اعتبارنامه‌های پیش‌فرض git استفاده می‌کند.
#
# ساخت تسک در Task Scheduler:
#   $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
#              -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\Desktop\azmoon-yar-seo\run_seo_agent.ps1"'
#   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
#              -RepetitionInterval (New-TimeSpan -Hours 3) -RepetitionDuration (New-TimeSpan -Days 3650)
#   Register-ScheduledTask -TaskName "AzmoonYarSEOAgent" -Action $action -Trigger $trigger -Description "SEO agent - every 3h" -Force

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$agent = Join-Path $root "agent\seo_agent.dart"
$logDir = Join-Path $root "agent\out"
$log = Join-Path $logDir "scheduler.log"
$gitUser = "seo-agent"
$gitMail = "seo-agent@users.noreply.github.com"
$repoUrl = "https://github.com/meysamabs/azmoon-yar-seo.git"

function Log($m) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
  Write-Host $line
  Add-Content -Path $log -Value $line -Encoding UTF8
}

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  Log "خطا: Dart در PATH نیست. خروج."
  exit 1
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Push-Location $root
try {
  # ۱) هم‌گام‌سازی با آخرین تغییرات روی GitHub
  if ($env:AZMOON_SEO_TOKEN) {
    $auth = "https://x-access-token:$($env:AZMOON_SEO_TOKEN)@github.com/meysamabs/azmoon-yar-seo.git"
    git -c user.name=$gitUser -c user.email=$gitMail pull --rebase -X theirs $auth main *> $null
  } else {
    git -c user.name=$gitUser -c user.email=$gitMail pull --rebase -X theirs origin main *> $null
  }
  Log "هم‌گام‌سازی با GitHub انجام شد."

  # ۲) اجرای کامل ایجنت
  dart run $agent run *> $null
  Log "ایجنت سئو اجرا شد (تولید/ساخت/ممیزی/IndexNow/گزارش)."

  # ۳) ثبت تغییرات و انتشار
  git add -A
  git -c user.name=$gitUser -c user.email=$gitMail commit -m "chore(seo): اجرای خودکار $(Get-Date -Format 'yyyy-MM-dd HH:mm')" *> $null
  if ($env:AZMOON_SEO_TOKEN) {
    git -c credential.helper= push "https://x-access-token:$($env:AZMOON_SEO_TOKEN)@github.com/meysamabs/azmoon-yar-seo.git" main:main *> $null
  } else {
    git push origin main *> $null
  }
  Log "تغییرات منتشر شد."
} catch {
  Log "خطا: $($_.Exception.Message)"
} finally {
  Pop-Location
}