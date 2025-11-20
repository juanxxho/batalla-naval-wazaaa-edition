extends Node2D

const TABLERO_SCENE = preload("res://mar.tscn")
const BARCO_SCENE = preload("res://Barco.tscn")
const BARCO_SEGMENTO_SCENE = preload("res://BarcoSegmento.tscn")
const CELL_SIZE = 50.0 # Tamaño de la celda

# =========================================================
# VARIABLES DE CLASE Y COSTOS
# =========================================================
enum Fase {COLOCACION, COLOCACION_IA, BATALLA, FIN_JUEGO}
var fase_actual = Fase.COLOCACION

var barcos_jugador_hundidos: int = 0
var barcos_ia_hundidos: int = 0
const TOTAL_BARCOS: int = 5

# === MONEDAS Y DISPAROS ESPECIALES (RF3, RF4, RF5, RF6) ===
var monedas_jugador: int = 50
var monedas_ia: int = 50
var tipo_disparo_actual: String = "Mortero" # Por defecto (Gratuito)

const COSTO_COHETE: int = 10
const COSTO_SONAR: int = 20
const COSTO_AREA: int = 30
# =========================================================

# Referencias a los tableros (instanciados por código)
var tablero_propio: Node2D
var tablero_objetivo: Node2D

# Estado de la flota
var barcos_flota: Dictionary = {
	"Portaaviones": { "longitud": 5, "restantes": 1, "nombre_visual": "Portaaviones" },
	"Acorazado": { "longitud": 4, "restantes": 1, "nombre_visual": "Acorazado" },
	"Submarino": { "longitud": 3, "restantes": 1, "nombre_visual": "Submarino" },
	"Destructor": { "longitud": 3, "restantes": 1, "nombre_visual": "Destructor" },
	"Patrulla": { "longitud": 2, "restantes": 1, "nombre_visual": "Patrulla" }
}
var barcos_flota_ia: Dictionary = barcos_flota.duplicate(true)
var barco_seleccionado_longitud: int = 0
var es_horizontal: bool = true

var barco_fantasma: Node2D = null

# === ULTI (RF7) ===
var ulti_cargada: float = 0.0 # Porcentaje de carga (0.0 a 100.0)
const CARGA_POR_IMPACTO_PROPIO: float = 10.0 # 10% por acierto (jugador)
const CARGA_POR_IMPACTO_ENEMIGO: float = 5.0 # 5% por acierto (IA)
const CARGA_POR_HUNDIMIENTO: float = 20.0 # 20% por hundir un barco
const CARGA_POR_FALLO_PROPIO: float = 5.0 # 5% por fallo del jugador (NUEVO)
var ulti_disponible: bool = false
# ===================

# === ESTADO DE LA IA (Caza) ===
enum IAfase {BUSQUEDA, CAZA}
var ia_fase: IAfase = IAfase.BUSQUEDA
var impactos_pendientes: Array[Vector2] = [] # Coordenadas de impactos de la IA en un barco no hundido.
var posibles_objetivos: Array[Vector2] = [] # Coordenadas adyacentes a explorar.
# ==============================
# === Variables de Flujo y Estado ===
enum Tablero {PROPIO, IA}
var tablero_actual: Tablero = Tablero.IA


# Lista para manejar los barcos que quedan por colocar por el jugador
var barcos_restantes: Array = [
	{ "nombre": "Portaaviones", "longitud": 5 },
	{ "nombre": "Acorazado", "longitud": 4 },
	{ "nombre": "Submarino", "longitud": 3 },
	{ "nombre": "Destructor", "longitud": 3 },
	{ "nombre": "Patrulla", "longitud": 2 }
]
# ==================================

# @onready variables de Interfaz
@onready var panel_selector: Control = $PanelSelector
@onready var boton_rotar: Button = $PanelSelector/BotonRotar
# === BOTONES DE COLOCACIÓN (Añadido: Asignación visual) ===
@onready var boton_portaaviones: Button = $PanelSelector/VBoxBarcos/BotonPortaaviones
@onready var boton_acorazado: Button = $PanelSelector/VBoxBarcos/BotonAcorazado
@onready var boton_submarino: Button = $PanelSelector/VBoxBarcos/BotonSubmarino
@onready var boton_destructor: Button = $PanelSelector/VBoxBarcos/BotonDestructor
@onready var boton_patrulla: Button = $PanelSelector/VBoxBarcos/BotonPatrulla
# ========================================================
@onready var resultado_label: RichTextLabel = $ResultadoLabel
@onready var label_monedas: Label = $CanvasLayer/MonedasLabel
# === REFERENCIAS DE DISPAROS ESPECIALES ===
@onready var disparos_panel: Control = $DisparosPanel # Agregado: Referencia al panel completo
@onready var boton_mortero: Button = $DisparosPanel/BotonMortero
@onready var boton_cohete: Button = $DisparosPanel/BotonCohete
@onready var boton_sonar: Button = $DisparosPanel/BotonSonar
@onready var boton_area: Button = $DisparosPanel/BotonArea
@onready var boton_ulti: Button = $DisparosPanel/BotonUlti # Asumiendo que el nombre es BotonUlti
# ==========================================


