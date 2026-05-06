extends PanelContainer

signal deploy_requested()

@onready var hero_name_label: Label = %HeroName
@onready var status_label: Label = %StatusLabel
@onready var cost_label: Label = %CostLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var deploy_button: Button = %DeployButton
@onready var cooldown_overlay: ColorRect = %CooldownOverlay
@onready var cooldown_label: Label = %CooldownLabel

var hero_id: String = "Guardian"
var deploy_cost: int = 100
var is_deployed: bool = false
var on_cooldown: bool = false

func _ready() -> void:
	deploy_button.pressed.connect(func(): deploy_requested.emit())
	hp_bar.visible = false
	cooldown_overlay.visible = false
	cooldown_label.visible = false

func setup_ui(config: Dictionary) -> void:
	hero_id = "Guardian"
	deploy_cost = config.get("deploy_cost", 100)
	cost_label.text = "%dG" % deploy_cost
	hero_name_label.text = hero_id
	
	set_ready()

func set_deployed(hero: Node, duration: float) -> void:
	is_deployed = true
	on_cooldown = false
	deploy_button.disabled = true
	hp_bar.visible = true
	
	status_label.text = "ACTIVE: %ds" % int(duration)
	status_label.modulate = Color(1.0, 0.9, 0.2) # Yellow/Gold
	
	_update_hp(hero.current_hp, hero.max_hp)
	if not hero.is_connected("health_changed", _update_hp):
		hero.health_changed.connect(_update_hp)

func update_duration(remaining: float) -> void:
	if is_deployed:
		status_label.text = "ACTIVE: %ds" % int(remaining)
		if remaining < 5.0:
			status_label.modulate = Color(1.0, 0.4, 0.4) # Red alert

func set_cooldown(current: float, max_v: float) -> void:
	is_deployed = false
	on_cooldown = true
	hp_bar.visible = false
	
	cooldown_overlay.visible = true
	cooldown_label.visible = true
	cooldown_label.text = "%ds" % int(current)
	deploy_button.disabled = true
	
	status_label.text = "COOLDOWN"
	status_label.modulate = Color(0.6, 0.6, 0.6)
	
	cooldown_overlay.scale.y = current / max_v

func set_ready() -> void:
	is_deployed = false
	on_cooldown = false
	cooldown_overlay.visible = false
	cooldown_label.visible = false
	deploy_button.disabled = false
	hp_bar.visible = false
	
	status_label.text = "READY"
	status_label.modulate = Color(0.4, 1.0, 0.6) # Vibrant Green
	
	# Highlight button
	deploy_button.modulate = Color(1, 1, 1)

func _update_hp(current: float, max_v: float) -> void:
	hp_bar.max_value = max_v
	hp_bar.value = current

func set_insufficient_gold(insufficient: bool) -> void:
	if not is_deployed and not on_cooldown:
		if insufficient:
			status_label.text = "LOW GOLD"
			status_label.modulate = Color(1.0, 0.3, 0.3)
			deploy_button.disabled = true
		else:
			status_label.text = "READY"
			status_label.modulate = Color(0.4, 1.0, 0.6)
			deploy_button.disabled = false
