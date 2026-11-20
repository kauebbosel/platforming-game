# entities/enemies/states/boss_chase.gd
extends EnemyState
## Cérebro do chefe (Curupira). Entra no lugar do Chase comum: mantém uma distância
## confortável do Valtair (aproxima se está longe, recua se está perto) e, quando o
## cooldown acaba, sorteia o próximo ataque pela distância. Nunca repete o mesmo ataque
## duas vezes seguidas. Os nós de estado "Charge", "Slam" e "Seeds" fazem cada golpe.

const RETREAT_FACTOR: float = 0.8

var _last_attack: StringName = &""


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)

	if not enemy.is_target_alive():
		state_machine.transition_to("idle")
		return

	var offset: Vector2 = enemy.get_target().global_position - enemy.global_position
	var dist: float = absf(offset.x)
	if dist > 2.0:
		enemy.set_facing(1 if offset.x > 0.0 else -1)

	if enemy.attack_cooldown_left <= 0.0:
		var choice: StringName = _pick_attack(dist)
		if choice != &"":
			_last_attack = choice
			state_machine.transition_to(choice)
			return

	var data: EnemyData = enemy.data
	if dist > data.keep_distance_max:
		enemy.velocity.x = enemy.facing * data.move_speed
	elif dist < data.keep_distance_min and not enemy.is_on_wall():
		enemy.velocity.x = -enemy.facing * data.move_speed * RETREAT_FACTOR
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, data.friction * delta)
	enemy.move_and_slide()


## Sorteio com pesos: a investida precisa de espaço, o salto serve de perto e de médio
## alcance, as sementes valem mais de longe.
func _pick_attack(dist: float) -> StringName:
	var weights: Dictionary = {
		&"charge": 3.0 if dist >= 90.0 else 1.0,
		&"slam": 2.0 if dist <= 220.0 else 0.5,
		&"seeds": 2.5 if dist >= 100.0 else 1.0,
	}
	weights.erase(_last_attack)
	var total: float = 0.0
	for w in weights.values():
		total += w
	var roll: float = randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return weights.keys()[0]