func _ready():
	tablero_propio = TABLERO_SCENE.instantiate()
	add_child(tablero_propio)
	tablero_propio.name = "TableroPropio"
	tablero_propio.position = Vector2(50, 100)
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
	
	# --- VISUALIZACIÓN INICIAL ---
	disparos_panel.visible = false # Ocultamos el panel de disparos hasta la batalla
	resultado_label.visible = false # Ocultamos el label de resultado
	actualizar_textos_botones_barco()
	actualizar_textos_botones_disparo()
	conectar_botones()
	actualizar_interfaz_monedas() # Se llama al final para asegurar que label_monedas exista
	# -----------------------------
	
	# --- INICIALIZACIÓN DE FANTASMA Y SELECCIÓN ---
	if not barcos_restantes.is_empty():
		barco_seleccionado_longitud = barcos_restantes[0].longitud
	
	crear_barco_fantasma()
	# ----------------------------------------------
	
	set_process_input(true)
	print("Flota cargada y lista para la colocación.")

# =========================================================
# FUNCIONES DE INTERFAZ Y UTILIDAD
# =========================================================

func actualizar_interfaz_monedas():
	if label_monedas:
		label_monedas.text = "MONEDAS: " + str(monedas_jugador)
		
# --- NUEVA FUNCIÓN: Actualizar textos de botones de barco ---
func actualizar_textos_botones_barco():
	boton_portaaviones.text = "Portaaviones (5)"
	boton_acorazado.text = "Acorazado (4)"
	boton_submarino.text = "Submarino (3)"
	boton_destructor.text = "Destructor (3)"
	boton_patrulla.text = "Patrulla (2)"
	
# --- NUEVA FUNCIÓN: Actualizar textos de botones de disparo ---
func actualizar_textos_botones_disparo():
	var mortero_text = "Mortero"
	var cohete_text = "Cohete (%d M)" % COSTO_COHETE
	var sonar_text = "Sonar (%d M)" % COSTO_SONAR
	var area_text = "Área (%d M)" % COSTO_AREA
	var ulti_text = "ULTI"

	if tipo_disparo_actual == "Mortero": mortero_text = "🎯 " + mortero_text
	if tipo_disparo_actual == "Cohete": cohete_text = "🎯 " + cohete_text
	if tipo_disparo_actual == "Sonar": sonar_text = "🎯 " + sonar_text
	if tipo_disparo_actual == "Area": area_text = "🎯 " + area_text
	if tipo_disparo_actual == "Ulti": ulti_text = "🎯 " + ulti_text
	
	if boton_mortero: boton_mortero.text = mortero_text
	if boton_cohete: boton_cohete.text = cohete_text
	if boton_sonar: boton_sonar.text = sonar_text
	if boton_area: boton_area.text = area_text
	if boton_ulti: boton_ulti.text = ulti_text # Asumiendo que esta referencia es correcta
		
func _desactivar_boton_barco(nombre_barco: String):
	var boton: Button = null
	var longitud: int = 0
	match nombre_barco:
		"Portaaviones": boton = boton_portaaviones; longitud = 5
		"Acorazado": boton = boton_acorazado; longitud = 4
		"Submarino": boton = boton_submarino; longitud = 3
		"Destructor": boton = boton_destructor; longitud = 3
		"Patrulla": boton = boton_patrulla; longitud = 2
	
	if boton:
		boton.disabled = true
		boton.text = nombre_barco + " (%d) (Colocado)" % longitud

func _input(event):
	if fase_actual == Fase.COLOCACION and barco_seleccionado_longitud > 0:
		if event is InputEventMouseMotion:
			if not barco_fantasma:
				crear_barco_fantasma()
			
			actualizar_barco_fantasma_posicion(tablero_propio.get_global_mouse_position())
			
		if event.is_action_pressed("mouse_right") or event.is_action_pressed("rotar"):
			_on_boton_rotar_presionado()

func cargar_ulti(cantidad: float):
	if ulti_disponible:
		return
		
	ulti_cargada += cantidad
	
	if ulti_cargada >= 100.0:
		ulti_cargada = 100.0
		ulti_disponible = true
		print("¡ULTI DISPONIBLE!")
		# Aquí se actualizaría la barra visual

	print("Ulti cargada: %s%%" % ulti_cargada)
	# Si tienes una barra de ulti, actualiza aquí.

