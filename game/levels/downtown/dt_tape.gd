class_name DtTape
extends Collectible
## The secret tape: a skate video cassette that spins where the letters would, for the "find the secret tape" goal.
## A Collectible like any other (item "tape"); only its look differs.


func _build_letter() -> void:
	var bt := DtBatch.new()
	bt.box(Vector3(0, 0, 0), Vector3(0.62, 0.38, 0.09), Color("1d1f26"), Basis.IDENTITY, false)
	bt.box(Vector3(0, 0.05, 0.047), Vector3(0.5, 0.16, 0.006), Color("f2c94c"), Basis.IDENTITY, false)
	bt.box(Vector3(0, 0.05, 0.051), Vector3(0.5, 0.035, 0.004), Color("d8382f"), Basis.IDENTITY, false)
	bt.box(Vector3(0, -0.1, 0.047), Vector3(0.36, 0.1, 0.006), Color("39404d"), Basis.IDENTITY, false)
	for s: float in [-1.0, 1.0]:
		bt.box(Vector3(s * 0.11, -0.1, 0.052), Vector3(0.06, 0.06, 0.004), Color("f1efe8"), Basis.IDENTITY, false)
	var mi: MeshInstance3D = bt.instance("Tape", false)
	mi.scale = Vector3.ONE * 1.3
	_visual.add_child(mi)
	var tag := Label3D.new()
	tag.text = "SECRET TAPE"
	tag.font_size = 64
	tag.pixel_size = 0.004
	tag.outline_size = 12
	tag.outline_modulate = OUTLINE_COLOR
	tag.modulate = LETTER_COLOR
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 0.6
	_visual.add_child(tag)
