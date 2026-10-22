class_name DtTraffic
extends Traffic
## Downtown's traffic: the world kit's Traffic, plus yielding between cars on different lanes. The ring and the corner
## loops share the junction boxes, so a turning car can cross another lane's path; here a car also slows for any MOVING
## car of another lane that is in its path ahead (the same in-path test Traffic uses for the skater and walkers). A
## stopped car never blocks anyone, so two cars can never wait for each other.

const YIELD_MIN_SPEED: float = 0.6


## Called once per car per tick by Traffic._physics_process; the crossing-car limit rides along with the signals.
func _signal_limit(car: TrafficCar) -> float:
	var lim: float = super._signal_limit(car)
	for other: TrafficCar in cars:
		if other == car or other.lane == car.lane or other.speed < YIELD_MIN_SPEED:
			continue
		if (other.global_position - car.global_position).length_squared() > 900.0:
			continue
		lim = minf(lim, _obstacle_limit(car, other.global_position))
	return lim
