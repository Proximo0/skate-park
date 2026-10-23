class_name ProLog
extends RefCounted
## Prints a Pro Challenge medal line (`PROMEDAL <level> <tier>`) for tools/pro_check.sh, which reads the bot's output.


static func medal(level_id: String, tier: String) -> void:
	print("PROMEDAL %s %s" % [level_id, tier])
