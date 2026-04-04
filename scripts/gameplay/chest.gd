extends Area2D

enum RewardType {
	ARROWS,
	HEALTH,
	EXPLOSIVE,
	RICOCHET,
	STRAIGHT,
	TRIPLE_SHOT,
	RAPID_FIRE,
	EXTRA_DASH,
	ARMOR,
	SPEED,
}

const REWARD_WEIGHTS := {
	RewardType.ARROWS: 5,
	RewardType.HEALTH: 2,
	RewardType.EXPLOSIVE: 2,
	RewardType.RICOCHET: 2,
	RewardType.STRAIGHT: 2,
	RewardType.TRIPLE_SHOT: 2,
	RewardType.RAPID_FIRE: 2,
	RewardType.EXTRA_DASH: 2,
	RewardType.ARMOR: 2,
	RewardType.SPEED: 2,
}

@export var timer_length: float = 5.0
@export var explosive_charges: int = 2
@export var ricochet_charges: int = 3
@export var straight_charges: int = 4
@export var triple_shot_charges: int = 3
@export var rapid_fire_duration: float = 5.0
@export var extra_dash_duration: float = 8.0
@export var armor_hits: int = 1
@export var speed_boost_duration: float = 6.0
@export_enum("Random:-1", "Arrows:0", "Health:1", "Bomb:2", "Bounce:3", "Triple Shot:4", "Rapid Fire:5", "Extra Dash:6", "Armor:7", "Speed:8") var reward_override: int = -1

@onready var timer: Timer = $Regeneration
@onready var particles: GPUParticles2D = $Recharged
@onready var progress: ProgressBar = $ProgressBar
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var loot_label: Label = $LootLabel

var lootable: bool = true
var current_reward: int = RewardType.ARROWS
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var has_initialized: bool = false

func _ready() -> void:
	rng.randomize()
	set_lootable(true)
	timer.wait_time = timer_length
	has_initialized = true

func _physics_process(_delta: float) -> void:
	progress.value = (timer_length - timer.time_left) / timer_length * 100.0

func _roll_reward() -> int:
	if reward_override >= 0:
		return reward_override

	var total_weight: int = 0
	for weight in REWARD_WEIGHTS.values():
		total_weight += weight

	var choice := rng.randi_range(1, total_weight)
	for reward in REWARD_WEIGHTS.keys():
		choice -= REWARD_WEIGHTS[reward]
		if choice <= 0:
			return reward

	return RewardType.ARROWS

func _get_reward_name() -> String:
	match current_reward:
		RewardType.HEALTH:
			return "HEAL"
		RewardType.EXPLOSIVE:
			return "BOMB x%d" % explosive_charges
		RewardType.RICOCHET:
			return "BOUNCE x%d" % ricochet_charges
		RewardType.STRAIGHT:
			return "STRAIGHT x%d" % straight_charges
		RewardType.TRIPLE_SHOT:
			return "TRIPLE x%d" % triple_shot_charges
		RewardType.RAPID_FIRE:
			return "RAPID"
		RewardType.EXTRA_DASH:
			return "DASH+"
		RewardType.ARMOR:
			return "ARMOR"
		RewardType.SPEED:
			return "SPEED"
		_:
			return "ARROWS"

func _get_reward_color() -> Color:
	match current_reward:
		RewardType.HEALTH:
			return Color("#ff5666")
		RewardType.EXPLOSIVE:
			return Arrow.get_arrow_color(Arrow.ArrowType.EXPLOSIVE)
		RewardType.RICOCHET:
			return Arrow.get_arrow_color(Arrow.ArrowType.RICOCHET)
		RewardType.STRAIGHT:
			return Arrow.get_arrow_color(Arrow.ArrowType.STRAIGHT)
		RewardType.TRIPLE_SHOT:
			return Color("#fff078")
		RewardType.RAPID_FIRE:
			return Color("#ff7ae0")
		RewardType.EXTRA_DASH:
			return Color("#74d0ff")
		RewardType.ARMOR:
			return Color("#8fd9ff")
		RewardType.SPEED:
			return Color("#8ff06d")
		_:
			return Color("#8ff06d")

func _update_loot_visuals() -> void:
	loot_label.text = _get_reward_name()
	loot_label.modulate = _get_reward_color()

func set_lootable(new_val: bool) -> void:
	lootable = new_val
	if new_val:
		current_reward = _roll_reward()
		_update_loot_visuals()
		animated_sprite.frame = 0
		particles.emitting = true
		progress.hide()
		loot_label.show()
		if has_initialized:
			GameSfx.play(self, &"chest_ready", global_position)
	else:
		animated_sprite.frame = 1
		timer.start()
		progress.show()
		loot_label.hide()

func apply_effect(player: Player) -> void:
	match current_reward:
		RewardType.HEALTH:
			player.heal()
		RewardType.EXPLOSIVE:
			player.grant_special_arrows(Arrow.ArrowType.EXPLOSIVE, explosive_charges)
		RewardType.RICOCHET:
			player.grant_special_arrows(Arrow.ArrowType.RICOCHET, ricochet_charges)
		RewardType.STRAIGHT:
			player.grant_special_arrows(Arrow.ArrowType.STRAIGHT, straight_charges)
		RewardType.TRIPLE_SHOT:
			player.grant_triple_shot(triple_shot_charges)
		RewardType.RAPID_FIRE:
			player.grant_rapid_fire(rapid_fire_duration)
		RewardType.EXTRA_DASH:
			player.grant_extra_dash(extra_dash_duration)
		RewardType.ARMOR:
			player.grant_armor(armor_hits)
		RewardType.SPEED:
			player.grant_speed_boost(speed_boost_duration)
		_:
			player.restore_arrows()

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if lootable and player != null:
		apply_effect(player)
		GameSfx.play(self, &"chest_open", global_position, randf_range(0.98, 1.05))
		set_lootable(false)

func _on_regeneration_timeout() -> void:
	set_lootable(true)
