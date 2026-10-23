class_name FocusMode
extends RefCounted
## THUG2 focus: with the special meter full, the focus button slows the game (the skater sets Engine.time_scale to
## focus_scale in live play) and the meter drains while it is on; empty, focus ends and special is lost. Pure logic: no
## Node, no clock. The drain is per real second: tick() gets the scaled (game) step and divides the scale back out, so a
## full meter lasts 1 / drain real seconds. Scripted runs never scale the engine, so there each tick drains the same
## share (deterministic, a little faster in game time).

var active: bool = false


## Turns focus on when the meter is special. Returns true when it came on.
func toggle(meter: SpecialMeter) -> bool:
	if active:
		active = false
		return false
	if meter == null or not meter.is_special():
		return false
	active = true
	return true


## Drains `meter` by drain per real second while active. Returns true on the tick it ran dry (focus is then off and the
## meter's special is spent).
func tick(delta: float, scale: float, drain: float, meter: SpecialMeter) -> bool:
	if not active or meter == null:
		return false
	meter.value = maxf(meter.value - drain * delta / maxf(scale, 0.01), 0.0)
	if meter.value > 0.0:
		return false
	meter.bail()
	active = false
	return true


## The engine clock for this state: `scale` while active, else 1.
func time_scale(scale: float) -> float:
	return scale if active else 1.0
