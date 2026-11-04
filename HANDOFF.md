# HANDOFF — Context Researcher File

> อัปเดตล่าสุด: 2026-11-04 · จบรอบ 3 (UX phase) · **session ถัดไปเริ่มที่ §8 งาน license**
> กฎ = `CLAUDE.md` · วิธีทำงาน = `SKILL.md`

## 0. ผลเทสรอบ 1 บนแอปจริง (เจ้าของรัน)
- **B/C/D/E ผ่านหมด** → index, ค้นไทยกลางคำ, PDF highlight + กด chip ไปหน้าถูก, เปิดไฟล์จริง, โหมดไม่ผูกโปรเจค **ยืนยันว่าใช้งานได้จริงแล้ว**
- ไม่ผ่าน 2 ข้อ แก้แล้วในรอบ 2: เปิดมาไม่เต็มจอ (A-1) · ย่อหน้าต่างแล้ว layout ล้น (F-28)

## 1. สถานะตอนนี้
โครงโปรเจคครบและเทสผ่านทั้งชุด (37 passed / 2 skipped) · `flutter analyze` ไม่มี issue
**ยังไม่เคยรันเป็นแอปจริง** — container ที่เขียนเป็น Linux และไม่มี Windows toolchain ⇒ **ข้อถัดไปคือเจ้าของ build บน Windows แล้ว verify**

| ฟีเจอร์ | สถานะ |
|---|---|
| สร้าง/ลบโปรเจค + ผูกโฟลเดอร์/ไฟล์ | ✔ เขียนแล้ว (เทส repo ผ่าน) |
| index ไฟล์เข้า SQLite + reindex เฉพาะไฟล์ที่เปลี่ยน | ✔ |
| ค้นในโปรเจค (FTS5 trigram · ไทยค้นกลางคำได้) | ✔ เทสด้วย sqlite จริง |
| ค้นแบบไม่ผูกโปรเจค (scan สด ทยอยแสดงผล) | ✔ เทสกับไฟล์จริงใน `test/fixtures` |
| extract: xlsx / docx / txt-csv | ✔ เทสกับไฟล์จริง |
| extract: pdf (+ ตรวจไฟล์สแกน) | ⚠ โค้ดครบ แต่ **ยังไม่ได้รันพิสูจน์** (ไม่มี PDFium ใน container) |
| preview PDF + highlight คำ (pdfrx) | ✔ เจ้าของเทสผ่านแล้ว |
| preview Word/TXT + เลื่อนไปจุดที่พบ | ✔ เจ้าของเทสผ่านแล้ว |
| เปิดไฟล์จริง / เปิดโฟลเดอร์ | ✔ เจ้าของเทสผ่านแล้ว |
| preview Excel เป็นตารางจริง (หัวคอลัมน์ + เลขแถว) | ⚠ ใหม่รอบ 2 รอ verify |
| ธีม 5 สี + หน้าตั้งค่า | ⚠ ใหม่รอบ 2 รอ verify |
| กันกดปุ่มซ้ำถี่ ๆ (spinner ระหว่างทำงาน) | ⚠ ใหม่รอบ 2 รอ verify |

## 2. วิธีรันบนเครื่อง Windows (ครั้งแรก)
ต้องใช้ **Flutter ≥ 3.47.0** (pdfrx 2.11 บังคับ) — ลงด้วย FVM:

```bash
fvm install 3.47.9
```

```bash
fvm use 3.47.9
```

```bash
fvm flutter pub get
```

```bash
fvm flutter run -d windows
```

build ไฟล์แจก:

```bash
fvm flutter build windows --release
```

> PDFium มาพร้อม package `pdfrx` อัตโนมัติตอน build (ไม่ต้องลงอะไรเพิ่ม)

## 3. เทส
```bash
fvm flutter test
```

```bash
fvm flutter analyze
```

ชุด PDF ถูก tag ไว้และ **ข้ามโดยค่าเริ่มต้น** เพราะ `flutter test` ไม่มี native PDFium ให้โหลด
จะรันต้องชี้ไฟล์ libpdfium เอง (เอาจาก release ของ `bblanchon/pdfium-binaries`):

```bash
PDFIUM_MODULE_PATH=/path/to/libpdfium.so fvm flutter test test/pdf_extractor_test.dart --tags pdfium
```

fixture ที่ใช้เทส (สร้างด้วย openpyxl / python-docx / reportlab):
`test/fixtures/` = xlsx (จาก openpyxl = rels แบบ absolute) · xlsx เขียนมือ (rels relative + inlineStr + สูตร) · docx · txt
`test/fixtures_pdf/` = pdf มีข้อความ · pdf ที่ไม่มี text layer (จำลองไฟล์สแกน) — แยกโฟลเดอร์ไว้เพื่อให้เทส scan สดไม่ต้องพึ่ง PDFium

