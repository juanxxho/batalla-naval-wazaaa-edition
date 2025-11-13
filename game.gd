# Game.gd
extends Node2D

const TABLERO_SCENE = preload("res://mar.tscn")
const BARCO_SCENE = preload("res://Barco.tscn") # <-- 1. El Contenedor Lógico
const BARCO_SEGMENTO_SCENE = preload("res://BarcoSegmento.tscn") # <-- 2. La Pieza Visual (50x50px)
const CELL_SIZE = 50.0 # Tamaño de la celda

# =========================================================
# VARIABLES DE CLASE Y REFERENCIAS DE INTERFAZ
# =========================================================
enum Fase {COLOCACION, BATALLA}
var fase_actual = Fase.COLOCACION

# Referencias a los tableros (instanciados por código)
var tablero_propio: Node2D
var tablero_objetivo: Node2D

# Estado de la flota para la colocación
var barcos_flota: Dictionary = {
	"Portaaviones": { "longitud": 5, "restantes": 1, "nombre_visual": "Portaaviones" },
	"Acorazado": { "longitud": 4, "restantes": 1, "nombre_visual": "Acorazado" },
	"Submarino": { "longitud": 3, "restantes": 1, "nombre_visual": "Submarino" },
	"Destructor": { "longitud": 3, "restantes": 1, "nombre_visual": "Destructor" },
	"Patrulla": { "longitud": 2, "restantes": 1, "nombre_visual": "Patrulla" }
}
# Estado de la flota de la IA
var barcos_flota_ia: Dictionary = {
	"Portaaviones": { "longitud": 5, "restantes": 1, "nombre_visual": "Portaaviones" },
	"Acorazado": { "longitud": 4, "restantes": 1, "nombre_visual": "Acorazado" },
	"Submarino": { "longitud": 3, "restantes": 1, "nombre_visual": "Submarino" },
	"Destructor": { "longitud": 3, "restantes": 1, "nombre_visual": "Destructor" },
	"Patrulla": { "longitud": 2, "restantes": 1, "nombre_visual": "Patrulla" }
}
var barco_seleccionado_longitud: int = 0
var es_horizontal: bool = true # Estado de rotación

var barco_fantasma: Node2D = null # Ahora es solo un Node2D vacío

# @onready variables...
@onready var panel_selector: Control = $PanelSelector
@onready var boton_rotar: Button = $PanelSelector/BotonRotar
@onready var boton_portaaviones: Button = $PanelSelector/VBoxBarcos/BotonPortaaviones
@onready var boton_acorazado: Button = $PanelSelector/VBoxBarcos/BotonAcorazado
@onready var boton_submarino: Button = $PanelSelector/VBoxBarcos/BotonSubmarino
@onready var boton_destructor: Button = $PanelSelector/VBoxBarcos/BotonDestructor
@onready var boton_patrulla: Button = $PanelSelector/VBoxBarcos/BotonPatrulla


func _ready():
	tablero_propio = TABLERO_SCENE.instantiate()
	add_child(tablero_propio)
	tablero_propio.name = "TableroPropio"
	tablero_propio.position = Vector2(50, 100) # (50, 100) es el origen del tablero propio
	tablero_propio.get_node("GridContainer2").mostrar_barcos = true
	tablero_propio.get_node("GridContainer2").celda_cliqueada.connect(_on_tablero_propio_clic)
	
	tablero_objetivo = TABLERO_SCENE.instantiate()
	add_child(tablero_objetivo)
	tablero_objetivo.name = "TableroObjetivo"
	tablero_objetivo.position = Vector2(650, 100)
	tablero_objetivo.get_node("GridContainer2").mostrar_barcos = false
	tablero_objetivo.get_node("GridContainer2").celda_cliqueada.connect(_on_tablero_objetivo_clic)
	
	panel_selector.position = Vector2(50, 650)
	panel_selector.z_index = 10
	panel_selector.visible = true
	conectar_botones()
	
	# Iniciar la colocación automática y crear el fantasma para el primer barco
	seleccionar_siguiente_barco()
	
	print("Flota cargada y lista para la colocación (RF2).")

func _input(event):
	# Solo si estamos en fase de colocación Y tenemos un barco seleccionado
	if fase_actual == Fase.COLOCACION and barco_seleccionado_longitud > 0:
		if event is InputEventMouseMotion:
			if not barco_fantasma:
				crear_barco_fantasma() # Crea el fantasma si aún no existe
			
			actualizar_barco_fantasma_posicion(event.position)


