class_name World
extends RefCounted
## Constantes da vila e altura do chão. A geometria fica em scenes/vila.tscn
## (editável no editor); tools/vila_builder.gd é o gerador usado para criá-la.

const STREET_LEN := 260.0
const STREET_W := 7.0
const SLOPE := deg_to_rad(7.0)
const WALL_X := 16.0


## Altura do chão na ladeira em função de z (sobe para z negativo).
static func ground_y(z: float) -> float:
	return -z * tan(SLOPE)
