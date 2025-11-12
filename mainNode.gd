extends Node

func _ready():
	cargar_escena("res://Main2.tscn")

func cargar_escena(ruta):
	# Elimina cualquier hijo previo (otra pantalla)
	for child in get_children():
		child.queue_free()
	
	# Carga la nueva escena
	var escena = load(ruta).instantiate()
	add_child(escena)