func conectar_botones():
	# Botones de colocación de barcos
	boton_portaaviones.pressed.connect(_on_boton_barco_presionado.bind(5, "Portaaviones"))
	boton_acorazado.pressed.connect(_on_boton_barco_presionado.bind(4, "Acorazado"))
	boton_submarino.pressed.connect(_on_boton_barco_presionado.bind(3, "Submarino"))
	boton_destructor.pressed.connect(_on_boton_barco_presionado.bind(3, "Destructor"))
	boton_patrulla.pressed.connect(_on_boton_barco_presionado.bind(2, "Patrulla"))
	boton_rotar.pressed.connect(_on_boton_rotar_presionado)
	boton_rotar.text = "Rotar (Horizontal)"
	
	
	# === CONEXIÓN DE DISPAROS ESPECIALES ===
	if boton_mortero:
		boton_mortero.pressed.connect(_on_boton_disparo_seleccionado.bind("Mortero", 0))
	if boton_cohete:
		boton_cohete.pressed.connect(_on_boton_disparo_seleccionado.bind("Cohete", COSTO_COHETE))
	if boton_sonar:
		boton_sonar.pressed.connect(_on_boton_disparo_seleccionado.bind("Sonar", COSTO_SONAR))
	if boton_area:
		boton_area.pressed.connect(_on_boton_disparo_seleccionado.bind("Area", COSTO_AREA))
	if boton_ulti:
		boton_ulti.pressed.connect(_on_boton_disparo_seleccionado.bind("Ulti", 0))


# =========================================================
# Lógica de Avance y Transición
# =========================================================

func _colocar_barcos_ia():
	print("Ejecutando la colocación de barcos de la IA...")
	
	colocar_barcos_ia()
	
	# Transición a fase de batalla
	fase_actual = Fase.BATALLA
	disparos_panel.visible = true # Hacemos visible el panel de disparos
	print("TODOS los barcos de la IA colocados.")
	print("FASE DE BATALLA INICIADA. ¡Dispara al tablero enemigo!")

func ejecutar_disparo_jugador(coord: Vector2, es_impacto: bool):
	print("Jugador disparando a la coordenada: ", coord)
	
	# CORRECCIÓN DE FLUJO: Solo pasamos el turno si NO es impacto Y el juego sigue en BATALLA
	if not es_impacto and fase_actual == Fase.BATALLA:
		print("Turno del Jugador finalizado. Turno de la IA...")
		get_tree().create_timer(0.5).timeout.connect(turno_ia)
	elif es_impacto and fase_actual == Fase.BATALLA:
		print("¡Impacto! El jugador puede disparar de nuevo.")
	# Si la fase_actual es FIN_JUEGO, no hacemos nada y el juego se detiene.

func seleccionar_siguiente_barco():
	# Esta función ya no es estrictamente necesaria porque la colocación es por lista, 
	# pero la dejamos por si acaso
	var barco_encontrado: bool = false
	
	for nombre in barcos_flota:
		if barcos_flota[nombre].restantes > 0:
			barco_seleccionado_longitud = barcos_flota[nombre].longitud
			print("AUTOMÁTICO: Siguiente barco seleccionado: ", nombre, " (", barco_seleccionado_longitud, ")")
			
			crear_barco_fantasma()
			
			barco_encontrado = true
			break
			
	if not barco_encontrado:
		print("TODOS LOS BARCOS DEL JUGADOR COLOCADOS. Iniciando Colocación de la IA...")
		
		if barco_fantasma:
			barco_fantasma.queue_free()
			barco_fantasma = null
		
		iniciar_fase_ia_y_batalla()

func iniciar_fase_ia_y_batalla():
	if fase_actual != Fase.COLOCACION:
		return

	_colocar_barcos_ia()
	
	panel_selector.visible = false

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
			
			var es_horizontal_ia = rng.randi_range(0, 1) == 0
			
			var max_x = 10 - (longitud if es_horizontal_ia else 1)
			var max_y = 10 - (longitud if not es_horizontal_ia else 1)
			
			var coord_x = rng.randi_range(0, max_x)
			var coord_y = rng.randi_range(0, max_y)
			var coord_ia = Vector2(coord_x, coord_y)
			
			if _validar_colocacion_ia(coord_ia, longitud, es_horizontal_ia, matriz_ia):
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
		
		if matriz[int(current_x)][int(current_y)] != -1:
			return false

	return true

func _colocar_barco_ia(coord: Vector2, longitud: int, horizontal: bool, matriz: Array):
	var barco_instancia = BARCO_SCENE.instantiate()
	tablero_objetivo.add_child(barco_instancia)
	
	barco_instancia.visible = false
	
	var celda_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
	barco_instancia.position = celda_pos
	
	if not horizontal:
		# La IA tiene la misma compensación visual que el jugador
		barco_instancia.position -= Vector2(0, CELL_SIZE)
		
	barco_instancia.z_index = 10
	# CORRECCIÓN CLAVE: Asignar propiedades y meta para _es_barco_hundido
	barco_instancia.longitud_casillas = longitud
	# CORRECCIÓN CLAVE: Añadir meta-propiedad
	barco_instancia.set_meta("longitud_casillas", longitud)
	barco_instancia.rotation_degrees = 90 if not horizontal else 0
	
	for i in range(longitud):
		var segmento = BARCO_SEGMENTO_SCENE.instantiate()
		barco_instancia.add_child(segmento)
		segmento.position = Vector2(i * CELL_SIZE, 0)
			
	for i in range(longitud):
		var current_x = coord.x + (i if horizontal else 0)
		var current_y = coord.y + (0 if horizontal else i)
		
		matriz[int(current_x)][int(current_y)] = 1

