class_name WeaponData
extends Resource

enum Category { PISTOL, SMG, RIFLE, SHOTGUN, SNIPER, MG }

@export var category: Category = Category.PISTOL
@export var display_name: String = "Pistol"
@export var damage: float = 20.0
@export var fire_rate: float = 6.0          # shots per second
@export var magazine_size: int = 12
@export var reserve_ammo: int = 60
@export var reload_time: float = 1.6
@export var spread_rad: float = 0.01        # cone half-angle, hip
@export var ads_spread_rad: float = 0.002
@export var recoil_kick: float = 0.06       # camera pitch kick per shot
@export var recoil_yaw: float = 0.01
@export var range_m: float = 80.0
@export var pellets: int = 1                # shotgun > 1
@export var headshot_mult: float = 2.0
@export var auto: bool = true               # hold-to-fire vs semi
@export var body_color: Color = Color(0.2, 0.2, 0.22)
@export var body_scale: Vector3 = Vector3(0.06, 0.08, 0.45)
@export var barrel_scale: Vector3 = Vector3(0.025, 0.025, 0.3)
@export var mag_scale: Vector3 = Vector3(0.04, 0.12, 0.06)
@export var shot_sound: String = ""         # res:// path to wav
@export var ads_zoom: float = 1.0           # camera FOV multiplier when aiming (lower = zoom)