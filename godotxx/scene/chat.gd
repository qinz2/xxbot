extends Label
class_name chat
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play_chat() -> void:
	animation_player.play("chatspeak")

func reset() -> void:
	animation_player.play("RESET")
