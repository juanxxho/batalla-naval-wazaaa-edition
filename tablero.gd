# mar.gd (Adjunto al GridContainer2)
extends GridContainer

# Señal genérica para notificar clics al Game Manager
signal celda_cliqueada(coord: Vector2)

var mostrar_barcos: bool = true
const TAMANO_TABLERO: int = 10
const CELDA_SCENE = preload("res://button.tscn")

# Matriz de estado del tablero (10x10)
# -2: Agua (disparada) | -1: Vacío | 0: Barco Jugador | 1: Barco IA | 2: Impacto
var estado_tablero: Array = []

# Lista para almacenar las referencias de los nodos de celda (necesario para la actualización visual)
var celdas: Array = []

func _ready():
	# Inicializar la matriz a vacío (-1)
	inicializar_matriz()
	crear_celdas_visuales()
	print("Tablero 10x10 generado.")

func inicializar_matriz():
	for x in range(TAMANO_TABLERO):
		estado_tablero.append([])
		for y in range(TAMANO_TABLERO):
			estado_tablero[x].append(-1) # -1 significa celda vacía
	print("Matriz de estado inicializada.")

func crear_celdas_visuales():
	# Bucle para generar las 100 celdas
	for y in range(TAMANO_TABLERO):
		for x in range(TAMANO_TABLERO):
			var celda = CELDA_SCENE.instantiate()
			add_child(celda)
			
			# 1. Almacenar la referencia en la lista
			celdas.append(celda)
			
			# Asignamos la coordenada (x, y)
			celda.coordenada = Vector2(x, y)
			
			# Ajustamos el tamaño (si es necesario)
			celda.custom_minimum_size = Vector2(50, 50)
			
			# Conectamos la señal de clic de la CELDA a esta función
			celda.celda_seleccionada.connect(_on_celda_seleccionada)

# Esta función se llama cuando se hace clic en CUALQUIERA de las 100 celdas
func _on_celda_seleccionada(coord: Vector2):
	# Esta señal es capturada por Game.gd para decidir si es colocación o ataque.
	emit_signal("celda_cliqueada", coord)
	print("Celda cliqueada, señal emitida a Game Manager: ", coord)

# =========================================================
# FUNCIÓN DE ACTUALIZACIÓN VISUAL (Requerida por Game.gd)
# =========================================================

func actualizar_celda_visual(x: int, y: int, estado: int):
	# La matriz 'celdas' se llenó por fila (Y) y luego por columna (X)
	# (0,0), (1,0), ..., (9,0), (0,1), (1,1), ...
	var index = y * TAMANO_TABLERO + x
	
	if index >= 0 and index < celdas.size():
		var celda_node = celdas[index]
		
		# Asumiendo que el nodo de celda (button.tscn) tiene un ColorRect llamado 'ColorRect'
		var color_rect = celda_node.get_node("ColorRect") 
		
		# Hacemos el ColorRect visible para mostrar el resultado
		color_rect.visible = true
		
		match estado:
			2: # Impacto (Hit)
				color_rect.color = Color.RED
			-2: # Agua (Miss)
				color_rect.color = Color.BLUE
			# Otros estados (0, 1, -1) no se modifican visualmente si no es un disparo
	else:
		print("ERROR: Índice de celda fuera de rango para la actualización visual.")
