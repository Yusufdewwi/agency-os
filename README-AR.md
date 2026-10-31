# Agency OS — Full Stack Package

هذه حزمة موحدة تجمع آخر نسخة من الواجهة كما هي مع Backend Node.js/Express وقاعدة Supabase migrations.

## مهم قبل الاستخدام

- ملف `frontend/index.html` منسوخ كما هو؛ لم يتم تغيير التصميم أو الأقسام أو الألوان أو النصوص أو سلوك الواجهة.
- الخادم يقدّم الواجهة والـ API من نفس العنوان: `http://localhost:4000`.
- الـ Backend يحتوي API وطبقة مصادقة Supabase ومخطط قاعدة البيانات وسياسات RLS.
- **الواجهة الحالية لم تُحوّل بعد من localStorage إلى API لكل شاشة**؛ لذلك لا تعتبر البيانات الحالية متزامنة بين الموظفين أو محفوظة في Supabase. هذا يتطلب مرحلة ربط CRUD وتسجيل الدخول لكل وحدة.
- Google OAuth placeholders موجودة في `backend/.env.example`، لكن Gmail وCalendar/Meet لا تصبح فعالة بمجرد إدخال القيم؛ مسارات OAuth وتخزين/تجديد الرموز والتحقق الأمني ما زالت تحتاج تنفيذ واختبار.
- لا يوجد ربط مالي فعلي أو تحويل أموال. المحافظ حالياً لا تتصل ببنك أو مزود دفع.

## المتطلبات

- Node.js 22.22 أو أحدث
- npm
- حساب Supabase

## تشغيل المشروع على Windows

1. فك ضغط الملف.
2. افتح مجلد `Agency_OS_Full_Stack` في VS Code.
3. افتح Terminal في جذر المشروع وشغّل:

   ```powershell
   .\START-WINDOWS.ps1
   ```

4. أول تشغيل ينشئ `backend/.env` من المثال ويتوقف. افتح `backend/.env` وأضف:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
5. شغّل `.\START-WINDOWS.ps1` مرة ثانية.
6. افتح `http://localhost:4000`.
7. فحص الخادم: `http://localhost:4000/health`.

بديل يدوي:

```powershell
cd backend
Copy-Item .env.example .env
# عدّل backend/.env
npm install
npm run check
npm run dev
```

## إعداد Supabase

1. أنشئ مشروعاً جديداً من https://supabase.com/dashboard
2. انسخ Project URL وPublishable/anon key إلى `backend/.env`.
3. من SQL Editor شغّل الملفات بالترتيب:
   - `backend/supabase/migrations/001_initial_schema.sql`
   - `backend/supabase/migrations/002_security_rls.sql`
   - `backend/supabase/migrations/003_bootstrap_functions.sql`
4. أكمل إنشاء المستخدم الأول والـ organization والـ Owner membership حسب `backend/README.md`.

**لا تضع service_role key في HTML أو ملفات frontend أو في المحادثة.** الخادم الحالي يعتمد على JWT المستخدم وRLS.

## إعداد Google

1. افتح https://console.cloud.google.com/
2. أنشئ Google Cloud Project وفعّل Gmail API وGoogle Calendar API.
3. اضبط OAuth consent screen وأنشئ OAuth Client من نوع Web application.
4. أضف redirect URI الموجود في `.env`:
   `http://localhost:4000/api/v1/integrations/google/callback`
5. ضع Client ID وClient Secret في `backend/.env` فقط.

ملاحظة: OAuth الفعلي غير مكتمل في هذه الحزمة؛ endpoint الاتصال يرجع `PROVIDER_SETUP_REQUIRED` إلى أن يتم تنفيذ callback، تشفير الرموز، refresh/revoke، scopes والمراجعة الأمنية.

## ماذا يعمل الآن؟

- Express backend وAPI routes.
- Supabase client والتحقق من JWT.
- SQL schema ومجموعة سياسات RLS كبداية.
- Health check وCORS وHelmet وrate limiting والتحقق من المدخلات.
- تقديم الواجهة الأصلية من الخادم نفسه.
- API helper scaffold في `frontend/api-client.js`.

## ما الذي يمنع وصفه بأنه Production Ready؟

- تسجيل الدخول وتهيئة أول Owner وربط جلسة الواجهة.
- نقل CRUD لكل الشاشات من localStorage إلى Supabase API.
- اختبار صلاحيات كل دور وقسم بحسابات فعلية.
- Google OAuth الفعلي وGmail/Calendar/Meet.
- Storage buckets والرفع والتنزيل الآمن للملفات.
- مزود دفع معتمد، webhooks، مطابقة مالية وموافقات فعلية.
- اختبارات end-to-end، النسخ الاحتياطي والاستعادة، مراقبة ونشر HTTPS.

لا تدخل بيانات عملاء أو موظفين حقيقية قبل إكمال هذه البنود واختبارها.