# =========================================================
# Lógica de Previsualización (Fantasma)
# =========================================================

func crear_barco_fantasma():
	if barco_fantasma:
		barco_fantasma.queue_free()
		barco_fantasma = null

	if barco_seleccionado_longitud == 0:
		return

	barco_fantasma = Node2D.new()
	tablero_propio.add_child(barco_fantasma)
	barco_fantasma.modulate = Color(1, 1, 1, 0.5)
	barco_fantasma.z_index = 20
	
	actualizar_barco_fantasma_apariencia()


func actualizar_barco_fantasma_apariencia():
	if not barco_fantasma or barco_seleccionado_longitud == 0:
		return
		
	for child in barco_fantasma.get_children():
		child.queue_free()

	for i in range(barco_seleccionado_longitud):
		var segmento = BARCO_SEGMENTO_SCENE.instantiate()
		barco_fantasma.add_child(segmento)
		segmento.position = Vector2(i * CELL_SIZE, 0)
			
	if not es_horizontal:
		barco_fantasma.rotation_degrees = 90
	else:
		barco_fantasma.rotation_degrees = 0


func actualizar_barco_fantasma_posicion(mouse_position: Vector2):
	if not barco_fantasma:
		return
	
	var local_pos = mouse_position - tablero_propio.position
	
	var grid_x = floor(local_pos.x / CELL_SIZE)
	var grid_y = floor(local_pos.y / CELL_SIZE)
	
	var max_x = 10 - (barco_seleccionado_longitud if es_horizontal else 1)
	var max_y = 10 - (barco_seleccionado_longitud if not es_horizontal else 1)

	grid_x = clamp(grid_x, 0, max_x)
	grid_y = clamp(grid_y, 0, max_y)
	
	var celda_pos = Vector2(grid_x * CELL_SIZE, grid_y * CELL_SIZE)
	
	if not es_horizontal:
		# Aplicar compensación visual para el pivot rotado
		celda_pos -= Vector2(0, CELL_SIZE)
	
	barco_fantasma.position = celda_pos


# =========================================================
# Lógica de Interfaz y Colocación (RF2)
# =========================================================

func _on_boton_barco_presionado(longitud: int, nombre: String):
	if fase_actual != Fase.COLOCACION: return
	
	if barcos_flota[nombre].restantes > 0:
		barco_seleccionado_longitud = longitud
		print("Barco ", nombre, " (", longitud, " casillas) seleccionado.")
		crear_barco_fantasma()
		actualizar_textos_botones_barco() # Opcional: Para resetear colores de selección si los tuvieras
	else:
		barco_seleccionado_longitud = 0
		print("¡Barcos de tipo ", nombre, " agotados!")
		if barco_fantasma:
			barco_fantasma.hide()
			barco_fantasma.queue_free()
			barco_fantasma = null


func _on_boton_rotar_presionado():
	if fase_actual != Fase.COLOCACION: return
	
	es_horizontal = !es_horizontal
	boton_rotar.text = "Rotar (" + ("Horizontal" if es_horizontal else "Vertical") + ")"
	print("Rotación cambiada a: ", "Horizontal" if es_horizontal else "Vertical")
	if barco_fantasma:
		actualizar_barco_fantasma_apariencia()
		actualizar_barco_fantasma_posicion(tablero_propio.get_global_mouse_position())


# =========================================================
# LÓGICA DE SELECCIÓN DE DISPARO
# =========================================================

func _on_boton_disparo_seleccionado(nombre_disparo: String, costo: int):
	if fase_actual != Fase.BATALLA:
		return
		
	if nombre_disparo == "Ulti" and not ulti_disponible:
		print("La habilidad Ulti no está cargada.")
		tipo_disparo_actual = "Mortero"
	elif costo > 0 and monedas_jugador < costo:
		print("Monedas insuficientes para usar " + nombre_disparo + ".")
		tipo_disparo_actual = "Mortero"
	else:
		tipo_disparo_actual = nombre_disparo
		print("Disparo seleccionado: " + tipo_disparo_actual)
		
	actualizar_textos_botones_disparo() # LLAMADA CLAVE: Actualiza el texto con el "🎯"
		
# =========================================================
# Lógica de Colocación y Validación
# =========================================================

