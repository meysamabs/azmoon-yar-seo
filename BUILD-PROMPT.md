# پرامپت ساخت / ادامهٔ پروژه — سایت سئوی اپ «آزمون یار»

> این متن، «پرامپت ساخت» است: آن را به هر هوش مصنوعی (یا نسخهٔ بعدی خودت) بده
> تا پروژه را بشناسد، بسازد یا ادامه‌اش دهد. همهٔ اطلاعات لازم اینجاست.

## هدف پروژه
ساخت و نگهداری یک **وب‌سایت عمومی سئو (لندینگ + وبلاگ)** برای اپلیکیشن اندروید «آزمون یار»
تا کاربران ایرانی هنگام جستجوی «آزمون آیین‌نامه»، «سوالات آیین‌نامه» و … آن را در گوگل پیدا
کنند و از طریق مایکت/کافه‌بازار اپ را نصب کنند. سایت باید **خودکار، روزبه‌روز و روی هاست رایگان** بماند.

## مشخصات اپ (واقعی — لینکش دست نزن)
- نام اپ: آزمون یار — آزمون آیین‌نامه رانندگی ۱۴۰۵ | توسعه‌دهنده: «اندروید پلاس»
- Package: `com.driver_azmon`
- مایکت: `https://myket.ir/app/com.driver_azmon`
- کافه‌بازار: `https://cafebazaar.ir/app/com.driver_azmon`
- امتیاز: ۴.۷ از ۵ (۸۵۷ نظر) | دانلود: حدود ۷۰ هزار | رایگان
- آیکون: `https://myket.ir/app-icon/8e05c29f-17bb-48fa-af7e-31900859fef7.png`
- اسکرین‌شات‌ها: `https://myket.ir/asset-files/screenshots/xlarge/com.driver_azmon/{972c1625-3f8f-4336-87da-6d82b131eb20|220fd043-929d-435c-8b51-71ffff9db3ed|929e07a6-fd85-43f3-992a-255c0791e3b5}.png`

## هاست و مخزن
- سایت لایو: `https://meysamabs.github.io/azmoon-yar-seo/`
- مخزن عمومی: `https://github.com/meysamabs/azmoon-yar-seo` (شاخهٔ اصلی: `main`)
- انتشار: GitHub Pages با `actions/deploy-pages` (build_type=workflow)، مجوزهای Actions: write
- آینهٔ اختیاری (فعلاً خاموش): Cloudflare Pages / Netlify با متغیرهای `ENABLE_CLOUDFLARE` و `ENABLE_NETLIFY`

## فناوری (مهم: محیط فقط Dart دارد)
- ایجنت سئو: **فقط Dart خالص (dart:io, dart:convert)** — بدون هیچ پکیج خارجی، بدون Python/Node
- پوستهٔ سایت: `assets/site.css` + فونت وزیرمتن هاست‌شده در `assets/fonts/` (۴ وزن woof2 با @font-face)
- Git + GitHub Actions برای کرون و Deploy

## ساختار فایل‌ها
```
index.html                        لندینگ (JSON-LD MobileApplication + FAQPage، دکمه‌های مایکت/بازار، ۸ کارت مقاله)
assets/site.css                   طراحی (light) مشترک لندینگ + بلاگ
assets/fonts/*.woff2              فونت وزیرمتن (هاست‌شده، بدون CDN)
blog/<slug>.html                  صفحات منتشرشدهٔ مقاله (تولید خودکار)
sitemap.xml / robots.txt / 404.html
agent/seo_agent.dart              ایجنت سئو (CLI زیر)
agent/config.json                 تنظیمات (domain، لینک‌ها، indexnow_key، dry_run، auto_publish، articles_per_run)
agent/keywords.json               صف مقالات (primary keywords + articles با status)
agent/content/<slug>.html         بدنهٔ واقعی مقالات (دست‌نویس — سورس حقیقت محتوا)
agent/state/                      خروجی rank / index و …
.github/workflows/publish.yml     کرون هر ۳ ساعت + اجرای ایجنت + انتشار Pages
run_seo_agent.ps1                 اجرای محلی (Windows Task Scheduler) — pull/run/commit/push
README-FA.md / agent/README-FA.md  مستندات
```

## دستورهای ایجنت سئو
از پوشهٔ پروژه: `dart run` در `C:\Users\Administrator\Desktop\azmoon-yar-seo`
```
dart run agent/seo_agent.dart init      ساخت config.json از مثال
dart run agent/seo_agent.dart run       تمام: generate → build → audit → index → rank → social → outreach → report
dart run agent/seo_agent.dart generate  تولید مقالات صف (به‌ترتیب content-file ← LLM ← قالب)
dart run agent/seo_agent.dart build     ساخت sitemap.xml (با lastmod) + robots.txt + syncDomain
dart run agent/seo_agent.dart audit     بررسی سئوی همهٔ صفحات
dart run agent/seo_agent.dart index     ارسال IndexNow برای همهٔ آدرس‌ها
```