## 4. FILE MAP
```
lib/
  main.dart                     init PDFium + เปิด DB + inject AppState
  app/
    app.dart                    MaterialApp + theme
    app_state.dart              ★ state กลาง: โปรเจค · โหมด · คำค้น · ผล · ไฟล์ที่เลือก
    theme/app_colors.dart       AppPalette + 5 ธีม (kThemeOptions) + applyTheme/themeNotifier
    theme/app_dimens.dart       token ขนาดอิงจอ: D.of(context).rw/rh/font*/icon*
    theme/app_theme.dart        ThemeData กลาง
    theme/motion.dart           Motion.fast/base/slow + FadeSlideIn + stagger
  domain/models.dart            FileKind · FileStatus · Project · Locator · Chunk · SearchHit · FileResult
  domain/app_settings.dart      ค่าตั้งค่าที่ผู้ใช้ปรับได้ (ธีม/ฟอนต์/motion/ชนิดไฟล์/ขนาดไฟล์)
  data/
    db.dart                     ★ เปิด DB + migration (_steps) + probe FTS5 trigram
    project_repository.dart     CRUD โปรเจค + root
    settings_repository.dart    อ่าน/เขียน app_setting (key-value)
    index_repository.dart       ★ เขียน/ลบ chunk · ค้นหา (FTS หรือ LIKE) · รวมผลต่อไฟล์
  services/
    match_util.dart             ★ findOccurrences / buildHit (snippet+offset) / escape FTS-LIKE
    file_scanner.dart           เดินโฟลเดอร์ กรองนามสกุล ข้าม ~$ และไฟล์ใหญ่เกิน 64MB
    indexer.dart                extractFile() (โยน pure-Dart เข้า Isolate) + indexProject() stream
    search_service.dart         searchIndexed() / searchLive() (ทยอยส่งผล)
    file_opener.dart            เปิดไฟล์ด้วย shell ของ Windows / เปิด Explorer
    extractors/
      extractor.dart            interface + splitNonEmptyLines + kMaxChunksPerFile
      pdf_extractor.dart        pdfrx: 1 บรรทัด = 1 chunk, locator = เลขหน้า · ตรวจไฟล์สแกน
      xlsx_extractor.dart       ★ อ่าน OOXML เองแบบ event stream → locator = Sheet!B12
      docx_extractor.dart       แกะ zip + ถอด tag → locator = เลขย่อหน้า
      text_extractor.dart       txt/csv → locator = เลขบรรทัด (+ เดา encoding)
  ui/
    projects/projects_screen.dart · project_card.dart
    search/search_screen.dart (layout 3 คอลัมน์) · search_panel.dart · results_list.dart
    preview/preview_pane.dart · pdf_preview.dart · lines_preview.dart · sheet_preview.dart (ตาราง Excel)
    settings/settings_screen.dart  ธีม · ขนาดตัวอักษร · เอฟเฟกต์ · ชนิดไฟล์ · ล้าง index
    widgets/common.dart         PanelCard · HighlightedText · HitChip · KindBadge · EmptyState · ScanProgressBar · AsyncIconButton · สี/ไอคอนตามชนิดไฟล์
    widgets/aurora_background.dart  พื้นหลังไล่สีตามธีม (หยุดเมื่อปิดเอฟเฟกต์)
    widgets/app_logo.dart       โลโก้ CustomPainter (สัดส่วนเดียวกับไอคอนแอป)
```

## 5. การตัดสินใจที่เคาะแล้ว (อย่าย้อนโดยไม่ถาม)
1. **PDF engine = pdfrx (PDFium)** — ฟรี ไม่มี license key · มี viewer + `PdfTextSearcher` ที่ highlight และเลื่อนไปคำนั้นได้
2. **Hybrid search** — โปรเจค = index ลง SQLite แล้วค้นไว · โหมดไม่ผูกโปรเจค = scan สด ไม่เขียน DB
3. **ชนิดไฟล์รอบแรก** = pdf · xlsx/xlsm · docx · txt/csv/tsv/md/log (`.xls` รุ่นเก่าไม่รองรับ: Dart อ่าน BIFF ไม่ได้)
4. **PDF สแกนไม่ OCR** — ขึ้น badge เตือนในผลค้นหาว่าไฟล์นี้ค้นไม่ได้
5. **เขียน xlsx reader เอง (ไม่ใช้ package `excel`)** — เพราะ `excel` 4.0.6 crash กับไฟล์ที่ rels ชี้ path แบบ absolute (`/xl/worksheets/sheet1.xml`) ที่ openpyxl และตัว export หลายตัวสร้าง (พบจากการเทสจริง) · ของเราอ่านด้วย xml event stream → ได้ cell ref ตรงจากไฟล์ + ไม่โหลด workbook ทั้งก้อนเข้า RAM
6. **FTS5 `tokenize='trigram'`** — จำเป็นสำหรับภาษาไทย (ไม่มีช่องว่าง) · คำค้น < 3 ตัวอักษร fallback `LIKE` · กรองผลซ้ำด้วย `findOccurrences()` กัน false positive ของ trigram