func _on_tablero_propio_clic(_coord: Vector2):
	if fase_actual == Fase.COLOCACION and barco_seleccionado_longitud > 0:
		
		var x_fantasma_visual = barco_fantasma.position.x
		var y_fantasma_visual = barco_fantasma.position.y
		
		var grid_x = floor(x_fantasma_visual / CELL_SIZE)
		var grid_y = floor(y_fantasma_visual / CELL_SIZE)
		
		if not es_horizontal:
			grid_y += 1 # Compensación INVERSA (ya que en posicionamiento se restó 1 celda)

		var coord_final_colocacion = Vector2(grid_x, grid_y)
		
		var longitud = barco_seleccionado_longitud
		
		if validar_colocacion(coord_final_colocacion, longitud, es_horizontal):
			# Encontrar el nombre del barco colocado
			var nombre_barco_colocado = ""
			for barco_data in barcos_restantes:
				if barco_data.longitud == longitud:
					nombre_barco_colocado = barco_data.nombre
					break
					
			colocar_barco(coord_final_colocacion, longitud, es_horizontal)
			_desactivar_boton_barco(nombre_barco_colocado) # Desactiva el botón
			
			barcos_restantes.pop_front()
			
			if barco_fantasma:
				barco_fantasma.hide()
				barco_fantasma.queue_free()
				barco_fantasma = null
				
			barco_seleccionado_longitud = 0
			
			if not barcos_restantes.is_empty():
				var siguiente_barco = barcos_restantes[0]
				barco_seleccionado_longitud = siguiente_barco.longitud
				print("AUTOMÁTICO: Siguiente barco seleccionado: ", siguiente_barco.nombre, " (", siguiente_barco.longitud, ")")
				crear_barco_fantasma()
				actualizar_barco_fantasma_posicion(tablero_propio.get_global_mouse_position())

			else:
				print("TODOS LOS BARCOS DEL JUGADOR COLOCADOS. Iniciando Colocación de la IA...")
				fase_actual = Fase.COLOCACION_IA
				get_tree().create_timer(0.5).timeout.connect(_colocar_barcos_ia)
		else:
			print("Colocación no válida en (", coord_final_colocacion.x, ", ", coord_final_colocacion.y, ").")
			
	elif fase_actual == Fase.BATALLA and tablero_actual == Tablero.IA:
		pass

func validar_colocacion(coord: Vector2, longitud: int, horizontal: bool) -> bool:
	var start_x = coord.x
	var start_y = coord.y

	if horizontal:
		if start_x + longitud > 10: return false
	else:
		if start_y + longitud > 10: return false

	var matriz = tablero_propio.get_node("GridContainer2").estado_tablero
	
	for i in range(longitud):
		var current_x = int(start_x + (i if horizontal else 0))
		var current_y = int(start_y + (0 if horizontal else i))
		
		if current_x >= 0 and current_x < 10 and current_y >= 0 and current_y < 10:
			if matriz[current_x][current_y] != -1:
				print("Validación fallida en celda (", current_x, ", ", current_y, ").")
				return false
		else:
			print("Validación fallida: Fuera de límites (", current_x, ", ", current_y, ")")
			return false

	return true


func colocar_barco(coord: Vector2, longitud: int, horizontal: bool):
	var barco_instancia = BARCO_SCENE.instantiate()
	tablero_propio.add_child(barco_instancia)
	
	var celda_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
	barco_instancia.position = celda_pos
	
	barco_instancia.z_index = 10
	# CORRECCIÓN CLAVE: Asignar propiedades y meta para _es_barco_hundido
	barco_instancia.longitud_casillas = longitud
	# CORRECCIÓN CLAVE: Añadir meta-propiedad
	barco_instancia.set_meta("longitud_casillas", longitud)
	
	if not horizontal:
		barco_instancia.rotation_degrees = 90
		# Compensación visual del barco colocado
		barco_instancia.position -= Vector2(0, CELL_SIZE)
	else:
		barco_instancia.rotation_degrees = 0

	for i in range(longitud):
		var segmento = BARCO_SEGMENTO_SCENE.instantiate()
		barco_instancia.add_child(segmento)
		segmento.position = Vector2(i * CELL_SIZE, 0)
			
	var matriz = tablero_propio.get_node("GridContainer2").estado_tablero
	
	for i in range(longitud):
		var current_x = coord.x + (i if horizontal else 0)
		var current_y = coord.y + (0 if horizontal else i)
		
		matriz[int(current_x)][int(current_y)] = 0
		
	print("Barco colocado y registrado en la matriz.")

# =========================================================
# LÓGICA CENTRAL DE IMPACTO Y DAÑO
# =========================================================

