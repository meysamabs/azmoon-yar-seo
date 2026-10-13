// SEO Agent — اجرای مداوم کارهای سئو برای اپ «آزمون یار»
//
// اجرا با Dart خالص و بدون هیچ وابستگی بیرونی:
//   dart run agent/seo_agent.dart init       // ساخت config.json از نمونه
//   dart run agent/seo_agent.dart run        // اجرای همهٔ کارهای فعال
//   dart run agent/seo_agent.dart generate   // فقط تولید پیش‌نویس مقاله
//   dart run agent/seo_agent.dart build      // ساخت sitemap و robots
//   dart run agent/seo_agent.dart audit      // بررسی سئوی صفحات
//   dart run agent/seo_agent.dart index      // معرفی آدرس‌ها (IndexNow)
//   dart run agent/seo_agent.dart rank       // ثبت رتبه/ایندکس کلمات
//   dart run agent/seo_agent.dart social     // انتشار در تلگرام
//   dart run agent/seo_agent.dart outreach   // ساخت پیش‌نویس بک‌لینک
//   dart run agent/seo_agent.dart report     // گزارش روزانه
//
// کلیدها از متغیرهای محیطی خوانده می‌شوند (هیچ رازی داخل فایل نیست):
//   OPENAI_API_KEY, OPENAI_BASE_URL, OPENAI_MODEL
//   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
//   SERPAPI_KEY, INDEXNOW_KEY
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// مسیرها
// ---------------------------------------------------------------------------

final String _agentDir = File.fromUri(Platform.script).parent.path;
final Directory _root = Directory(_agentDir).parent; // پوشهٔ seo
final String _configPath = '$_agentDir/config.json';
final String _examplePath = '$_agentDir/config.example.json';
final String _keywordsPath = '$_agentDir/keywords.json';
final String _targetsPath = '$_agentDir/outreach_targets.json';
final String _stateDir = '$_agentDir/state';
final String _outDir = '$_agentDir/out';

// ---------------------------------------------------------------------------
// ابزار پایه
// ---------------------------------------------------------------------------

void step(String m) => stdout.writeln('[•] $m');
void ok(String m) => stdout.writeln('[✓] $m');
void warn(String m) => stdout.writeln('[!] $m');
void fail(String m) => stderr.writeln('[✗] $m');

String? env(String key) {
  final v = Platform.environment[key];
  if (v == null || v.trim().isEmpty) return null;
  return v.trim();
}

DateTime nowUtc() => DateTime.now().toUtc();

String stamp() {
  final d = nowUtc();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return {};
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

void writeText(String path, String content) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content, encoding: utf8);
}

void writeJson(String path, Object data) =>
    writeText(path, const JsonEncoder.withIndent('  ').convert(data));