## 6. ข้อจำกัดที่รู้อยู่ (บอกผู้ใช้ตรง ๆ ได้)
- **PDF สแกน** ค้นไม่เจอ (ไม่มี text layer)
- **`.xls` / `.doc` รุ่นเก่า** ไม่รองรับ → ต้อง save as xlsx/docx ก่อน
- **Excel: เปิดไฟล์จริงแล้วให้ cursor ไปจ่อ cell ไม่ได้** (ต้องยิง COM/VBA = เปราะ) → ปุ่ม copy `Sheet1!B12` ให้แปะใน Name Box เอง · ส่วน preview ในแอปเลื่อนไป highlight cell ให้แล้ว
- **วันที่ใน Excel** เก็บเป็น serial number → ค้นด้วยข้อความวันที่ที่เห็นบนจออาจไม่เจอ (ยังไม่แปลง number format)
- **ไฟล์ไทยรหัสเก่า TIS-620/CP874** อ่านเป็นตัวอักษรเพี้ยน (รองรับ utf8 + latin1 fallback เท่านั้น)
- **Word**: อ่านเฉพาะ `word/document.xml` + header/footer → ข้อความใน textbox/SmartArt/comment อาจไม่ติด
- ไฟล์ใหญ่กว่า 64 MB ถูกข้าม (`kMaxFileSizeBytes`) · 1 ไฟล์เก็บได้ไม่เกิน 200,000 chunk

## 6.5 ที่เพิ่มในรอบ 2
- **หน้าต่างเปิดมาเต็มจอ** — แก้ที่ `Win32Window::Show()` (SW_SHOWMAXIMIZED) ไม่ใช่ที่ `main.cpp` เพราะ Show() ถูกเรียกหลัง Flutter เฟรมแรกและทับค่าที่ตั้งไว้ก่อนหน้า
- **ขนาดหน้าต่างขั้นต่ำ 980×640** (`WM_GETMINMAXINFO`) + หน้าค้นหายุบเป็น preview ทับผลเมื่อกว้าง < 1150
- **Excel preview เป็นตารางจริง** (`sheet_preview.dart`) — หัวคอลัมน์ A B C · เลขแถว · แท็บเลือก sheet · เลื่อนไป highlight ช่องเป้าหมายทั้งแนวตั้งและแนวนอน
- **ธีม 5 สี** (อินดิโก/ม่วง/เขียวมรกต/ส้มอำพัน/โหมดมืด) เปลี่ยนแล้วมีผลทันที เก็บค่าลง `app_setting` (migration step 2)
- **หน้าตั้งค่า**: ธีม · ขนาดตัวอักษร · ปิดเอฟเฟกต์เคลื่อนไหว · ชนิดไฟล์ที่จะค้น · ขนาดไฟล์สูงสุด · ที่อยู่+ขนาดไฟล์ index + ปุ่มล้าง index · เวอร์ชัน
- **สีประจำชนิดไฟล์** (PDF แดง · Excel เขียว · Word น้ำเงิน · Text เทา) ใช้ที่ป้าย ไอคอน และแถบซ้ายการ์ด
- **กันกดซ้ำ** — `AsyncIconButton` ปิดตัวเอง + ขึ้น spinner จนงานจบ