func conectar_botones():
	boton_portaaviones.pressed.connect(_on_boton_barco_presionado.bind(5, "Portaaviones"))
	boton_acorazado.pressed.connect(_on_boton_barco_presionado.bind(4, "Acorazado"))
	boton_submarino.pressed.connect(_on_boton_barco_presionado.bind(3, "Submarino"))
	boton_destructor.pressed.connect(_on_boton_barco_presionado.bind(3, "Destructor"))
	boton_patrulla.pressed.connect(_on_boton_barco_presionado.bind(2, "Patrulla"))
	
	boton_rotar.pressed.connect(_on_boton_rotar_presionado)
	boton_rotar.text = "Rotar (Horizontal)"


# =========================================================
# Lógica de Avance y Transición
# =========================================================

func seleccionar_siguiente_barco():
	var barco_encontrado: bool = false
	
	for nombre in barcos_flota:
		if barcos_flota[nombre].restantes > 0:
			barco_seleccionado_longitud = barcos_flota[nombre].longitud
			print("AUTOMÁTICO: Siguiente barco seleccionado: ", nombre, " (", barco_seleccionado_longitud, ")")
			
			# Si se seleccionó uno, siempre recreamos el fantasma con la longitud correcta
			crear_barco_fantasma()
			
			barco_encontrado = true
			break
			
	if not barco_encontrado:
		print("TODOS LOS BARCOS DEL JUGADOR COLOCADOS. Iniciando Colocación de la IA...")
		
		# Asegúrate de que el último fantasma también se borre
		if barco_fantasma:
			barco_fantasma.queue_free()
			barco_fantasma = null
		
		iniciar_fase_ia_y_batalla()

func iniciar_fase_ia_y_batalla():
	if fase_actual != Fase.COLOCACION:
		return

	colocar_barcos_ia()
	
	panel_selector.visible = false
	fase_actual = Fase.BATALLA
	print("FASE DE BATALLA INICIADA. ¡Dispara al tablero enemigo!")

# =========================================================
# Lógica de Colocación de la IA
# =========================================================

func colocar_barcos_ia():
	print("COLOCANDO BARCOS DE LA IA...")
	
	var matriz_ia = tablero_objetivo.get_node("GridContainer2").estado_tablero
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for nombre in barcos_flota_ia:
		var longitud = barcos_flota_ia[nombre].longitud
		
		var colocado = false
		var intentos = 0
		const MAX_INTENTOS = 1000
		
		while not colocado and intentos < MAX_INTENTOS:
			intentos += 1
			
			# 1. Generar Posición y Rotación aleatorias
			var es_horizontal_ia = rng.randi_range(0, 1) == 0 # 0=Horizontal, 1=Vertical
			
			var max_x = 10 - (longitud if es_horizontal_ia else 1)
			var max_y = 10 - (longitud if not es_horizontal_ia else 1)
			
			var coord_x = rng.randi_range(0, max_x)
			var coord_y = rng.randi_range(0, max_y)
			var coord_ia = Vector2(coord_x, coord_y)
			
			# 2. Validar
			if _validar_colocacion_ia(coord_ia, longitud, es_horizontal_ia, matriz_ia):
				
				# 3. Colocar (usando función auxiliar)
				_colocar_barco_ia(coord_ia, longitud, es_horizontal_ia, matriz_ia)
				colocado = true
				
		if not colocado:
			print("ERROR: No se pudo colocar el barco ", nombre, " de la IA.")
	
	print("TODOS los barcos de la IA colocados.")

func _validar_colocacion_ia(coord: Vector2, longitud: int, horizontal: bool, matriz: Array) -> bool:
	var start_x = coord.x
	var start_y = coord.y

	for i in range(longitud):
		var current_x = start_x + (i if horizontal else 0)
		var current_y = start_y + (0 if horizontal else i)
		
		# Verifica superposición (Valor de celda != -1)
		if matriz[int(current_x)][int(current_y)] != -1:
			return false

	return true

