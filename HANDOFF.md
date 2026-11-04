# HANDOFF — Context Researcher File

> อัปเดตล่าสุด: 2026-11-04 · session แรก (วางโครง + ทำครบ flow หลัก)
> กฎ = `CLAUDE.md` · วิธีทำงาน = `SKILL.md`

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
| preview PDF + highlight คำ (pdfrx) | ⚠ ต้อง verify บนแอปจริง |
| preview Excel/Word/TXT + เลื่อนไปจุดที่พบ | ⚠ ต้อง verify บนแอปจริง |
| เปิดไฟล์จริง / เปิดโฟลเดอร์ | ⚠ ต้อง verify บน Windows |

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
    theme/app_colors.dart       AppPalette (semantic) + AppColors getter → สลับ theme ได้
    theme/app_dimens.dart       token ขนาดอิงจอ: D.of(context).rw/rh/font*/icon*
    theme/app_theme.dart        ThemeData กลาง
    theme/motion.dart           Motion.fast/base/slow + FadeSlideIn + stagger
  domain/models.dart            FileKind · FileStatus · Project · Locator · Chunk · SearchHit · FileResult
  data/
    db.dart                     ★ เปิด DB + migration (_steps) + probe FTS5 trigram
    project_repository.dart     CRUD โปรเจค + root
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
    preview/preview_pane.dart · pdf_preview.dart · lines_preview.dart
    widgets/common.dart         PanelCard · HighlightedText · HitChip · KindBadge · EmptyState · ScanProgressBar
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

## 7. งานถัดไปที่เสนอ (รอเจ้าของเคาะ)
1. **เจ้าของ build + verify บน Windows** (สำคัญสุด — ยังไม่เคยรันจริง) · จุดที่ต้องดู: preview PDF highlight · กด chip แล้วเด้งไปจุดถูก · เปิดไฟล์ตอนที่ไฟล์เปิดค้างอยู่ใน Excel
2. ค้นหลายคำ / ตัวเลือก "ทั้งคำ" / case-sensitive
3. แปลง number format ของ Excel (วันที่/เงิน) ให้ค้นด้วยข้อความที่เห็นบนจอได้
4. รองรับ TIS-620 (ต้องเพิ่ม decoder เอง)
5. ปุ่มหยุดกลางคัน (cancel) ตอน index/scan ไฟล์เยอะ (ตอนนี้มี `cancelSearch()` ใน state แล้วแต่ยังไม่ผูกปุ่มใน UI)
6. จำคำค้นล่าสุดต่อโปรเจค