Future<String?> httpGet(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    warn('HTTP ${res.statusCode} GET $url');
    return null;
  } catch (e) {
    warn('خطای شبکه در GET $url: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<String?> httpPostJson(
  String url,
  Object body, {
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse(url));
    headers.forEach(req.headers.set);
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 200 && res.statusCode < 300) return text;
    warn('HTTP ${res.statusCode} POST $url — $text');
    return null;
  } catch (e) {
    warn('خطای شبکه در POST $url: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

String htmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// ---------------------------------------------------------------------------
// پیکربندی
// ---------------------------------------------------------------------------

class SiteCfg {
  final String domain, brand, siteDir, blogDir;
  SiteCfg(this.domain, this.brand, this.siteDir, this.blogDir);
}

class AppCfg {
  final String pkg, myket, bazaar, developer;
  AppCfg(this.pkg, this.myket, this.bazaar, this.developer);
}

class Agent {
  final Map<String, dynamic> cfg;
  Agent(this.cfg);

  SiteCfg get site {
    final s = (cfg['site'] as Map?)?.cast<String, dynamic>() ?? {};
    return SiteCfg(
      (s['domain'] ?? 'https://example.ir').toString().replaceAll(RegExp(r'/$'), ''),
      (s['brand'] ?? 'آزمون یار').toString(),
      (s['site_dir'] ?? '.').toString(),
      (s['blog_dir'] ?? 'blog').toString(),
    );
  }

  AppCfg get app {
    final a = (cfg['app'] as Map?)?.cast<String, dynamic>() ?? {};
    return AppCfg(
      (a['package'] ?? '').toString(),
      (a['myket'] ?? '').toString(),
      (a['bazaar'] ?? '').toString(),
      (a['developer'] ?? '').toString(),
    );
  }

  bool taskEnabled(String name) =>
      ((cfg['tasks'] as Map?)?[name] ?? true) == true;

  bool get dryRun => cfg['dry_run'] == true;
  bool get autoPublish => cfg['auto_publish'] == true;
  int limit(String key, int fallback) {
    final l = (cfg['limits'] as Map?)?[key];
    return l is int ? l : fallback;
  }

  String get sitePath => '${_root.path}${Platform.pathSeparator}${site.siteDir == '.' ? '' : site.siteDir}';

  String absUrl(String rel) => '${site.domain}/$rel';
  String pagePath(String rel) =>
      '${sitePath}${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}';
}

// ---------------------------------------------------------------------------
// کلمات کلیدی
// ---------------------------------------------------------------------------

Map<String, dynamic> loadKeywords() {
  final j = readJson(_keywordsPath);
  j['primary'] ??= <String>[];
  j['articles'] ??= <dynamic>[];
  return j;
}

// ---------------------------------------------------------------------------
// تولید محتوا
// ---------------------------------------------------------------------------

Future<String?> callLlm(Agent a, String prompt) async {
  final key = env('OPENAI_API_KEY');
  if (key == null) return null;
  final llm = (a.cfg['llm'] as Map?)?.cast<String, dynamic>() ?? {};
  if (llm['enabled'] == false) return null;

  final base = (env('OPENAI_BASE_URL') ?? llm['base_url'] ?? 'https://api.openai.com/v1')
      .toString()
      .replaceAll(RegExp(r'/$'), '');
  final model = env('OPENAI_MODEL') ?? (llm['model'] ?? 'gpt-4o-mini').toString();

  final res = await httpPostJson(
    '$base/chat/completions',
    {
      'model': model,
      'messages': [
        {'role': 'system', 'content': 'تو یک نویسندهٔ محتوای سئوی فارسی هستی. فقط HTML بدنه بده.'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.6,
    },
    headers: {'Authorization': 'Bearer $key'},
  );
  if (res == null) return null;
  try {
    final j = jsonDecode(res) as Map<String, dynamic>;
    return (j['choices'] as List).first['message']['content'] as String;
  } catch (e) {
    warn('پاسخ LLM قابل خواندن نبود: $e');
    return null;
  }
}

String fallbackBody(String keyword) {
  return '''
    <p>
      این صفحه یک پیش‌نویس ساختاریافته برای «${htmlEscape(keyword)}» است.
      تا وقتی محتوای واقعی نوشته نشود و وضعیت مقاله در <code>keywords.json</code>
      به <code>published</code> تغییر نکند، در sitemap قرار نمی‌گیرد.
    </p>
    <h2>مقدمه</h2>
    <p><!-- TODO: یک پاراگراف مقدمهٔ مفید و اصیل بنویس. --></p>
    <h2>مهم‌ترین نکات</h2>
    <ul>
      <li><!-- TODO --></li>
      <li><!-- TODO --></li>
      <li><!-- TODO --></li>
    </ul>
    <h2>اشتباه‌های رایج</h2>
    <p><!-- TODO --></p>
    <h2>پرسش‌های متداول</h2>
    <h3>سؤال اول؟</h3>
    <p><!-- TODO --></p>
    <h3>سؤال دوم؟</h3>
    <p><!-- TODO --></p>
  ''';
}

String articleHtml(Agent a, Map<String, dynamic> art, String body, {required bool published}) {
  final title = art['title']?.toString() ?? art['keyword'].toString();
  final keyword = art['keyword'].toString();
  final slug = art['slug'].toString();
  final desc = art['description']?.toString() ??
      '$title — راهنمای کامل، به‌روز و کاربردی در $keyword.';
  final url = a.absUrl('${a.site.blogDir}/$slug.html');
  final myket = htmlEscape(a.app.myket);
  final bazaar = htmlEscape(a.app.bazaar);

  final jsonLd = const JsonEncoder.withIndent('  ').convert({
    '@context': 'https://schema.org',
    '@type': 'Article',
    'headline': title,
    'description': desc,
    'inLanguage': 'fa',
    'mainEntityOfPage': url,
    'author': {'@type': 'Organization', 'name': a.app.developer},
    'publisher': {'@type': 'Organization', 'name': a.site.brand},
  });

  final icon =
      'https://myket.ir/app-icon/8e05c29f-17bb-48fa-af7e-31900859fef7.png';

  // مطالب مرتبط (لینک داخلی برای سئو) — همه در همان پوشهٔ blog قرار دارند.
  // توجه: در زمان تولید، وضعیت بقیهٔ مقاله‌ها ممکن است هنوز «todo» باشد،
  // پس مقاله‌ای که فایل محتوای دست‌نویس دارد هم منتشرشده در نظر گرفته می‌شود.
  final allArts = (loadKeywords()['articles'] as List)
      .cast<dynamic>()
      .map((e) => (e as Map).cast<String, dynamic>())
      .where((x) => x['slug']?.toString() != slug)
      .where((x) =>
          x['status'] == 'published' ||
          File('$_agentDir/content/${x['slug']}.html').existsSync())
      .take(3)
      .toList();
  final related = allArts.isEmpty
      ? ''
      : '''
    <section class="related">
      <h2>مطالب مرتبط</h2>
      <div class="grid">
${allArts.map((x) => '''        <a class="card" href="${x['slug']}.html">
          <h3>${htmlEscape(x['title']?.toString() ?? x['keyword'].toString())}</h3>
          <span class="post-more">ادامهٔ مطلب ←</span>
        </a>''').join('\n')}
      </div>
    </section>''';

  return '''<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${htmlEscape(title)} | ${htmlEscape(a.site.brand)}</title>
  <meta name="description" content="${htmlEscape(desc)}" />
  <link rel="canonical" href="$url" />
  <meta name="robots" content="${published ? 'index, follow' : 'noindex, follow'}" />
  <meta name="theme-color" content="#1e3a8a" />
  <link rel="icon" href="$icon" />
  <meta property="og:type" content="article" />
  <meta property="og:locale" content="fa_IR" />
  <meta property="og:title" content="${htmlEscape(title)}" />
  <meta property="og:description" content="${htmlEscape(desc)}" />
  <meta property="og:url" content="$url" />
  <meta property="og:image" content="$icon" />
  <script type="application/ld+json">
$jsonLd
  </script>
  <link rel="stylesheet" href="../assets/site.css" />
</head>
<body>

  <header class="topbar">
    <div class="wrap inner">
      <a class="brand" href="../">
        <img src="$icon" alt="لوگوی ${htmlEscape(a.site.brand)}" width="38" height="38" />
        <span>${htmlEscape(a.site.brand)}</span>
      </a>
      <nav class="topnav">
        <a href="../#articles">مقالات</a>
        ${myket.isEmpty ? '' : '<a class="topnav-cta" href="$myket" target="_blank" rel="noopener">دانلود رایگان</a>'}
      </nav>
    </div>
  </header>

  <main>
    <div class="article-head">
      <div class="wrap">
        <div class="breadcrumb">
          <a href="../">${htmlEscape(a.site.brand)}</a> ›
          <a href="../#articles">مقالات آموزشی</a>
        </div>
        <h1>${htmlEscape(title)}</h1>
        <p class="lead">${htmlEscape(desc)}</p>
      </div>
    </div>

    <div class="wrap">
      <article class="article-body">
$body
      </article>

      <div class="dl-card">
        <h3>آماده‌ای تمرین کنی؟</h3>
        <p>اپلیکیشن ${htmlEscape(a.site.brand)} رایگان است و آفلاین کار می‌کند: آزمون‌های ۳۰ سوالی، سوالات فنی، تابلوها و کارنامهٔ پیشرفت.</p>
        <div class="btns">
          ${myket.isEmpty ? '' : '<a class="btn btn-myket" href="$myket" rel="noopener">دریافت از مایکت</a>'}
          ${bazaar.isEmpty ? '' : '<a class="btn btn-bazaar" href="$bazaar" rel="noopener">دریافت از کافه‌بازار</a>'}
        </div>
      </div>
$related
    </div>
  </main>

  <footer class="site">
    <div class="wrap copy">
      <p>${htmlEscape(a.site.brand)} · سازنده: ${htmlEscape(a.app.developer)}</p>
    </div>
  </footer>
</body>
</html>
''';
}

String buildPrompt(String keyword, String brand) => '''
یک مقالهٔ کامل، اصیل و کاربردی به زبان فارسی دربارهٔ «$keyword» برای وب‌سایت «$brand» بنویس.

خروجی را **فقط به صورت HTML بدنه** بده (بدون تگ‌های html، head و body و بدون بلوک کد مارک‌داون).

ساختار:
- یک پاراگراف مقدمهٔ جذاب و صادقانه
- بین ۴ تا ۶ بخش با تگ <h2>
- در بخش‌ها از <ul>، <ol> و در صورت نیاز <table> استفاده کن
- در انتها بخش «پرسش‌های متداول» با ۳ پرسش (<h3>) و پاسخ
- طول حدود ۸۰۰ تا ۱۲۰۰ کلمه

قواعد:
- لحن آموزشی و صادقانه؛ هیچ وعدهٔ دروغ یا ادعای تأیید رسمی نده.
- کلمات کلیدی را به‌صورت طبیعی به کار ببر؛ از تکرار انبوه بپرهیز.
- هیچ لینکی به سایت‌های دیگر نگذار.
''';

Future<void> taskGenerate(Agent a) async {
  final kw = loadKeywords();
  final articles = (kw['articles'] as List).cast<dynamic>();
  final todo = articles.where((e) => (e as Map)['status'] == 'todo' || (e as Map)['status'] == null).toList();
  if (todo.isEmpty) {
    step('مقاله‌ای در صف نیست.');
    return;
  }

  final n = a.limit('articles_per_run', 1);
  final useLlm = env('OPENAI_API_KEY') != null;
  step('تولید ${todo.length} پیش‌نویس در صف — این اجرا $n مورد${useLlm ? ' با LLM' : ' با قالب (بدون کلید LLM)'}');

  var made = 0;
  for (final raw in todo) {
    if (made >= n) break;
    final art = (raw as Map).cast<String, dynamic>();
    final keyword = art['keyword'].toString();
    final slug = art['slug'].toString();

    // اگر برای این مقاله یک بدنهٔ دست‌نویس در agent/content/<slug>.html باشد،
    // همان استفاده می‌شود (کیفیت بالاتر از قالب و از LLMِ بدون تنظیم دقیق).
    final localFile = File('$_agentDir/content/$slug.html');
    final fromFile = localFile.existsSync();

    String? body = fromFile ? localFile.readAsStringSync() : null;
    if (body == null && useLlm) body = await callLlm(a, buildPrompt(keyword, a.site.brand));
    final fromLlm = body != null && !fromFile;
    body ??= fallbackBody(keyword);

    // مقالهٔ دست‌نویس مستقیماً منتشر می‌شود؛ مقالهٔ LLM فقط با auto_publish.
    final published = fromFile || (fromLlm && a.autoPublish);
    writeText(a.pagePath('${a.site.blogDir}/$slug.html'),
        articleHtml(a, art, body, published: published));

    art['status'] = published ? 'published' : 'draft';
    art['generated_at'] = nowUtc().toIso8601String();
    art['file'] = '${a.site.blogDir}/$slug.html';
    ok('مقاله: ${a.site.blogDir}/$slug.html  (${published ? 'منتشرشده' : 'پیش‌نویس'})');
    made++;
  }

  writeJson(_keywordsPath, kw);
}

// ---------------------------------------------------------------------------
// ساخت سایت: sitemap و robots
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> publishedArticles() {
  final kw = loadKeywords();
  return (kw['articles'] as List)
      .cast<dynamic>()
      .map((e) => (e as Map).cast<String, dynamic>())
      .where((e) => e['status'] == 'published')
      .toList();
}

void taskBuild(Agent a) {
  syncDomain(a);
  final urls = <String>[a.absUrl('')];
  for (final art in publishedArticles()) {
    urls.add(a.absUrl('${a.site.blogDir}/${art['slug']}.html'));
  }

  final buf = StringBuffer();
  buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buf.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final u in urls) {
    buf.writeln('  <url>');
    buf.writeln('    <loc>${htmlEscape(u)}</loc>');
    buf.writeln('    <changefreq>weekly</changefreq>');
    buf.writeln('    <priority>${u == a.absUrl('') ? '1.0' : '0.8'}</priority>');
    buf.writeln('  </url>');
  }
  buf.writeln('</urlset>');
  writeText(a.pagePath('sitemap.xml'), buf.toString());

  writeText(
    a.pagePath('robots.txt'),
    'User-agent: *\n'
    'Allow: /\n'
    'Disallow: /agent/\n'
    'Disallow: /*.dart\$\n'
    '\n'
    'Sitemap: ${a.absUrl('sitemap.xml')}\n',
  );

  ok('sitemap.xml ساخته شد (${urls.length} آدرس) و robots.txt به‌روز شد.');
}

/// اگر دامنه در config تغییر کرده باشد، همان را در لندینگ هم به‌روز می‌کند
/// تا canonical و og:url همه‌جا یکسان باشند (جلوگیری از محتوای تکراری).
void syncDomain(Agent a) {
  final f = File(a.pagePath('index.html'));
  if (!f.existsSync()) return;
  var html = f.readAsStringSync();
  if (html.contains('example.ir')) {
    html = html.replaceAll('https://example.ir', a.site.domain);
    f.writeAsStringSync(html, encoding: utf8);
    ok('دامنه در index.html به «${a.site.domain}» به‌روز شد.');
  }
}

// ---------------------------------------------------------------------------
// بررسی سئوی صفحات
// ---------------------------------------------------------------------------

String? _tag(String html, RegExp re) {
  final m = re.firstMatch(html);
  return m == null ? null : m.group(1)?.trim();
}

void taskAudit(Agent a) {
  final dir = Directory(a.sitePath);
  if (!dir.existsSync()) {
    warn('پوشهٔ سایت پیدا نشد: ${a.sitePath}');
    return;
  }
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.html'))
      // فایل‌های محتوای ایجنت، قطعهٔ HTML هستند نه صفحهٔ کامل؛ بررسی نمی‌شوند.
      .where((f) => !f.path.replaceAll('\\', '/').contains('/content/'))
      .toList();

  final issues = <String>[];
  for (final f in files) {
    final html = f.readAsStringSync();
    final rel = f.path.startsWith(a.sitePath)
        ? f.path.substring(a.sitePath.length)
        : f.path;
    final name = rel.replaceAll(RegExp(r'^[\\/]+'), '');
    if (name == '404.html') continue; // صفحهٔ خطا نیازی به canonical و description ندارد
    final title = _tag(html, RegExp(r'<title>(.*?)</title>', dotAll: true));
    final desc = _tag(html, RegExp(r'<meta name="description" content="(.*?)"', dotAll: true));
    final h1 = RegExp(r'<h1[ >]').allMatches(html).length;

    if (title == null || title.length < 15 || title.length > 70) {
      issues.add('$name — طول عنوان مناسب نیست (${title?.length ?? 0})');
    }
    if (desc == null || desc.length < 70 || desc.length > 170) {
      issues.add('$name — طول meta description مناسب نیست (${desc?.length ?? 0})');
    }
    if (h1 != 1) issues.add('$name — تعداد <h1> باید دقیقاً ۱ باشد (فعلی: $h1)');
    if (!html.contains('canonical')) issues.add('$name — تگ canonical ندارد');
    if (!html.contains('lang="fa"')) issues.add('$name — lang="fa" ندارد');
  }

  if (issues.isEmpty) {
    ok('بررسی سئو: همهٔ ${files.length} صفحه سالم‌اند.');
  } else {
    warn('بررسی سئو: ${issues.length} مورد در ${files.length} صفحه:');
    for (final i in issues) {
      stdout.writeln('    • $i');
    }
  }
  writeText('$_stateDir/audit-${stamp()}.txt', issues.join('\n'));
}

// ---------------------------------------------------------------------------
// معرفی آدرس‌ها به موتور جست‌وجو
// ---------------------------------------------------------------------------

Future<void> taskIndex(Agent a) async {
  final urls = <String>[a.absUrl('')];
  for (final art in publishedArticles()) {
    urls.add(a.absUrl('${a.site.blogDir}/${art['slug']}.html'));
  }

  // کلید IndexNow عمومی است (در /KEY.txt منتشر می‌شود)، پس از env یا config خوانده می‌شود.
  final key = env('INDEXNOW_KEY') ?? a.cfg['indexnow_key']?.toString();
  if (key != null && key.isNotEmpty) {
    writeText(a.pagePath('$key.txt'), key);
    if (a.dryRun) {
      step('DRY-RUN: IndexNow ارسال نشد (${urls.length} آدرس).');
    } else {
      final res = await httpPostJson('https://api.indexnow.org/indexnow', {
        'host': Uri.parse(a.site.domain).host,
        'key': key,
        'keyLocation': a.absUrl('$key.txt'),
        'urlList': urls,
      });
      ok('IndexNow: ${res == null ? 'بدون پاسخ' : 'ارسال شد'} (${urls.length} آدرس).');
    }
  } else {
    warn('INDEXNOW_KEY تنظیم نشده — پینگ موتورها رد شد.');
  }

  // خطاهای احتمالی ساختار سایت
  if (urls.length == 1) {
    warn('هیچ مقالهٔ منتشرشده‌ای وجود ندارد؛ فقط صفحهٔ اصلی معرفی می‌شود.');
  }
}

// ---------------------------------------------------------------------------
// رتبه و ایندکس
// ---------------------------------------------------------------------------

Future<void> taskRank(Agent a) async {
  final kw = loadKeywords();
  final primary = (kw['primary'] as List).map((e) => e.toString()).toList();
  if (primary.isEmpty) {
    warn('لیست primary در keywords.json خالی است.');
    return;
  }

  final serpKey = env('SERPAPI_KEY');
  final result = <String, dynamic>{
    'date': nowUtc().toIso8601String(),
    'domain': Uri.parse(a.site.domain).host,
    'keywords': <dynamic>[],
  };

  for (final q in primary) {
    final entry = <String, dynamic>{'keyword': q};

    if (serpKey != null && !a.dryRun) {
      final url = 'https://serpapi.com/search.json?engine=google'
          '&gl=ir&hl=fa&num=30'
          '&q=${Uri.encodeQueryComponent(q)}'
          '&api_key=$serpKey';
      final body = await httpGet(url);
      if (body != null) {
        try {
          final j = jsonDecode(body) as Map<String, dynamic>;
          final organic = (j['organic_results'] as List?) ?? [];
          int? myPos;
          for (final r in organic) {
            final link = (r['link'] ?? '').toString();
            final hitPkg = a.app.pkg.isNotEmpty && link.contains(a.app.pkg);
            final hitMyket = a.app.myket.isNotEmpty && link.contains(a.app.myket);
            if (hitPkg || hitMyket) {
              myPos = r['position'] as int?;
              break;
            }
          }
          entry['position'] = myPos;
          entry['top'] = organic.take(3).map((r) => r['link'].toString()).toList();
        } catch (e) {
          entry['error'] = 'پاسخ نامعتبر';
        }
      }
    } else {
      entry['position'] = null;
      entry['note'] = serpKey == null ? 'SERPAPI_KEY تنظیم نشده' : 'dry-run';
    }
    result['keywords'].add(entry);
  }

  writeText('$_stateDir/rank-${stamp()}.json',
      const JsonEncoder.withIndent('  ').convert(result));
  ok('رتبهٔ ${primary.length} کلمه ثبت شد در state/rank-${stamp()}.json');
}

// ---------------------------------------------------------------------------
// انتشار در تلگرام
// ---------------------------------------------------------------------------

Future<void> taskSocial(Agent a) async {
  final token = env('TELEGRAM_BOT_TOKEN');
  final chat = env('TELEGRAM_CHAT_ID');
  if (token == null || chat == null) {
    warn('TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID تنظیم نشده — انتشار رد شد.');
    return;
  }

  final latest = publishedArticles().isEmpty ? null : publishedArticles().last;
  final text = latest == null
      ? '«${a.site.brand}» — سوالات و آزمون‌های آیین‌نامه رانندگی\n${a.app.myket}'
      : 'مطلب جدید: ${latest['title']}\n${a.absUrl('${a.site.blogDir}/${latest['slug']}.html')}';

  if (a.dryRun) {
    step('DRY-RUN: پیام تلگرام ارسال نشد:\n$text');
    return;
  }

  final res = await httpPostJson(
    'https://api.telegram.org/bot$token/sendMessage',
    {'chat_id': chat, 'text': text, 'disable_web_page_preview': false},
  );
  res == null ? warn('ارسال تلگرام ناموفق بود.') : ok('پیام تلگرام ارسال شد.');
}

// ---------------------------------------------------------------------------
// پیش‌نویس بک‌لینک (outreach)
// ---------------------------------------------------------------------------

void taskOutreach(Agent a) {
  final data = readJson(_targetsPath);
  final targets = ((data['targets'] as List?) ?? []).cast<dynamic>();
  if (targets.isEmpty) {
    warn('فایل outreach_targets.json خالی است — هدفی برای پیام نیست.');
    return;
  }

  final n = a.limit('outreach_per_run', 3);
  final outSub = '$_outDir${Platform.pathSeparator}outreach';
  var made = 0;

  for (final raw in targets) {
    if (made >= n) break;
    final t = (raw as Map).cast<String, dynamic>();
    if (t['sent'] == true) continue;

    final siteName = (t['site'] ?? '').toString();
    final url = (t['url'] ?? a.app.myket).toString();
    final reason = (t['reason'] ?? 'معرفی اپلیکیشن مرتبط').toString();
    final slug = siteName.replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), '-');

    final mail = '''موضوع: معرفی اپلیکیشن «${a.site.brand}» برای صفحهٔ «$siteName»

سلام،
وقت شما بخیر.

من سازندهٔ «${a.site.brand}» هستم؛ یک اپلیکیشن اندروید که ${reason}.
اگر فکر می‌کنید برای مخاطبان «$siteName» مفید است، خوشحال می‌شوم در صفحهٔ زیر به آن اشاره کنید:

$url

اگر مایل بودید، توضیح کوتاه و تصاویر آماده را هم ارسال می‌کنم. سپاس از وقتی که گذاشتید.

${a.app.developer}
''';
    writeText('$outSub${Platform.pathSeparator}$slug.md', mail);
    ok('پیش‌نویس پیام برای «$siteName» ساخته شد.');
    made++;
  }

  if (made == 0) step('پیام جدیدی لازم نبود.');
}

// ---------------------------------------------------------------------------
// گزارش
// ---------------------------------------------------------------------------

void taskReport(Agent a) {
  final states = Directory(_stateDir).existsSync()
      ? Directory(_stateDir).listSync().whereType<File>().toList()
      : <File>[];
  final drafts = (loadKeywords()['articles'] as List)
      .cast<dynamic>()
      .map((e) => (e as Map))
      .where((e) => e['status'] == 'draft')
      .length;
  final pub = publishedArticles().length;

  final md = '''
# گزارش سئو — ${stamp()}

- دامنه: ${a.site.domain}
- برند: ${a.site.brand}
- وضعیت: ${a.dryRun ? 'DRY-RUN (هیچ چیز منتشر نشد)' : 'اجرای واقعی'}

| شاخص | مقدار |
|---|---|
| مقالهٔ منتشرشده | $pub |
| پیش‌نویس در انتظار بازبینی | $drafts |
| فایل‌های وضعیت | ${states.length} |

## کارهای دستهٔ C (نیازمند تأیید تو)
- کلمات کلیدی جدید را در `keywords.json` اضافه کن.
- پیش‌نویس‌ها را در `blog/` بازبینی و وضعیت را `published` کن.
- درخواست «ویژه‌شدن» را دستی به تیم محتوای مایکت/بازار بده.
''';
  writeText('$_outDir/report-${stamp()}.md', md);
  ok('گزارش ساخته شد: out/report-${stamp()}.md');
}

// ---------------------------------------------------------------------------
// اجرای همه
// ---------------------------------------------------------------------------

Future<void> taskRun(Agent a) async {
  if (a.taskEnabled('generate')) await taskGenerate(a);
  if (a.taskEnabled('build')) taskBuild(a);
  if (a.taskEnabled('audit')) taskAudit(a);
  if (a.taskEnabled('index')) await taskIndex(a);
  if (a.taskEnabled('rank')) await taskRank(a);
  if (a.taskEnabled('social')) await taskSocial(a);
  if (a.taskEnabled('outreach')) taskOutreach(a);
  if (a.taskEnabled('report')) taskReport(a);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

void cmdInit() {
  if (File(_configPath).existsSync()) {
    warn('config.json از قبل هست — دست نزدم.');
    return;
  }
  if (!File(_examplePath).existsSync()) {
    fail('config.example.json پیدا نشد.');
    exit(1);
  }
  File(_examplePath).copySync(_configPath);
  ok('config.json ساخته شد. دامنه و لینک‌ها را داخلش جایگزین کن.');
}

Future<void> main(List<String> args) async {
  final cmd = args.isEmpty ? 'run' : args.first;
  if (cmd == 'init') {
    cmdInit();
    return;
  }

  if (!File(_configPath).existsSync()) {
    warn('config.json نیست؛ از config.example.json استفاده می‌کنم.');
  }
  final cfg = File(_configPath).existsSync() ? readJson(_configPath) : readJson(_examplePath);
  final agent = Agent(cfg);

  stdout.writeln('=== SEO Agent — $cmd — ${stamp()} ===');
  if (agent.dryRun) stdout.writeln('حالت: DRY-RUN (هیچ چیز بیرونی ارسال نمی‌شود)');

  switch (cmd) {
    case 'generate':
      await taskGenerate(agent);
      break;
    case 'build':
      taskBuild(agent);
      break;
    case 'audit':
      taskAudit(agent);
      break;
    case 'index':
      await taskIndex(agent);
      break;
    case 'rank':
      await taskRank(agent);
      break;
    case 'social':
      await taskSocial(agent);
      break;
    case 'outreach':
      taskOutreach(agent);
      break;
    case 'report':
      taskReport(agent);
      break;
    case 'run':
      await taskRun(agent);
      break;
    default:
      fail('دستور ناشناخته: $cmd');
      stdout.writeln('دستورها: init | run | generate | build | audit | index | rank | social | outreach | report');
      exit(1);
  }
  stdout.writeln('=== پایان ===');
}