func _colocar_barco_ia(coord: Vector2, longitud: int, horizontal: bool, matriz: Array):
	# Instanciar el CONTENEDOR LÓGICO (Barco.tscn)
	var barco_instancia = BARCO_SCENE.instantiate()
	# Añadir como hijo del TABLERO OBJETIVO
	tablero_objetivo.add_child(barco_instancia)
	
	# Configurar la posición relativa al tablero
	var celda_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
	barco_instancia.position = celda_pos
	barco_instancia.visible= true
	if not horizontal:
		# Desplazamiento de 50px a la derecha para la rotación de 90 grados
		barco_instancia.position += Vector2(CELL_SIZE, 0)

	barco_instancia.z_index = 10
	barco_instancia.longitud_casillas = longitud
	
	# Añadir los SEGMENTOS VISUALES
	for i in range(longitud):
		var segmento = BARCO_SEGMENTO_SCENE.instantiate()
		barco_instancia.add_child(segmento)
		
		if horizontal:
			segmento.rotation_degrees = 0
			segmento.position = Vector2(i * CELL_SIZE, 0)
		else:
			segmento.rotation_degrees = 90
			segmento.position = Vector2(0, i * CELL_SIZE)
			
	# Registrar en la matriz (1 = Barco de la IA)
	for i in range(longitud):
		var current_x = coord.x + (i if horizontal else 0)
		var current_y = coord.y + (0 if horizontal else i)
		
		matriz[int(current_x)][int(current_y)] = 1
		
# =========================================================
# Lógica de Previsualización (Fantasma)
# =========================================================

func crear_barco_fantasma():
	# Siempre eliminamos el viejo fantasma si existe para crear uno nuevo con la longitud correcta
	if barco_fantasma:
		barco_fantasma.queue_free()
		barco_fantasma = null

	if barco_seleccionado_longitud == 0:
		return

# El fantasma es un simple Node2D contenedor
	barco_fantasma = Node2D.new()
	# **SOLO ESTO:** Añádelo al TABLERO PROPIO (tablero_propio)
	tablero_propio.add_child(barco_fantasma)
	barco_fantasma.modulate = Color(1, 1, 1, 0.5)
	barco_fantasma.z_index = 20
	
	actualizar_barco_fantasma_apariencia()


func actualizar_barco_fantasma_apariencia():
	if not barco_fantasma or barco_seleccionado_longitud == 0:
		return
		
	# Aseguramos que el contenedor del fantasma esté limpio antes de añadir nuevos segmentos
	for child in barco_fantasma.get_children():
		child.queue_free()

	# Añadimos los segmentos
	for i in range(barco_seleccionado_longitud):
		var segmento = BARCO_SEGMENTO_SCENE.instantiate()
		barco_fantasma.add_child(segmento)
		
		# Posicionamos el segmento de 50x50px en el lugar correcto
		if es_horizontal:
			segmento.position = Vector2(i * CELL_SIZE, 0)
		else:
			segmento.rotation_degrees = 90
			segmento.position = Vector2(0, i * CELL_SIZE)
			
	# El fantasma debe estar posicionado en la esquina superior izquierda (0,0) del tablero propio
	# Ahora que es hijo del tablero, la posición es relativa
	barco_fantasma.position = Vector2(0, 0)


func actualizar_barco_fantasma_posicion(mouse_position: Vector2):
	if not barco_fantasma:
		return
	
	# Calcula la posición LOCAL respecto al TABLERO PROPIO (tablero_propio.position = (50, 100))
	var local_pos = mouse_position - tablero_propio.position
	
	var grid_x = floor(local_pos.x / CELL_SIZE)
	var grid_y = floor(local_pos.y / CELL_SIZE)
	
	# Ajusta los límites para que el final del barco no se salga
	var max_x = 10 - (barco_seleccionado_longitud if es_horizontal else 1)
	var max_y = 10 - (barco_seleccionado_longitud if not es_horizontal else 1)

	grid_x = clamp(grid_x, 0, max_x)
	grid_y = clamp(grid_y, 0, max_y)
	
	var celda_pos = Vector2(grid_x * CELL_SIZE, grid_y * CELL_SIZE)
	
	# Posiciona el contenedor del fantasma en la celda inicial (¡Sin sumar tablero_propio.position!)
	# La posición es relativa a su padre, que es tablero_propio.
	barco_fantasma.position = celda_pos
	
	# Si es vertical, el fantasma (contenedor) debe moverse un CELL_SIZE a la derecha
	if not es_horizontal:
		barco_fantasma.position += Vector2(CELL_SIZE, 0)


