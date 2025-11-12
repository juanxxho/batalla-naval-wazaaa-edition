# Celda.gd (Asociado al TextureButton)

extends TextureButton

var coordenada: Vector2 = Vector2(-1, -1) # Almacena la posicion (x, y)
signal celda_seleccionada(coord) # Señal para avisarle al tablero/juego

func _ready():
	# Conecta el clic del botón a la función que emite la señal
	pressed.connect(_on_pressed)

# Función que se llama cuando se hace clic en el botón
func _on_pressed():
	# Solo emite la coordenada si ya fue asignada (no -1, -1)
	if coordenada != Vector2(-1, -1):
		print("He sido cliqueado en la coordenada: ", coordenada)
		emit_signal("celda_seleccionada", coordenada)
