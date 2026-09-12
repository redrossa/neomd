# Recovery fixture: UTF-8 emoji and mixed line endings 🎉

Family ZWJ sequence: 👨‍👩‍👧‍👦 · flag: 🇯🇵 · skin tone: 👍🏽 · keycap: 1️⃣ · text presentation: ☺︎ ☺️

Combining marks: é (NFD) vs é (NFC) · Devanagari: नमस्ते · Thai: สวัสดี · Arabic RTL: مرحبا بالعالم · Hebrew: שלום

CJK: 日本語のメモ 中文测试 한국어 · Cyrillic: Привет · Greek: Γειά σου · Math: ∑∫√∞ · Ligature-prone: ﬁ ﬂ- List item with emoji 🧪 and CRLF ending
- List item with LF ending 🧵
- List item with classic Mac CR ending 🔬
> Quote with 🚀 and *emphasis* and **strong** and `code 🐍`

```swift
let greeting = "héllo 🌍" // CRLF code line
let tab = "\t"
print(greeting)```

| Emoji | Meaning |
| --- | --- |
| ✅ | done |
| ❌ | not done |

Zero-width joiner alone: ‍ · zero-width space: [​] · NBSP: [ ] · BOM as ZWNBSP mid-text: [﻿]

Last line has no trailing newline and ends with an emoji 🏁