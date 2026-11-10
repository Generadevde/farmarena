extends RefCounted
class_name SafraTempo
## relógio dos períodos de 3 dias (Safra, colheita do clã)
const PERIOD_DAYS = 3


static func current_period() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0 / PERIOD_DAYS)
