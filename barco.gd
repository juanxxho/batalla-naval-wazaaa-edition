# Barco.gd (Adjunto al nodo Area2D)
extends Area2D

# Longitud del barco en casillas (ej: 4, 3, 2)
@export var longitud_casillas: int = 4 

var es_arrastrado: bool = false
var offset: Vector2 = Vector2.ZERO # Diferencia entre el centro del barco y el clic

# Señales para notificar al Game.gd
signal barco_colocado(posicion_logica)
signal barco_cliqueado(es_arrastrado)

# Función del motor Godot para detectar entrada (clics/toques)
func _input(event: InputEvent):
	# Detección del clic inicial
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Revisa si el clic está sobre este Area2D
			if get_global_mouse_position().distance_to(global_position) < 50: 
				# ^ Ajusta el umbral de distancia según el tamaño de tu barco
				es_arrastrado = true
				offset = global_position - get_global_mouse_position()
				emit_signal("barco_cliqueado", true)
		else:
			# Soltar el clic
			if es_arrastrado:
				es_arrastrado = false
				# Notificar a Game.gd para validar la posición final
				# La lógica de "snap to grid" (ajustar a la cuadrícula) la haremos en Game.gd
				emit_signal("barco_colocado", global_position)
				emit_signal("barco_cliqueado", false)

func _process(delta):
	# Mueve el barco si está siendo arrastrado
	if es_arrastrado:
		global_position = get_global_mouse_position() + offset
