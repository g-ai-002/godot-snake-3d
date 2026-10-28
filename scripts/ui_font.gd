class_name UiFont
extends RefCounted

## 优先使用 CI 生成的中文字体子集（res://assets/fonts/web_cjk.otf，不入库），
## 桌面端没有该文件时回退到系统字体，避免把字体二进制放进仓库。

const WEB_FONT_PATH := "res://assets/fonts/web_cjk.otf"
const FONT_NAMES := [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"PingFang SC",
	"Hiragino Sans GB",
	"Noto Sans CJK SC",
	"Noto Sans SC",
	"Source Han Sans SC",
	"WenQuanYi Micro Hei",
	"sans-serif",
]

static var _font: Font


static func get_font() -> Font:
	if _font != null:
		return _font

	if ResourceLoader.exists(WEB_FONT_PATH):
		var web_font: Resource = load(WEB_FONT_PATH)
		if web_font is Font:
			_font = web_font

	if _font == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(FONT_NAMES)
		system.allow_system_fallback = true
		_font = system

	return _font
