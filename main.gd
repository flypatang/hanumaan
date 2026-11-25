extends Node3D
## Boot scene placeholder. Replaced by core/chapter_flow.gd in Wave 5.

const TITLE: String = "Hanumaan — Sundara Kanda"


func _ready() -> void:
	var label: Label = Label.new()
	label.text = TITLE
	add_child(label)
