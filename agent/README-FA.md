# ایجنت سئو — راهنمای کامل

ایجنت با **Dart خالص** نوشته شده و **هیچ پکیج بیرونی** لازم ندارد. داخل خود پروژه‌ی Flutter اجرا می‌شود.

## اجرای سریع

```powershell
# ۱) ساخت فایل تنظیمات از نمونه
dart run agent/seo_agent.dart init

# ۲) ویرایش agent/config.json  (دامنه، لینک مایکت/بازار)

# ۳) اجرای همهٔ کارها (پیش‌فرض: حالت آزمایشی)
dart run agent/seo_agent.dart run
```

دستورهای تک‌تک:

| دستور | کار |
|---|---|
| `generate` | تولید پیش‌نویس مقاله از صف `keywords.json` |
| `build` | ساخت `sitemap.xml` و `robots.txt` از مقالات منتشرشده |
| `audit` | بررسی سئوی همهٔ صفحات HTML |
| `index` | پینگ IndexNow (Bing/Yandex) + ساخت فایل کلید |
| `rank` | ثبت جایگاه کلمات کلیدی (نیاز به `SERPAPI_KEY`) |
| `social` | انتشار مطلب در کانال تلگرام |
| `outreach` | ساخت پیش‌نویس پیام بک‌لینک |
| `report` | گزارش روزانه در `agent/out/` |
| `run` | اجرای همهٔ موارد فعال |

## حالت‌ها در `config.json`

- `dry_run: true` → **هیچ چیز بیرونی فرستاده نمی‌شود** (برای تست). بعد از آماده‌شدن `false` کن.
- `auto_publish: false` → مقاله با LLM ساخته می‌شود ولی **پیش‌نویس** می‌ماند (`noindex`) تا تو تأیید کنی.
  برای انتشار خودکار، `true` کن.
- `tasks.*` → هر کار را می‌توانی جدا روشن/خاموش کنی.

## کلیدها (فقط از متغیر محیطی، نه داخل فایل)

هیچ‌کدام اجباری نیست؛ هر کدام نبود، آن کار رد می‌شود و بقیه ادامه می‌یابند.

| متغیر | برای چه |
|---|---|
| `OPENAI_API_KEY` | تولید محتوا با LLM (بدون آن، قالب پیش‌نویس می‌سازد) |
| `OPENAI_BASE_URL` · `OPENAI_MODEL` | اگر سرویس دیگری (سازگار با OpenAI) استفاده می‌کنی |
| `INDEXNOW_KEY` | معرفی سریع آدرس‌ها به Bing و Yandex (یک رشتهٔ تصادفی) |
| `SERPAPI_KEY` | خواندن رتبهٔ واقعی گوگل |
| `TELEGRAM_BOT_TOKEN` · `TELEGRAM_CHAT_ID` | انتشار در تلگرام |
| `SMTP_*` · `MAIL_FROM` | ارسال ایمیل outreach (فعلاً فقط پیش‌نویس ساخته می‌شود) |

### روش تنظیم در ویندوز

```powershell
setx OPENAI_API_KEY "sk-..."
setx INDEXNOW_KEY "یک-رشته-تصادفی-32-کاراکتری"
# پنجرهٔ ترمینال را ببند و باز کن
```

## اجرای مداوم

### گزینهٔ ۱ — GitHub Actions (پیشنهادی)
فایل `.github/workflows/seo-agent.yml` آماده است و **هر روز ساعت ۰۷:۳۰ تهران** خودش اجرا می‌شود.
1. پروژه را به GitHub push کن.
2. در Settings → Secrets and variables → Actions، همان کلیدهای بالا را اضافه کن.
3. از تب Actions می‌توانی دستی هم اجرا کنی (workflow_dispatch).

### گزینهٔ ۲ — Windows Task Scheduler
```
Program:   powershell.exe
Arguments: -ExecutionPolicy Bypass -File "C:\مسیر\check_flutter\tool\run_seo_agent.ps1"
```
و زمان‌بندی روزانه بگذار.

## چرخهٔ کاری

```
keywords.json (todo)
      ↓  generate
   blog/*.html  ── پیش‌نویس (noindex)
      ↓  تأیید تو  → status = published
      ↓  build
   sitemap.xml
      ↓  index
   Bing/Yandex
      ↓  rank / report
   گزارش روزانه
```

## نکتهٔ صداقتی
هیچ‌کدام از این‌ها گوگل را «مجبور» نمی‌کند. ایجنت کارهای مجاز را **مداوم و منظم** انجام می‌دهد؛
نتیجه (رتبه) از ترکیب محتوای باکیفیت + بک‌لینک + برند می‌آید و زمان می‌برد.