# =========================================================
# Lógica de Interfaz y Colocación (RF2)
# =========================================================

func _on_boton_barco_presionado(longitud: int, nombre: String):
	if barcos_flota[nombre].restantes > 0:
		barco_seleccionado_longitud = longitud
		print("Barco ", nombre, " (", longitud, " casillas) seleccionado.")
		crear_barco_fantasma()
	else:
		barco_seleccionado_longitud = 0
		print("¡Barcos de tipo ", nombre, " agotados!")
		if barco_fantasma:
			barco_fantasma.queue_free()
			barco_fantasma = null


func _on_boton_rotar_presionado():
	es_horizontal = !es_horizontal
	boton_rotar.text = "Rotar (" + ("Horizontal" if es_horizontal else "Vertical") + ")"
	print("Rotación cambiada a: ", "Horizontal" if es_horizontal else "Vertical")
	# Al rotar, recreamos el fantasma para que sus segmentos cambien de orientación
	if barco_fantasma:
		actualizar_barco_fantasma_apariencia()


func _on_tablero_propio_clic(coord: Vector2):
	if fase_actual == Fase.COLOCACION and barco_seleccionado_longitud > 0:
		var longitud = barco_seleccionado_longitud
		
		if validar_colocacion(coord, longitud, es_horizontal):
			colocar_barco(coord, longitud, es_horizontal)
			
			for nombre in barcos_flota:
				if barcos_flota[nombre].longitud == longitud and barcos_flota[nombre].restantes > 0:
					barcos_flota[nombre].restantes -= 1
					print("Quedan ", barcos_flota[nombre].restantes, " de ", nombre)
					break
			
			barco_seleccionado_longitud = 0
			
			# Borrar el fantasma después de colocarlo
			if barco_fantasma:
				barco_fantasma.queue_free()
				barco_fantasma = null
			
			seleccionar_siguiente_barco()
			
		else:
			print("Colocación NO VÁLIDA: Se superpone, se sale, o está muy cerca.")
			
	elif fase_actual == Fase.BATALLA:
		pass


func _on_tablero_objetivo_clic(coord: Vector2):
	if fase_actual == Fase.BATALLA:
		_on_disparo_realizado(coord)
	else:
		print("Esperando colocación de barcos...")

# ***************************************************************
# LÓGICA DE RF2: COLOCACIÓN FINAL
# ***************************************************************

func validar_colocacion(coord: Vector2, longitud: int, horizontal: bool) -> bool:
	# Asegura que el barco no se salga del tablero
	var start_x = coord.x
	var start_y = coord.y

	if horizontal:
		if start_x + longitud > 10: return false
	else:
		if start_y + longitud > 10: return false

	# Verifica superposición en la matriz de estado
	var matriz = tablero_propio.get_node("GridContainer2").estado_tablero
	
	for i in range(longitud):
		var current_x = start_x + (i if horizontal else 0)
		var current_y = start_y + (0 if horizontal else i)
		
		# Si el valor de la celda no es -1 (vacío), hay superposición
		if matriz[int(current_x)][int(current_y)] != -1:
			return false

	return true


func colocar_barco(coord: Vector2, longitud: int, horizontal: bool):
	# 1. Instanciar el CONTENEDOR LÓGICO (Barco.tscn)
	var barco_instancia = BARCO_SCENE.instantiate()
	# Añadir el barco como HIJO DEL TABLERO. ¡Esto es crucial!
	tablero_propio.add_child(barco_instancia)
	
	# 2. Configurar la posición del CONTENEDOR del barco
	# Ahora, la posición debe ser relativa al padre (tablero_propio)
	var celda_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
	barco_instancia.position = celda_pos
	
	# === CORRECCIÓN DE POSICIONAMIENTO VERTICAL (Se mantiene) ===
	if not horizontal:
		# Si es vertical, movemos el contenedor un CELL_SIZE a la derecha.
		barco_instancia.position += Vector2(CELL_SIZE, 0)
	# ==========================================================

	barco_instancia.z_index = 10
	barco_instancia.longitud_casillas = longitud
	
	# 3. Añadir los SEGMENTOS VISUALES (BarcoSegmento.tscn)
	for i in range(longitud):
		var segmento = BARCO_SEGMENTO_SCENE.instantiate()
		barco_instancia.add_child(segmento)
		
		# Posicionamos y rotamos cada segmento INDIVIDUALMENTE
		if horizontal:
			segmento.rotation_degrees = 0
			segmento.position = Vector2(i * CELL_SIZE, 0)
		else:
			segmento.rotation_degrees = 90
			segmento.position = Vector2(0, i * CELL_SIZE)
			
	# 4. Registrar en la matriz (0 = Barco del Jugador)
	var matriz = tablero_propio.get_node("GridContainer2").estado_tablero
	
	for i in range(longitud):
		var current_x = coord.x + (i if horizontal else 0)
		var current_y = coord.y + (0 if horizontal else i)
		
		matriz[int(current_x)][int(current_y)] = 0
		
	print("Barco colocado y registrado en la matriz.")

