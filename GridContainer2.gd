extends GridContainer # O Node2D, si usas un arreglo de TextureButtons sin GridContainer

# === EXPORTACIONES ===
const CELL_SCENE = preload("res://mar.tscn") # Asumiendo que tu celda usa la escena Celda.tscn
@export var mostrar_barcos: bool = false # Si es true, muestra los barcos (Tablero Propio)
@export var mostrar_sonar: bool = false # Usado para el modo Sonar
# =====================

# === VARIABLES DE ESTADO ===
# Estado de la matriz:
# -1: Agua/No disparado (Valor inicial)
# 0: Barco sin impactar (Solo en tablero propio)
# 1: Barco IA sin impactar (Solo en matriz IA)
# -2: Agua/Fallo (Disparado)
# 2: Impacto/Acierto (Disparado)
var estado_tablero: Array = []
var celda_nodes: Array = [] # Arreglo 2D para acceder a los nodos de celda

# === SEÑALES ===
signal celda_cliqueada(coord) # Señal que emite la celda y se conecta a Game.gd

# === RECURSOS (Asegúrate de que estas rutas sean correctas) ===
const TEXTURA_AGUA = preload("res://Assets/agua.png")
const TEXTURA_FALLO = preload("res://Assets/fallo.png")
const TEXTURA_IMPACTO = preload("res://Assets/impacto.png")
const TEXTURA_BARCO_VISUAL = preload("res://Assets/barco_segmento.png") # Para el sonar

# =========================================================

func _ready():
	# Inicializa la matriz de estado
	for i in range(10):
		estado_tablero.append([])
		celda_nodes.append([])
		for j in range(10):
			estado_tablero[i].append(-1)
			celda_nodes[i].append(null) # Inicializa la referencia al nodo
	
	_inicializar_cuadricula()

func _inicializar_cuadricula():
	for x in range(10):
		for y in range(10):
			var celda_instancia = CELL_SCENE.instantiate()
			# Asignar la coordenada ANTES de emitir la señal
			celda_instancia.coordenada = Vector2(x, y) 
			
			# Conectar la señal local de la celda a la señal principal del GridContainer
			if celda_instancia.has_signal("celda_seleccionada"):
				celda_instancia.celda_seleccionada.connect(_on_celda_seleccionada)
			
			add_child(celda_instancia)
			celda_nodes[x][y] = celda_instancia # Guardar referencia
			
			# Configuración visual inicial (Todas inician como agua)
			celda_instancia.texture_normal = TEXTURA_AGUA
			celda_instancia.texture_pressed = TEXTURA_AGUA

# Captura la señal de la celda y la retransmite al Game.gd
func _on_celda_seleccionada(coord: Vector2):
	emit_signal("celda_cliqueada", coord)


## =========================================================
## FUNCIÓN CLAVE PARA LA VISUALIZACIÓN DE DISPAROS
## =========================================================
func actualizar_celda_visual(x: int, y: int, estado: int):
	if x < 0 or x > 9 or y < 0 or y > 9:
		return
		
	var celda: TextureButton = celda_nodes[x][y]
	if not celda:
		return
		
	# 1. VISUALIZACIÓN DE FALLOS E IMPACTOS (Permanente)
	match estado:
		# FALLO
		-2: 
			celda.texture_normal = TEXTURA_FALLO
			celda.texture_pressed = TEXTURA_FALLO
			celda.texture_hover = TEXTURA_FALLO
		# ACIERTO
		2: 
			celda.texture_normal = TEXTURA_IMPACTO
			celda.texture_pressed = TEXTURA_IMPACTO
			celda.texture_hover = TEXTURA_IMPACTO
			
		# 2. VISUALIZACIÓN DE BARCOS (Temporal o Permanente)
		# Nota: Las celdas con estado 0 (barco propio) o 1 (barco IA) solo deben 
		# mostrar el barco si mostrar_barcos es true (propio) O si el estado es 
		# revelado por el Sonar (estado 1 en tablero enemigo, que es temporal).
		
		# BARCO VISIBLE POR SONAR O COLOCACIÓN (No impactado)
		1: 
			if mostrar_barcos: # Tablero Propio
				celda.texture_normal = TEXTURA_BARCO_VISUAL
			elif mostrar_sonar: # Tablero Objetivo (Temporal por Sonar)
				celda.texture_normal = TEXTURA_BARCO_VISUAL
				# NOTA: Para que la visualización por Sonar sea temporal, 
				# necesitas un Timer en Game.gd que, después de unos segundos, 
				# llame de nuevo a esta función para resetear el estado 1 a -1.
				# Si no implementas el Timer, el barco se quedará visible.

		# AGUA/NO DISPARADO
		-1, 0:
			if mostrar_barcos and estado == 0:
				celda.texture_normal = TEXTURA_BARCO_VISUAL
			else:
				celda.texture_normal = TEXTURA_AGUA
