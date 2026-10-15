class_name CoachOverlay
extends CanvasLayer

var _panel: PanelContainer
var _title: Label
var _detail: Label
var _current: LessonDefinition = null
var _fade := 0.0

func _ready() -> void:
	_panel = get_node_or_null("TipPanel") as PanelContainer
	_title = get_node_or_null("TipPanel/VBox/Title") as Label
	_detail = get_node_or_null("TipPanel/VBox/Detail") as Label
	if _panel != null:
		_panel.visible = false
		_panel.modulate.a = 0.0
	TutorialSystem.lesson_triggered.connect(_on_lesson)

func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_fade = minf(1.0, _fade + delta / 0.4)
	_panel.modulate.a = _fade

func teach(lesson: LessonDefinition) -> void:
	_current = lesson
	if lesson == null:
		_hide()
		return
	if _title != null:
		_title.text = String(lesson.title)
	if _detail != null:
		_detail.text = String(lesson.detail)
	if _panel != null:
		_panel.visible = true
	_fade = 0.0

func _on_lesson(lesson: LessonDefinition) -> void:
	teach(lesson)

func _hide() -> void:
	_current = null
	if _panel != null:
		_panel.visible = false

func current() -> LessonDefinition:
	return _current
