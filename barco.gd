# Barco.gd
extends Node2D

# Longitud total del barco (establecida en Game.gd)
var longitud_casillas: int = 0 
# Contador de impactos
var impactos_recibidos: int = 0


# Señal que Game.gd escuchará para saber que un barco ha sido hundido
signal hundido(longitud: int)

func registrar_impacto():
	impactos_recibidos += 1
	print("Barco impactado. Faltan ", longitud_casillas - impactos_recibidos, " hits.")
	
	if impactos_recibidos >= longitud_casillas:
		# ¡Hundido!
		emit_signal("hundido", longitud_casillas)
		print("¡BARCO HUNDIDO!")
		
		# Si el barco es de la IA (estaba oculto), lo hacemos visible al hundirse
		# (Para que se vea que estaba allí y fue destruido)
		if not visible:
			visible = true
			
		return true # Indica que el barco se hundió
	return false # Indica que el barco fue impactado, pero no hundido
