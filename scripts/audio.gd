extends Node
## Tamamen prosedürel ses üretimi (osilatör + üstel sönümlü zarf) — Web Audio API'deki
## oscillator+gain mantığının AudioStreamGenerator karşılığı. Dış ses dosyası kullanılmaz,
## bu yüzden telif riski sıfır (bkz. aktarım dokümanı bölüm 2 ve 8).

const MIX_RATE := 44100.0
const TAU := PI * 2.0

var sound_on: bool = true

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _tones: Array = [] # Array of Dictionary {freq, dur, type, vol, t}


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = "Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func play_tone(freq: float, dur: float, type: String = "sine", vol: float = 0.06) -> void:
	if not sound_on:
		return
	_tones.append({"freq": freq, "dur": dur, "type": type, "vol": vol, "t": 0.0})


func play_chime() -> void:
	play_tone(660, 0.12, "triangle", 0.05)
	get_tree().create_timer(0.07).timeout.connect(func(): play_tone(880, 0.12, "triangle", 0.05))
	get_tree().create_timer(0.14).timeout.connect(func(): play_tone(1100, 0.16, "triangle", 0.055))


func play_win_sound() -> void:
	var freqs := [523.0, 659.0, 784.0, 1047.0]
	for i in range(freqs.size()):
		get_tree().create_timer(i * 0.09).timeout.connect(func(): play_tone(freqs[i], 0.18, "triangle", 0.05))


func play_lose_sound() -> void:
	var freqs := [392.0, 330.0, 262.0]
	for i in range(freqs.size()):
		get_tree().create_timer(i * 0.11).timeout.connect(func(): play_tone(freqs[i], 0.22, "sine", 0.05))


func _wave(phase: float, type: String) -> float:
	match type:
		"triangle":
			return (2.0 / PI) * asin(sin(phase))
		"sawtooth":
			var x: float = phase / TAU
			return 2.0 * (x - floor(x + 0.5))
		_:
			return sin(phase)


func _process(_delta: float) -> void:
	if _playback == null or _tones.is_empty():
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var step: float = 1.0 / MIX_RATE
	for _i in range(frames):
		var sample: float = 0.0
		var alive: Array = []
		for tone in _tones:
			var t: float = tone.t
			if t >= tone.dur:
				continue
			var env: float = tone.vol * exp(-5.0 * t / tone.dur)
			var phase: float = TAU * tone.freq * t
			sample += env * _wave(phase, tone.type)
			tone.t = t + step
			alive.append(tone)
		_tones = alive
		sample = clampf(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
