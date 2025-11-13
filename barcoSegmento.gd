# Barco.gd (Adjunto al nodo Area2D)
extends Area2D

@export var longitud_casillas: int = 4 

var es_arrastrado: bool = false
var offset: Vector2 = Vector2.ZERO 

signal barco_colocado(barco_node, posicion_final: Vector2) # Añade barco_node
signal barco_cliqueado(es_arrastrado)

# Barco.gd - VERSIÓN ALTERNATIVA (Recomendado para Area2D)

func _input(event: InputEvent):
	# Esta parte maneja SOLTAR el ratón (se ejecuta fuera del area)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: # Mouse button released
			if es_arrastrado:
				es_arrastrado = false
				# La posición final debe ser manejada al soltar
				emit_signal("barco_colocado", self, global_position)
				get_viewport().set_input_as_handled() 

func _process(_delta):
	# Mueve el barco si está siendo arrastrado
	if es_arrastrado:
		global_position = get_global_mouse_position() + offset

# Función conectada a la señal 'input_event' (solo detecta el clic inicial DENTRO del área)
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		es_arrastrado = true
		offset = global_position - get_global_mouse_position()
		emit_signal("barco_cliqueado", true)
		get_viewport().set_input_as_handled()