## 6.6 ที่เพิ่มในรอบ 3 (UX phase)
- **ฟอนต์ Anuphan (OFL-1.1) bundle มากับแอป** — ไทย+ละตินในฟอนต์เดียว ทุกเครื่องเห็นเหมือนกันโดยไม่พึ่งฟอนต์ระบบ · ⚠️ ก่อนแจกจริงต้องวาง `OFL.txt` ใน `assets/fonts/` (ดู `assets/fonts/NOTICE.md`)
- **พื้นหลังไล่สี** `AuroraBackground` — วาดด้วย CustomPainter ดึงสีจากธีมที่ใช้อยู่ จึงเปลี่ยนตามธีมเอง · เคลื่อนช้ามาก (28 วินาทีต่อรอบ) และ **หยุดสนิท** เมื่อปิดเอฟเฟกต์ในแอปหรือระบบตั้ง reduce motion
- **โลโก้ + ไอคอนแอป** — มาร์กหน้ากระดาษ+แว่นขยาย · ในแอปวาดด้วย CustomPainter (`AppLogo`) จึงเปลี่ยนสีตามธีม · ไอคอน Windows อยู่ที่ `windows/runner/resources/app_icon.ico` (สร้างจากสคริปต์ PIL สัดส่วนเดียวกับ `AppLogo`)
- **การ์ดโปรเจค** แสดงโฟลเดอร์ที่ผูกไว้ + จำนวนไฟล์ + เวลา index ล่าสุด (เดิมว่างกลางการ์ด)
- **การ์ดเลือกธีม** เป็นภาพจำลองหน้าจอย่อ (การ์ด+ปุ่ม) แทนจุดสี อ่านออกว่าแต่ละธีมหน้าตาอย่างไร
- **ภาพตัวอย่างหน้าจอ** `docs/ui/*.jpg` (สร้างจาก `test/snapshot_test.dart`)

### 🐞 บั๊กที่เจอจากการเรนเดอร์ภาพ (analyze/เทสเดิมจับไม่ได้)
1. **การ์ดผลค้นหาไม่แสดงเนื้อหาเลย** — ใส่แถบสีชนิดไฟล์เป็น `Border` ที่สีไม่เท่ากันทุกด้านคู่กับ `borderRadius` ⇒ Flutter assert ตอน paint แล้ววาดลูกไม่ออก · แก้เป็นแถบลูกด้านในที่ clip ตามมุมการ์ด + มีเทส `results_render_test.dart` ล็อกไว้
2. **ข้อความ snippet ได้ฟอนต์คนละตัวกับทั้งแอป** — `RichText` ไม่สืบทอด `DefaultTextStyle` · เปลี่ยนไปใช้ `Text.rich`

## 7. งานถัดไปที่เสนอ (รอเจ้าของเคาะ)
1. **License key แบบออฟไลน์** (เคาะแล้ว: ไฟล์ `.lic` ลายเซ็น Ed25519 · ผูกเครื่อง · เก็บสถานะนอก index.db เข้ารหัสด้วย Windows DPAPI · กันหมุนนาฬิกาถอยหลัง) + CLI ออก key สำหรับเจ้าของ
2. **UX/UI phase**: gradient/shader background · ฟอนต์ไทย bundle · logo + app icon · ขัดรายละเอียดทุกหน้า
3. **ภาษา (ไทย/อังกฤษ)** — ต้องห่อข้อความทุกจุด (~150 จุด) + เลือกวิธี (ไฟล์ .arb ของ intl หรือ map ง่าย ๆ) ⇒ ควรทำเป็นรอบของตัวเอง
2. ค้นหลายคำ / ตัวเลือก "ทั้งคำ" / case-sensitive
3. แปลง number format ของ Excel (วันที่/เงิน) ให้ค้นด้วยข้อความที่เห็นบนจอได้
4. รองรับ TIS-620 (ต้องเพิ่ม decoder เอง)
5. ปุ่มหยุดกลางคัน (cancel) ตอน index/scan ไฟล์เยอะ (ตอนนี้มี `cancelSearch()` ใน state แล้วแต่ยังไม่ผูกปุ่มใน UI)
6. จำคำค้นล่าสุดต่อโปรเจค


---

## 8. 🔜 งานถัดไป — License key แบบออฟไลน์ (ยังไม่เริ่มเขียนโค้ด)

### ที่เจ้าของเคาะแล้ว (ห้ามเปลี่ยนเองโดยไม่ถาม)
| หัวข้อ | ที่เคาะ |
|---|---|
| รูปแบบ key | **ไฟล์ `.lic`** ที่ลูกค้ากดเลือก (ไม่ใช่พิมพ์ key สั้น) |
| วิธีกันปลอม | **ลายเซ็น Ed25519** — private key อยู่กับเจ้าของเท่านั้น (ห้ามเข้า repo) · ฝังเฉพาะ public key ในแอป ⇒ แกะ exe ก็ออก key เองไม่ได้ |
| ผูกเครื่อง | **1 key ต่อ 1 เครื่อง** — fingerprint จาก MachineGuid (registry) + volume serial ของไดรฟ์ระบบ |
| ที่เก็บสถานะ | **ไม่เก็บใน `index.db`** (เปิดแก้ได้ด้วย DB Browser) → ไฟล์แยกใน `%APPDATA%` เข้ารหัสด้วย **Windows DPAPI** (ผูกกับ user account) |
| กันหมุนนาฬิกา | เก็บ `lastSeenUtc` ทุกครั้งที่เปิดแอป · เวลาปัจจุบันย้อนหลังกว่าเดิมเกิน 1 ชม. = ถือว่าโกง ล็อกทันที |
| อายุ | ระบุจำนวนวันใน key (เช่น 30) นับจากวันที่ issue |

