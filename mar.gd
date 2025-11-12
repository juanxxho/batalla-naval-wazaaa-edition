# mar.gd
extends Sprite2D

# Nueva señal para que el Game.gd la capte
signal ataque_realizado(coord) 

# ... (resto de variables y _ready) ...

# Esta función se llama cuando se hace clic en CUALQUIERA de las 100 celdas
func _on_celda_seleccionada(coord: Vector2):
	# En lugar de solo imprimir, emitimos la señal al Game.gd (el padre)
	emit_signal("ataque_realizado", coord) 
	print("Celda cliqueada, señal emitida: ", coord)
