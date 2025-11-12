# Game.gd

extends Node2D

const BARCO_SCENE = preload("res://barco.tscn")
const TABLERO_SCENE = preload("res://mar.tscn")


# =========================================================
# VARIABLES DE CLASE (Variables globales, accesibles desde cualquier función)
# =========================================================
enum Fase {COLOCACION, BATALLA}
var fase_actual = Fase.COLOCACION

var tablero_propio: Node2D # <--- ¡CORRECCIÓN 1: Almacenar referencia!
var tablero_objetivo: Node2D # <--- ¡CORRECCIÓN 1: Almacenar referencia!
# =========================================================


func _ready():
	# 1. Tablero del JUGADOR (Propio)
	tablero_propio = TABLERO_SCENE.instantiate() # Usamos la variable de clase
	add_child(tablero_propio)
	tablero_propio.name = "TableroPropio"
	tablero_propio.position = Vector2(50, 100)
	
	# CONFIGURACIÓN DEL TABLERO PROPIO
	tablero_propio.get_node("GridContainer2").mostrar_barcos = true
	
	# 2. Tablero del ENEMIGO (Objetivo)
	tablero_objetivo = TABLERO_SCENE.instantiate() # Usamos la variable de clase
	add_child(tablero_objetivo)
	tablero_objetivo.name = "TableroObjetivo" # ¡CORRECCIÓN 2: Un solo nombre!
	tablero_objetivo.position = Vector2(1200, 100) 
	
	# CONFIGURACIÓN DEL TABLERO OBJETIVO
	tablero_objetivo.get_node("GridContainer2").mostrar_barcos = false
	
	# Conexión para Ataque (solo el objetivo)
	tablero_objetivo.get_node("GridContainer2").ataque_realizado.connect(_on_disparo_realizado)
	
	print("Dos tableros instanciados y configurados. Conexiones listas.")
	iniciar_fase_colocacion()


func iniciar_fase_colocacion():
	# Crea el primer barco (ej: de 4 casillas)
	var barco_4 = BARCO_SCENE.instantiate()
	add_child(barco_4) # Añade el barco a la escena principal (Game.tscn)
	barco_4.longitud_casillas = 4

	# Conecta las señales del barco al Game Manager
	barco_4.barco_colocado.connect(_on_barco_colocado.bind(barco_4)) # <-- ¡Añade .bind(barco_4)!
	barco_4.position = Vector2(50, 50) 
	
	print("Fase de colocación iniciada. Arrastra el barco.")
	
# ¡CORRECCIÓN 3: Recibir el barco como argumento!
func _on_barco_colocado(barco: Area2D, posicion_final: Vector2):
	if fase_actual == Fase.COLOCACION:
		# Accedemos a la variable de clase corregida
		var offset_tablero = tablero_propio.position
		var cell_size = 50.0 # Usamos 50.0 para forzar flotante en la división

		# Calcular la coordenada lógica (0-9)
		var coord_x = floor((posicion_final.x - offset_tablero.x) / cell_size)
		var coord_y = floor((posicion_final.y - offset_tablero.y) / cell_size)

		if coord_x >= 0 and coord_x < 10 and coord_y >= 0 and coord_y < 10:
			print("Barco colocado en la cuadrícula: (", coord_x, ", ", coord_y, ")")
			
			# Lógica de Snap to Grid (Ajustar la posición visual)
			# La nueva posición central de la casilla es: 
			# Tablero_Posición + (Coordenada * Tamaño_Celda) + (Tamaño_Celda / 2)
			var snap_pos = offset_tablero + Vector2(coord_x * cell_size, coord_y * cell_size)
			
			# Fijar el barco a la nueva posición (Snap to Grid)
			barco.position = snap_pos
			
			# El barco ya está colocado, podemos añadirlo al tablero (lógica pendiente)
			
		else:
			print("Barco fuera del tablero. Regresando a posición inicial.")
			# Opcional: regresa el barco a su posición inicial si no está en la cuadrícula
			barco.position = Vector2(50, 50) 


func _on_disparo_realizado(coord: Vector2):
	print("¡Disparo del Jugador procesado en Game.gd! Coordenada: ", coord)
	pass