### ที่ยังไม่ได้เคาะ — ต้องถามเจ้าของก่อนเขียน
1. **ยังไม่ activate / หมดอายุแล้วทำอะไรได้บ้าง** — ล็อกทั้งแอปเหลือแต่หน้า activate · หรือค้นได้แบบจำกัด · หรือทดลองใช้อัตโนมัติ X วันตอนลงครั้งแรก
2. **เตือนล่วงหน้ากี่วันก่อนหมดอายุ** (เสนอ 7 วัน เป็นแถบบนหน้าแรก)
3. **ตอน dev/เทสจะข้ามการตรวจยังไง** (เสนอ: debug build ข้ามให้ + ขึ้นแถบว่าอยู่โหมด dev)
4. **ต่ออายุ = ส่งไฟล์ `.lic` ใบใหม่ทับใบเดิม ใช่ไหม**

### โครงที่วางไว้ (ยังไม่ได้เขียน)
```
lib/services/license/
  machine_id.dart       fingerprint เครื่อง (MachineGuid + volume serial → sha256)
  license_payload.dart  {version, machineId, days, issuedAt, note} + canonical json
  license_verifier.dart ตรวจลายเซ็น Ed25519 ด้วย public key ที่ฝังในแอป
  license_store.dart    อ่าน/เขียนสถานะ + DPAPI (CryptProtectData ผ่าน win32 + ffi)
  license_service.dart  สถานะรวม: valid / expired / tampered / none + วันคงเหลือ
lib/ui/license/activate_screen.dart   โชว์ Machine ID ให้ copy + ปุ่มเลือกไฟล์ .lic
tool/keygen.dart        สร้างคู่กุญแจครั้งแรก (รันครั้งเดียว · private key เก็บนอก repo)
tool/licgen.dart        เจ้าของออก key: dart run tool/licgen.dart --machine XXX --days 30
```
- package ที่ต้องเพิ่ม: `cryptography` (Ed25519 pure Dart) · `ffi` + `win32` (DPAPI)
- **ความจริงที่ยอมรับแล้ว:** ตรวจสิทธิ์ฝั่งเครื่องลูกค้าล้วน ๆ กันคนตั้งใจ patch exe ไม่ได้ 100% เป้าหมายคือ "แพงพอจนไม่คุ้มแกะ"

---

## 9. กับดักที่ session ใหม่ต้องรู้ (เจอมาแล้วจริง)
1. **`flutter analyze` ผ่าน ไม่ได้แปลว่าวาดออก** — `BoxDecoration` ที่ `Border` สีไม่เท่ากันทุกด้าน + `borderRadius` จะ assert ตอน paint แล้ววาดลูกไม่ออกทั้งก้อน · แตะ UI แล้วให้ดูภาพจริงด้วย `RENDER_SHOTS=1 flutter test test/snapshot_test.dart --update-goldens`
2. **`RichText` ไม่สืบทอด `DefaultTextStyle`** → ได้ฟอนต์คนละตัวกับทั้งแอป ใช้ `Text.rich` เสมอ
3. **งานที่อ่านไฟล์จริง/Isolate ใน widget test ต้องอยู่ใน `tester.runAsync()`** ไม่งั้นค้างตลอดกาล
4. **อนิเมชันวนไม่จบ (พื้นหลัง) ทำให้ `pumpAndSettle` ไม่นิ่ง** → ใน test ครอบด้วย `MediaQuery(disableAnimations: true)`
5. **เทส PDF ถูก skip โดยค่าเริ่มต้น** (ไม่มี PDFium ในคอนเทนเนอร์) ต้องตั้ง `PDFIUM_MODULE_PATH` ถึงรัน
6. **แก้ schema ต้องต่อ step ท้าย `_steps` เท่านั้น** (`lib/data/db.dart`) step ที่ปล่อยแล้วห้ามแก้
7. **ห้าม `git add -A` ตอนยังไม่ได้แยกกอง** — เคยทำให้ 5 เรื่องรวมเป็น commit เดียวมาแล้ว