## قوانین طلایی (در ادامهٔ کار رعایت کن)
1. **لینک‌ها همیشه نسبی و زیرمسیر-امن** باشند: سایت روی `/azmoon-yar-seo/` است؛ در index.html از
   `blog/x.html` و `assets/site.css` و `href="./"` استفاده کن، **نه** `/blog/...` یا `/assets/...`.
   در blog/ از `../assets/site.css` و `../` برای خانه و `x.html` برای مقالات هم‌دیرگ.
2. `syncDomain` هر بار `https://example.ir` را با دامنهٔ config جایگزین می‌کند (canonical/og یکسان).
3. مقاله با `noindex` فقط اگر draft باشد؛ فقط `published` وارد sitemap شود.
4. محتوا **فقط فارسی**، رسمی و با نیم‌فاصله؛ آمار/قوانین واقعی را **با احتیاط و hedging** بنویس
   (چون مقررات ممکن است تغییر کند، «بر اساس قوانین جاری» بنویس).
5. **برا افزودن مقاله:** (الف) بدنه را در `agent/content/<slug>.html` بنویس (sections با h2/h3/جدول)،
   (ب) در `agent/keywords.json` یک آیتم با `status: todo` اضافه کن، (ج) `dart run agent/seo_agent.dart generate`
   → محتوای دست‌نویس مستقیماً منتشر می‌شود (حتی بدون کلید LLM و بدون auto_publish).
6. فایل‌های فارسی را با ابزار write/edit دستکاری کن؛ **هرگز** با PowerShell `Get-Content|Set-Content`
   (دبل-encoding می‌شود). اسکریپت‌های .ps1 باید UTF-8 با BOM باشند.
7. `agent/out/` در .gitignore است (لاگ‌ها و خروجی موقتی).
8. قبل از push محلی: `git pull --rebase -X theirs` (کاریگروی روی main کامیت می‌کند).
   Token را در مخزن نگه ندار؛ از متغیر محیطی `AZMOON_SEO_TOKEN` یا Credential Manager استفاده کن.

## زمان‌بندی خودکار (فعال)
- GitHub Actions: `cron: '0 */3 * * *'` → هر ۳ ساعت: `dart run agent/seo_agent.dart run` + commit + Deploy Pages.
- Task Scheduler ویندوز: `AzmoonYarSEOAgent` → هر ۳ ساعت `run_seo_agent.ps1` (pull/run/commit/push).
- IndexNow key در config است (`indexnow_key`) و بعد از هر اجرا همهٔ آدرس‌ها ping می‌شوند.

## وضعیت فعلی (آخرین به‌روزرسانی)
- ۸ مقالهٔ منتشرشدهٔ واقعی در `agent/content/` + لندینگ؛ sitemap ۹ آدرس با `<lastmod>`.
- ممیزی همهٔ صفحات سالم (audit تمیز).
- صف articles خالی است (همه published) → بدون محتوای دست‌نویس یا LLM، اجرای خودکار چیزی جدید تولید نمی‌کند.

## بازمانده‌ها / گام‌های بعدی (به‌ترتیب اولویت)
1. **کلید LLM** (مثلاً `OPENAI_API_KEY` در GitHub Secrets) برای تولید مقالهٔ خودکار شبانه
   + فعال‌کردن `auto_publish: true` در config (فعلاً false تا محتوای قالب/LLMِ خام منتشر نشود).
2. **Google Search Console** (با حساب گوگل مالک سایت): افزودن ملک + `meta` تایید + request indexing + آپلود sitemap.
3. آینهٔ Cloudflare Pages / Netlify (در صورت تمایل، با `ENABLE_CLOUDFLARE=true` + Secrets مربوطه) برای سرعت در ایران.
4. دامنهٔ ایرانی دلخواه (مثلاً azmoon.ir) — در config `domain` عوض شود؛ syncDomain همه را درست می‌کند.
5. امنیت: توکن‌های اکسپوزشده را از GitHub revoke کن.

## کارهای رایج
- «مقالهٔ X را بنویس و منتشر کن» → مسیر بند ۵ قوانین طلایی.
- «سایت را چک کن» → `dart run agent/seo_agent.dart audit` و بررسی live با curl/code 200.
- «بگو چرا رتبه نمیاد» → بررسی keyword در گوگل، محتوای رقبا (test-drive.ir، govahiyar.ir، …) و backlink/محتوا.