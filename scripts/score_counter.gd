extends Node

@onready var score_label := %TimerLabel

var score := 0 :
	set(value):
		score = value
		score_label.text = str(score)


func _on_timer_label_timer_timeout() -> void:
	score += 1
