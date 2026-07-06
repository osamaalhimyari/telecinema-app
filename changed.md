# 🎬 التغييرات / Changes

## 🆕 نوع غرفة جديد: "تشغيل محلي" / New room type: "Play locally"

**🇸🇦 عربي**
- 📱 عند إنشاء غرفة، أصبح هناك خيار جديد **«تشغيل محلي»**.
- 🎞️ منشئ الغرفة يختار فيديو من جهازه → يُحفظ فورًا في ذاكرة الجهاز (كاش) ويبدأ التشغيل مباشرة **بدون أي رفع للسيرفر**.
- 🔗 يُنشأ رابط الغرفة فورًا دون انتظار رفع الفيديو.
- 🤝 السيرفر يشارك **أزرار التحكم فقط** (تشغيل/إيقاف/تقديم/سرعة) بين الجميع — الفيديو لا يمر عبر السيرفر إطلاقًا.

**🇬🇧 English**
- 📱 A new **"Play locally"** option is available when creating a room.
- 🎞️ The creator picks a video from their device → it's saved to on-device cache instantly and plays right away, **with no upload to the server**.
- 🔗 The room link is created immediately — no waiting for an upload.
- 🤝 The server shares **only the controls** (play / pause / seek / speed) between everyone — the video never passes through the server.

---

## 🚪 بوابة توفير الملف للعضو الثاني / Provide-file gate for the joiner

**🇸🇦 عربي**
- 👥 عندما ينضم عضو آخر، تظهر له شاشة تطلب منه **اختيار الفيديو من جهازه هو**.
- 💾 يُحفظ الفيديو في ذاكرة جهازه (كاش) — **وليس على السيرفر** — ثم يبدأ التشغيل محليًا.
- 🎯 لا توجد أي مطابقة للاسم أو الحجم — كل شخص يشغّل أي ملف يريده، والمزامنة تكون للتحكم فقط.

**🇬🇧 English**
- 👥 When another viewer joins, they see a screen asking them to **pick the video from their own device**.
- 💾 It's saved to their device cache — **not the server** — then plays locally.
- 🎯 No name/size matching — everyone plays whatever file they like, and only the controls are synced.

---

## ☁️ خيار الرفع الاختياري / Optional upload fallback

**🇸🇦 عربي**
- 🔀 في غرفة «التشغيل المحلي» يوجد مفتاح **«ارفعه أيضًا إلى السيرفر»**.
- 🌐 عند تفعيله، من لا يملك الملف يمكنه **المشاهدة أونلاين** عبر زر «المشاهدة عبر الإنترنت».

**🇬🇧 English**
- 🔀 An **"Also upload to the server"** switch is available in a local room.
- 🌐 When enabled, viewers without the file can **watch online** via a "Watch online instead" button.

---

## ⏱️ إزاحة المزامنة لكل مشاهد / Per-viewer sync offset

**🇸🇦 عربي**
- 🎛️ زر جديد داخل المشغّل (للغرف المحلية) لتقديم أو تأخير توقيتك أنت فقط: **−5ث / −0.5ث / +0.5ث / +5ث**.
- 🧭 يعالج اختلاف الملفات البسيط (مقدمة أطول، إعلان، نسخة مختلفة) — يضبط توقيتك أنت **دون التأثير على بقية المشاهدين**.

**🇬🇧 English**
- 🎛️ A new control inside the player (local rooms) nudges **only your** timing: **−5s / −0.5s / +0.5s / +5s**.
- 🧭 It absorbs slight file differences (longer intro, an ad, a different rip) — it adjusts your timeline **without affecting anyone else**.

---

## ⚡ تحسين لغرف الرفع / Upload-room enhancement

**🇸🇦 عربي**
- 🚀 عند إنشاء غرفة **رفع** عادية، يُحفظ الملف الذي اخترته في الكاش فورًا، فتشاهد من القرص مباشرة بدل إعادة بثّه من السيرفر.

**🇬🇧 English**
- 🚀 When you create a normal **upload** room, your picked file is cached instantly so you play from disk instead of re-streaming your own upload.

---

## 🔁 استبدال الملف المحلي / Replace local file

**🇸🇦 عربي**
- 🗑️ خيار في قائمة الغرفة لاستبدال الملف المحلي إذا اخترت ملفًا خاطئًا.

**🇬🇧 English**
- 🗑️ A room-menu option to swap your local file if you picked the wrong one.

---

## 🛠️ ملاحظات تقنية / Technical notes

**🇸🇦 عربي**
- 🗄️ **لا حاجة لأي مايجريشن (migration)** — لا توجد أعمدة جديدة في قاعدة البيانات. القيمة `roomType = 'local'` تُخزَّن في عمود نصّي موجود أصلًا.
- 🌍 الغرف المحلية تعمل على التطبيق فقط (الكاش غير مدعوم على الويب) — وتظهر رسالة مناسبة على الويب.
- ✅ تم فحص الكود: `flutter analyze` نظيف، وفحص أنواع السيرفر `tsc` ناجح.
- ♻️ أعد تشغيل سيرفر AdonisJS ليُحمّل الـ validator/controller/model المحدّث.

**🇬🇧 English**
- 🗄️ **No migration needed** — no new DB columns. `roomType = 'local'` stores in the existing text column.
- 🌍 Local rooms are app-only (cache is disabled on web) — a graceful message shows on web.
- ✅ Verified: `flutter analyze` clean, server `tsc` typecheck passes.
- ♻️ Restart the AdonisJS server to load the updated validator/controller/model.

---

## 📂 أبرز الملفات المعدّلة / Key files changed

- 🧩 `lib/features/rooms/domain/entities/room_type.dart` — قيمة `local` الجديدة / new `local` value
- 💽 `lib/features/cache/data/cache_manager.dart` — `importLocalFile` (نسخ ملف محلي إلى الكاش / import a local file)
- 🎥 `lib/features/watch/presentation/bloc/watch_cubit.dart` — اختيار المصدر + توفير الملف + إزاحة المزامنة / source selection + provide file + sync offset
- 🚪 `lib/features/watch/presentation/widgets/local_file_gate.dart` — شاشة توفير الملف / provide-file gate (جديد / new)
- 🎚️ `lib/features/watch/presentation/widgets/video_surface.dart` — زر إزاحة المزامنة / sync-offset control
- 📝 `lib/features/rooms/presentation/pages/create_room_page.dart` — خيار «تشغيل محلي» + مفتاح الرفع / local option + upload toggle
- 🖥️ `watch-party/app/controllers/api/rooms_api_controller.ts` — فرع إنشاء غرفة `local` / server `local` create branch