func _ejecutar_impacto_en_celda(x: int, y: int, tablero: Node2D) -> bool:
	if x < 0 or x > 9 or y < 0 or y > 9:
		return false
		
	var matriz = tablero.get_node("GridContainer2").estado_tablero
	var coord = Vector2(x, y)
	var es_impacto = false
	
	if matriz[x][y] == 2 or matriz[x][y] == -2:
		return false
		
	# Tablero IA (Enemigo) - Jugador Ataca
	if tablero == tablero_objetivo:
		if matriz[x][y] == 1:
			matriz[x][y] = 2
			es_impacto = true
			
			monedas_jugador += 5
			cargar_ulti(CARGA_POR_IMPACTO_PROPIO)
			
			if _registrar_impacto_en_barco(tablero_objetivo, coord, true):
				monedas_jugador += 15
				cargar_ulti(CARGA_POR_HUNDIMIENTO)
				barcos_ia_hundidos += 1
				check_win_condition()
				
			actualizar_interfaz_monedas() # CLAVE: Actualiza monedas después de ganar

		elif matriz[x][y] == -1:
			matriz[x][y] = -2
			cargar_ulti(CARGA_POR_FALLO_PROPIO) # Carga por Fallo del Jugador
			
	# Tablero Jugador - IA Ataca
	elif tablero == tablero_propio:
		if matriz[x][y] == 0:
			matriz[x][y] = 2
			es_impacto = true
			cargar_ulti(CARGA_POR_IMPACTO_ENEMIGO)

			if _registrar_impacto_en_barco(tablero_propio, coord, false):
				barcos_jugador_hundidos += 1
				check_win_condition()
				
		elif matriz[x][y] == -1:
			matriz[x][y] = -2

	# CLAVE: Asegura que la celda se actualice VISUALMENTE
	tablero.get_node("GridContainer2").actualizar_celda_visual(x, y, matriz[x][y])
	
	return es_impacto

# =========================================================
# LÓGICA DE DISPAROS ESPECÍFICOS (RF3, RF4, RF5, RF6, RF7)
# =========================================================

func _ejecutar_disparo_mortero(coord: Vector2) -> bool:
	var x = int(coord.x)
	var y = int(coord.y)
	return _ejecutar_impacto_en_celda(x, y, tablero_objetivo)

func _ejecutar_disparo_cohete(coord: Vector2) -> bool:
	print("Cohete disparado: Impacto dual.")
	var x = int(coord.x)
	var y = int(coord.y)
	
	var impacto1 = _ejecutar_impacto_en_celda(x, y, tablero_objetivo)
	var impacto2 = _ejecutar_impacto_en_celda(x + 1, y, tablero_objetivo)
		
	return impacto1 or impacto2

func _ejecutar_disparo_sonar(coord: Vector2) -> bool:
	print("Sonar activado. Revelando área 3x3...")
	var x_center = int(coord.x)
	var y_center = int(coord.y)
	
	var matriz = tablero_objetivo.get_node("GridContainer2").estado_tablero
	var grid_container = tablero_objetivo.get_node("GridContainer2")
	
	for i in range(-1, 2):
		for j in range(-1, 2):
			
			var target_x = x_center + i
			var target_y = y_center + j
			
			if target_x >= 0 and target_x <= 9 and target_y >= 0 and target_y <= 9:
				var estado_actual = matriz[target_x][target_y]
				
				# CLAVE: Solo revela el estado (1=barco, -1=agua) si aún no ha sido impactado
				if estado_actual == -1 or estado_actual == 1:
					grid_container.actualizar_celda_visual(target_x, target_y, estado_actual)

	return false

func _ejecutar_disparo_area(coord: Vector2) -> bool:
	print("Disparo en Área 3x3. ¡BOOM! Destrucción masiva.")
	var x_center = int(coord.x)
	var y_center = int(coord.y)
	var impacto_total = false
	
	for i in range(-1, 2):
		for j in range(-1, 2):
			
			var target_x = x_center + i
			var target_y = y_center + j
			
			var impacto_celda = _ejecutar_impacto_en_celda(target_x, target_y, tablero_objetivo)
			
			if impacto_celda:
				impacto_total = true
				
	return impacto_total

func _ejecutar_disparo_ulti(coord: Vector2) -> bool:
	if not ulti_disponible:
		print("ERROR: La habilidad Ulti no está disponible.")
		return false
		
	print("¡ULTI ACTIVADA! Impacto devastador 5x5.")
	var x_center = int(coord.x)
	var y_center = int(coord.y)
	var impacto_total = false
	
	for i in range(-2, 3):
		for j in range(-2, 3):
			
			var target_x = x_center + i
			var target_y = y_center + j
			
			var impacto_celda = _ejecutar_impacto_en_celda(target_x, target_y, tablero_objetivo)
			
			if impacto_celda:
				impacto_total = true
	
	ulti_cargada = 0.0
	ulti_disponible = false
	print("Ulti utilizada. Reiniciando carga.")
	
	return impacto_total
	
	
# =========================================================
# LÓGICA DE TURNO (CONTROL DE FLUJO)
# =========================================================

