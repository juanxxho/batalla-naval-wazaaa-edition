extends Node2D

const FILAS = 10
const COLUMNAS = 10

@onready var tablero_jugador = $HBoxContainer/TableroJugador
@onready var tablero_enemigo = $HBoxContainer/TableroEnemigo

# Configuración de flota clásica
var flota = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]

var barcos_jugador = {}
var barcos_restantes = flota.duplicate()

func _ready():
	generar_tablero(tablero_jugador, "J")
	generar_tablero(tablero_enemigo, "E")
	print("Coloca tus barcos. Restantes: ", barcos_restantes)

func generar_tablero(tablero: GridContainer, prefijo: String):
	for fila in range(FILAS):
		for col in range(COLUMNAS):
			var boton = Button.new()
			boton.name = "%s_%d_%d" % [prefijo, fila, col]
			boton.text = ""
			boton.custom_minimum_size = Vector2(40, 40)

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.8) # azul mar
			boton.add_theme_stylebox_override("normal", style)

			boton.connect("pressed", Callable(self, "_on_casilla_pressed").bind(fila, col, tablero, prefijo))
			tablero.add_child(boton)

func _on_casilla_pressed(fila: int, col: int, tablero: GridContainer, prefijo: String):
	if prefijo != "J":
		return # solo jugador coloca barcos

	if barcos_restantes.is_empty():
		print("Ya colocaste toda la flota")
		return

	var size = barcos_restantes[0] # tamaño del barco actual
	if puede_colocar(fila, col, size, "horizontal"): # probamos horizontal
		colocar_barco(fila, col, size, "horizontal", tablero, prefijo)
		barcos_restantes.pop_front()
		print("Barco colocado! Restantes:", barcos_restantes)
	else:
		print("No se puede poner barco aquí")

func puede_colocar(fila: int, col: int, size: int, orientacion: String) -> bool:
	if orientacion == "horizontal":
		if col + size > COLUMNAS:
			return false
		for i in range(size):
			if barcos_jugador.has(Vector2(fila, col + i)):
				return false
			if _tiene_vecinos(fila, col + i):
				return false
		return true  # 👈 este return debe estar dentro del bloque
	return false

func colocar_barco(fila: int, col: int, size: int, orientacion: String, tablero: GridContainer, prefijo: String):
	for i in range(size):
		var pos: Vector2
		if orientacion == "horizontal":
			pos = Vector2(fila, col + i)
		else: # vertical
			pos = Vector2(fila + i, col)
		
		barcos_jugador[pos] = true
		var boton = tablero.get_node("%s_%d_%d" % [prefijo, pos.x, pos.y])
		_pintar_boton(boton, Color(0.3, 0.3, 0.3))


func _pintar_boton(boton: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	boton.add_theme_stylebox_override("normal", style)

func _tiene_vecinos(fila: int, col: int) -> bool:
	for df in range(-1,2):
		for dc in range(-1,2):
			if df == 0 and dc == 0: continue
			var pos = Vector2(fila + df, col + dc)
			if barcos_jugador.has(pos): return true
	return false
