# Noto Serif SC (subset)

`NotoSerifSC-Subset.woff2` is the display serif for CJK headings. It is a subset of
Noto Serif SC 2.003 (SIL OFL 1.1, see `NotoSerifSC-LICENSE.txt`), bundled so builds
do not fetch it from Google Fonts.

- Source: https://raw.githubusercontent.com/notofonts/noto-cjk/Serif2.003/Serif/Variable/OTF/Subset/NotoSerifSC-VF.otf
- Weight axis limited to 600–700 (the weights headings use).
- Characters: all of GB2312 (6,763 common hanzi plus symbols), CJK punctuation
  (U+3000–303F), kana (U+3040–30FF) and fullwidth forms (U+FF00–FFEF). Other
  characters fall back to the system serif.

Regenerate with fontTools (`pip install fonttools brotli`):

```sh
python3 - > chars.txt <<'EOF'
import sys
chars = set()
for hi in range(0xA1, 0xF8):
    for lo in range(0xA1, 0xFF):
        try:
            chars.add(bytes([hi, lo]).decode("gb2312"))
        except UnicodeDecodeError:
            pass
for a, b in [(0x3000, 0x303F), (0x3040, 0x30FF), (0xFF00, 0xFFEF)]:
    chars.update(chr(c) for c in range(a, b + 1))
sys.stdout.write("".join(sorted(chars)))
EOF
fonttools varLib.instancer NotoSerifSC-VF.otf wght=600:700 -o NotoSerifSC-600-700.otf
pyftsubset NotoSerifSC-600-700.otf --text-file=chars.txt --layout-features='*' \
  --flavor=woff2 --output-file=NotoSerifSC-Subset.woff2
```