func _on_tablero_objetivo_clic(coord: Vector2):
	if fase_actual != Fase.BATALLA: # GUARDA DE ESTADO
		print("El juego ha terminado o no ha empezado.")
		return
		
	var es_impacto = false
	var costo_disparo = 0
	var disparo_seleccionado = tipo_disparo_actual # Capturamos el tipo antes de resetearlo
	
	# La lógica de selección de disparo se realiza al presionar el botón
	# Aquí solo se valida y se ejecuta
	match disparo_seleccionado:
		"Mortero":
			es_impacto = _ejecutar_disparo_mortero(coord)
		"Cohete":
			costo_disparo = COSTO_COHETE
			if monedas_jugador >= costo_disparo:
				es_impacto = _ejecutar_disparo_cohete(coord)
				monedas_jugador -= costo_disparo
			else:
				print("ERROR: Monedas insuficientes para Cohete. Usando Mortero.")
				disparo_seleccionado = "Mortero"
				es_impacto = _ejecutar_disparo_mortero(coord)
		"Sonar":
			costo_disparo = COSTO_SONAR
			if monedas_jugador >= costo_disparo:
				_ejecutar_disparo_sonar(coord)
				monedas_jugador -= costo_disparo
				# El sonar nunca devuelve impacto (es solo revelación), forzamos el paso de turno
				es_impacto = false 
			else:
				print("ERROR: Monedas insuficientes para Sonar. Usando Mortero.")
				disparo_seleccionado = "Mortero"
				es_impacto = _ejecutar_disparo_mortero(coord)
		"Area":
			costo_disparo = COSTO_AREA
			if monedas_jugador >= costo_disparo:
				es_impacto = _ejecutar_disparo_area(coord)
				monedas_jugador -= costo_disparo
			else:
				print("ERROR: Monedas insuficientes para Área. Usando Mortero.")
				disparo_seleccionado = "Mortero"
				es_impacto = _ejecutar_disparo_mortero(coord)
		"Ulti":
			costo_disparo = 0
			if ulti_disponible:
				es_impacto = _ejecutar_disparo_ulti(coord)
			else:
				print("ERROR: Ulti no cargada. Usando Mortero.")
				disparo_seleccionado = "Mortero"
				es_impacto = _ejecutar_disparo_mortero(coord)
		_:
			es_impacto = _ejecutar_disparo_mortero(coord)
	
	tipo_disparo_actual = "Mortero" # Resetear siempre al Mortero después de usar
	actualizar_textos_botones_disparo() # Actualiza el texto para quitar el "🎯"
	actualizar_interfaz_monedas()
	
	ejecutar_disparo_jugador(coord, es_impacto)


func turno_ia():
	if fase_actual != Fase.BATALLA: # GUARDA DE ESTADO
		return
	
	var matriz_jugador = tablero_propio.get_node("GridContainer2").estado_tablero
	var x: int
	var y: int
	
	# --- LÓGICA DE SELECCIÓN DE OBJETIVO DE LA IA ---
	if ia_fase == IAfase.CAZA and not posibles_objetivos.is_empty():
		var objetivo_caza = posibles_objetivos.pop_front()
		x = int(objetivo_caza.x)
		y = int(objetivo_caza.y)
		print("IA: Modo CAZA. Disparo a (", x, ", ", y, ")")
		
		if matriz_jugador[x][y] == 2 or matriz_jugador[x][y] == -2:
			# Si el objetivo de caza ya fue disparado, intentar de nuevo inmediatamente.
			get_tree().create_timer(0.05).timeout.connect(turno_ia)
			return
			
	else:
		ia_fase = IAfase.BUSQUEDA
		posibles_objetivos.clear()
		var disparo_valido = false
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		
		while not disparo_valido:
			x = rng.randi_range(0, 9)
			y = rng.randi_range(0, 9)
			
			if matriz_jugador[x][y] != 2 and matriz_jugador[x][y] != -2:
				disparo_valido = true
		
		print("IA: Modo BÚSQUEDA. Disparo aleatorio a (", x, ", ", y, ")")

	# --- EJECUCIÓN DEL DISPARO ---
	var es_impacto = _ejecutar_impacto_en_celda(x, y, tablero_propio)
	var coord_disparada = Vector2(x, y)
	
	# --- LÓGICA POST-DISPARO ---
	if es_impacto:
		impactos_pendientes.append(coord_disparada)
		ia_fase = IAfase.CAZA
		
		var adyacentes = [Vector2(x+1, y), Vector2(x-1, y), Vector2(x, y+1), Vector2(x, y-1)]
		for adj_coord in adyacentes:
			var adj_x = int(adj_coord.x)
			var adj_y = int(adj_coord.y)
			
			if adj_x >= 0 and adj_x <= 9 and adj_y >= 0 and adj_y <= 9:
				var estado_celda = matriz_jugador[adj_x][adj_y]
				if estado_celda != 2 and estado_celda != -2:
					if not posibles_objetivos.has(adj_coord):
						posibles_objetivos.append(adj_coord)
		
		# Si este impacto hundió un barco, limpiamos el estado de caza y volvemos a búsqueda
		if _es_barco_hundido(tablero_propio, coord_disparada):
			ia_fase = IAfase.BUSQUEDA
			impactos_pendientes.clear()
			posibles_objetivos.clear()
			print("IA: ¡Barco hundido! Volviendo a BÚSQUEDA.")
			
		print("IA: ¡Impacto! Estado actual: ", ia_fase, ". Impactos pendientes: ", impactos_pendientes.size(), ". Posibles objetivos: ", posibles_objetivos.size())
		
	else: # La IA falló
		print("IA: Fallo.")
		
		if ia_fase == IAfase.CAZA and posibles_objetivos.is_empty() and impactos_pendientes.is_empty():
			ia_fase = IAfase.BUSQUEDA
			print("IA: Modo CAZA sin objetivos, volviendo a BÚSQUEDA.")
	
	# CORRECCIÓN DE FLUJO: Solo continúa el turno si hubo impacto Y la fase sigue en BATALLA
	if es_impacto and fase_actual == Fase.BATALLA:
		get_tree().create_timer(0.5).timeout.connect(turno_ia)
	elif fase_actual == Fase.BATALLA:
		print("Turno de la IA finalizado. Turno del Jugador.")