# ***************************************************************
# LÓGICA DE BATALLA (Disparo del Jugador y Turno de la IA)
# ***************************************************************

func _on_disparo_realizado(coord: Vector2):
	var x = int(coord.x)
	var y = int(coord.y)
	print("Turno del Jugador: Disparo a (", x, ", ", y, ")")
	
	var matriz_ia = tablero_objetivo.get_node("GridContainer2").estado_tablero
	var celda_actual = matriz_ia[x][y]
	
	# 1. Verificar si ya se disparó a esta celda
	if celda_actual == 2 or celda_actual == -2:
		print("Ya se disparó a esta posición. Intenta de nuevo.")
		return
	
	var es_impacto = false
	
	if celda_actual == 1:
		# ¡Impacto! (1 = Barco de la IA)
		print("¡IMPACTO en el barco enemigo!")
		matriz_ia[x][y] = 2 # 2 = Impacto
		es_impacto = true
	elif celda_actual == -1:
		# Agua
		print("Agua.")
		matriz_ia[x][y] = -2 # -2 = Agua
		
	# 2. Actualizar visualmente la celda en el tablero objetivo
	# NOTA: Debes tener implementada la función 'actualizar_celda_visual' en el script de tu GridContainer2
	tablero_objetivo.get_node("GridContainer2").actualizar_celda_visual(x, y, matriz_ia[x][y])
	
	# 3. Transición de turno
	if not es_impacto:
		print("Turno del Jugador finalizado. Turno de la IA...")
		# Usamos un timer para dar una pequeña pausa
		get_tree().create_timer(0.5).timeout.connect(turno_ia)
	else:
		print("¡Impacto! El jugador puede disparar de nuevo (Regla opcional de BattleShip)")
		# Por simplicidad, si impacta, el jugador tiene otro turno.

# =========================================================
# Lógica de Disparo de la IA (Simple)
# =========================================================

func turno_ia():
	# La IA dispara al tablero del jugador (tablero_propio)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var matriz_jugador = tablero_propio.get_node("GridContainer2").estado_tablero
	var disparo_valido = false
	var x: int
	var y: int
	
	# 1. Encontrar una celda aleatoria que no haya sido disparada
	while not disparo_valido:
		x = rng.randi_range(0, 9)
		y = rng.randi_range(0, 9)
		
		# Verificamos si la celda no es ya un Impacto (2) o Agua (-2)
		if matriz_jugador[x][y] != 2 and matriz_jugador[x][y] != -2:
			disparo_valido = true
			
	print("Turno de la IA: Disparo a (", x, ", ", y, ")")
	
	var celda_actual = matriz_jugador[x][y]
	var es_impacto = false
	
	if celda_actual == 0:
		# ¡Impacto! (0 = Barco del Jugador)
		print("¡EL ENEMIGO HA IMPACTADO UNO DE TUS BARCOS!")
		matriz_jugador[x][y] = 2 # 2 = Impacto
		es_impacto = true
	elif celda_actual == -1:
		# Agua
		print("El enemigo ha disparado a Agua.")
		matriz_jugador[x][y] = -2 # -2 = Agua
		
	# 2. Actualizar visualmente la celda en el tablero propio
	tablero_propio.get_node("GridContainer2").actualizar_celda_visual(x, y, matriz_jugador[x][y])

	# 3. Transición de turno
	if es_impacto:
		print("¡Impacto de la IA! La IA dispara de nuevo.")
		get_tree().create_timer(0.5).timeout.connect(turno_ia)
	else:
		print("Turno de la IA finalizado. Turno del Jugador.")
		# Podrías querer mostrar algún mensaje de "Tu Turno" aquí.
