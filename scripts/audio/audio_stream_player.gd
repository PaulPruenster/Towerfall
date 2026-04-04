extends AudioStreamPlayer

@export var music_folder: String = "res://music/"  # Folder containing MP3s
@onready var audio_player: AudioStreamPlayer = $"."  # Reference to your player node

var songs: Array[AudioStreamMP3] = []
var current_index: int = 0

func _ready() -> void:
	load_songs()
	start_random_song()
	audio_player.finished.connect(_on_song_finished)

# Load all MP3 files from the folder
func load_songs() -> void:
	var dir = DirAccess.open(music_folder)
	if dir:
		var files = dir.get_files()
		for file in files:
			if file.to_lower().ends_with(".mp3"):
				var song = load(music_folder + file)
				if song:
					songs.append(song)
		songs.sort_custom(func(a, b): return a.resource_path < b.resource_path)  # Sort alphabetically
		print(songs.size())
	else:
		push_error("Failed to open music folder: " + music_folder)

# Start playing from a random song
func start_random_song() -> void:
	if songs.is_empty():
		push_warning("No songs found!")
		return
		
	randomize()
	current_index = randi() % songs.size()
	play_current_song()

# Play the song at current_index
func play_current_song() -> void:
	audio_player.stream = songs[current_index]
	audio_player.play()

# Called when current song finishes
func _on_song_finished() -> void:
	current_index = (current_index + 1) % songs.size()  # Loop to next song
	play_current_song()