# --- FUNCIÓN AUXILIAR PARA LA IA: Comprobar si un barco se hundió con el último impacto ---
func _es_barco_hundido(tablero: Node2D, coord_impacto: Vector2) -> bool:
	var x = int(coord_impacto.x)
	var y = int(coord_impacto.y)
	
	for child in tablero.get_children():
		# Buscamos nodos que sean barcos (asumiendo que los barcos tienen esta meta)
		if child is Node2D and child.has_meta("longitud_casillas"):
			var barco = child
			# Aseguramos que la conversión a int sea correcta
			var longitud = barco.get_meta("longitud_casillas") as int
			var es_horizontal_barco = (barco.rotation_degrees == 0)
			
			var barco_pos_local_grid = barco.position / CELL_SIZE
			var start_x = int(round(barco_pos_local_grid.x))
			var start_y = int(round(barco_pos_local_grid.y))

			# Ajuste de coordenadas iniciales para barcos verticales del jugador/IA
			if not es_horizontal_barco:
				# Si es vertical, la posición 'y' visual está un CELL_SIZE más arriba. 
				# Ajustamos la posición inicial de la matriz para que coincida con la celda más baja (correcta).
				if start_y < 10:
					start_y += 1
			
			var barco_hit = false
			# 1. Verificar si la coordenada impactada está dentro del área lógica de este barco
			if es_horizontal_barco:
				if y == start_y and x >= start_x and x < start_x + longitud:
					barco_hit = true
			else: # Vertical
				if x == start_x and y >= start_y and y < start_y + longitud:
					barco_hit = true
			
			if barco_hit:
				# 2. Si la celda pertenece a este barco, contar cuántos segmentos han sido impactados
				var impactos_en_este_barco = 0
				var matriz = tablero.get_node("GridContainer2").estado_tablero
				
				for i in range(longitud):
					var current_x = start_x + (i if es_horizontal_barco else 0)
					var current_y = start_y + (0 if es_horizontal_barco else i)
					
					# Verificar que las coordenadas estén dentro de los límites
					if current_x >= 0 and current_x < 10 and current_y >= 0 and current_y < 10:
						if matriz[current_x][current_y] == 2: # 2 = Impactado
							impactos_en_este_barco += 1
					
				# 3. Determinar si está hundido
				return impactos_en_este_barco == longitud
				
	return false


# =========================================================
# Lógica de Hundimiento y Fin de Juego
# =========================================================

func _registrar_impacto_en_barco(tablero: Node2D, coord: Vector2, _es_enemigo: bool) -> bool:
	# Esta función solo sirve como puente a _es_barco_hundido.
	return _es_barco_hundido(tablero, coord)

func check_win_condition():
	if barcos_ia_hundidos == TOTAL_BARCOS:
		print("====================================")
		print("         🎉 ¡FELICIDADES, HAS GANADO! 🎉")
		print("====================================")
		# Se muestra el texto de victoria en pantalla
		resultado_label.text = "¡FELICIDADES, HAS GANADO! 🏆"
		resultado_label.visible = true
		fase_actual = Fase.FIN_JUEGO # CLAVE: Detiene la recursión de turnos
		get_tree().paused = true # <--- CLAVE: Pausa todo el juego
	elif barcos_jugador_hundidos == TOTAL_BARCOS:
		print("====================================")
		print("           ☠️ HAS PERDIDO ☠️")
		print("====================================")
		# Se muestra el texto de derrota en pantalla
		resultado_label.text = "☠️ HAS PERDIDO ☠️"
		resultado_label.visible = true
		fase_actual = Fase.FIN_JUEGO # CLAVE: Detiene la recursión de turnos
		get_tree().paused = true # <--- CLAVE: Pausa todo el juego
