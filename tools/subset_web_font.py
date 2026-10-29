#!/usr/bin/env python3
"""生成 Web 构建用的中文字体子集（不提交到仓库）。

用法：
    python -m pip install fonttools
    python tools/subset_web_font.py

脚本会缓存下载 Noto Sans SC（约 8MB），按项目源码里出现的字符裁剪，
输出 assets/fonts/web_cjk.otf（通常几百 KB）与 OFL.txt 许可。
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE_DIR = Path(tempfile.gettempdir()) / "godot_snake_web_font"
FONT_URL = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/main/"
    "Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
)
LICENSE_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt"
FALLBACK_CHARS = (
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz "
    ".,:;!?+-*/()[]{}<>\"'/\\|@#$%^&*=_~`\n"
)


def download(url: str, target: Path) -> None:
    if target.exists() and target.stat().st_size > 0:
        return
    print(f"⬇️  下载: {url}")
    with urllib.request.urlopen(url, timeout=120) as response:
        target.write_bytes(response.read())


def collect_text() -> str:
    chunks: list[str] = []
    for pattern in ("*.gd", "*.tscn", "*.godot"):
        for path in ROOT.rglob(pattern):
            if ".godot" in path.parts:
                continue
            chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(chunks) + "\n" + FALLBACK_CHARS


def main() -> int:
    try:
        import fontTools  # noqa: F401
    except ImportError:
        print("❌ 缺少 fonttools，请先执行: python -m pip install fonttools")
        return 1

    output_dir = ROOT / "assets" / "fonts"
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / "web_cjk.otf"

    with tempfile.TemporaryDirectory() as tmp:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        font_path = CACHE_DIR / "NotoSansSC-Regular.otf"
        tmp_path = Path(tmp)
        download(FONT_URL, font_path)
        download(LICENSE_URL, output_dir / "OFL.txt")

        text = collect_text()
        chars_path = tmp_path / "chars.txt"
        chars_path.write_text(text, encoding="utf-8")
        print(f"📝 收集到 {len(set(text))} 个不同字符")

        subprocess.run(
            [
                sys.executable,
                "-m",
                "fontTools.subset",
                str(font_path),
                f"--text-file={chars_path}",
                f"--output-file={output}",
                "--layout-features=*",
                "--glyph-names",
                "--symbol-cmap",
                "--legacy-cmap",
                "--notdef-glyph",
                "--notdef-outline",
                "--recommended-glyphs",
            ],
            check=True,
        )

    size_kb = output.stat().st_size / 1024
    print(f"✅ 已生成 {output.relative_to(ROOT)}（{size_kb:.1f} KB）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
