# mar.gd (Adjunto al GridContainer2)
extends GridContainer
# Nueva señal para que el Game.gd la capte
# AÑADE ESTO: Variable para controlar si se deben mostrar los barcos
var mostrar_barcos: bool = true
signal ataque_realizado(coord)
const TAMANO_TABLERO: int = 10
# ¡IMPORTANTE! Revisa que la ruta a tu celda sea correcta.
const CELDA_SCENE = preload("res://button.tscn") 

func _ready():
	crear_celdas_visuales()
	print("Tablero 10x10 generado.")

func crear_celdas_visuales():
	for x in range(TAMANO_TABLERO):
		for y in range(TAMANO_TABLERO):
			var celda = CELDA_SCENE.instantiate()
			add_child(celda) 
			
			# Asignamos la coordenada (x, y)
			celda.coordenada = Vector2(x, y)
			
			# Ajustamos el tamaño para que encajen 10x10 (ej: 50x50 píxeles cada una)
			# Puedes ajustar esto en el editor o aquí:
			celda.custom_minimum_size = Vector2(50, 50)
			
			# Conectamos la señal de clic de la celda a una función en este script
			celda.celda_seleccionada.connect(_on_celda_seleccionada)
			
# Esta función se llama cuando se hace clic en CUALQUIERA de las 100 celdas

func _on_celda_seleccionada(coord: Vector2):
	# Ya sea que dispares o coloques un barco, esta celda notifica.
	emit_signal("ataque_realizado", coord)
	print("Celda cliqueada, señal emitida: ", coord)
