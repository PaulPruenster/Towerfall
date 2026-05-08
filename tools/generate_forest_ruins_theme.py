#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT / "music" / "forest-ruins-adventure-theme.mp3"
SAMPLE_RATE = 48_000
BPM = 150
BEAT_SECONDS = 60.0 / BPM
BAR_SECONDS = BEAT_SECONDS * 4.0
EIGHTH_SECONDS = BEAT_SECONDS * 0.5
TAIL_SECONDS = 2.4
RNG = np.random.default_rng(20260424)

NOTE_OFFSETS = {
	"C": 0,
	"C#": 1,
	"Db": 1,
	"D": 2,
	"D#": 3,
	"Eb": 3,
	"E": 4,
	"F": 5,
	"F#": 6,
	"Gb": 6,
	"G": 7,
	"G#": 8,
	"Ab": 8,
	"A": 9,
	"A#": 10,
	"Bb": 10,
	"B": 11,
}

CHORDS = {
	"Am": {
		"arp": ["A4", "C5", "E5", "A5"],
		"pad": ["A3", "C4", "E4"],
		"root": "A2",
		"bass": "A2",
	},
	"F": {
		"arp": ["F4", "A4", "C5", "F5"],
		"pad": ["F3", "A3", "C4"],
		"root": "F2",
		"bass": "F2",
	},
	"C": {
		"arp": ["C4", "E4", "G4", "C5"],
		"pad": ["C3", "E3", "G3"],
		"root": "C2",
		"bass": "C2",
	},
	"G": {
		"arp": ["G4", "B4", "D5", "G5"],
		"pad": ["G3", "B3", "D4"],
		"root": "G2",
		"bass": "G2",
	},
	"Dm": {
		"arp": ["D4", "F4", "A4", "D5"],
		"pad": ["D3", "F3", "A3"],
		"root": "D2",
		"bass": "D2",
	},
	"E7": {
		"arp": ["E4", "G#4", "B4", "D5"],
		"pad": ["E3", "G#3", "B3", "D4"],
		"root": "E2",
		"bass": "E2",
	},
	"Em": {
		"arp": ["E4", "G4", "B4", "E5"],
		"pad": ["E3", "G3", "B3"],
		"root": "E2",
		"bass": "E2",
	},
	"G/B": {
		"arp": ["G4", "B4", "D5", "G5"],
		"pad": ["G3", "B3", "D4"],
		"root": "G2",
		"bass": "B2",
	},
	"C/E": {
		"arp": ["C4", "E4", "G4", "C5"],
		"pad": ["C3", "E3", "G3"],
		"root": "C2",
		"bass": "E2",
	},
}

PROGRESSION = [
	"Am", "F", "C", "G",
	"Am", "F", "C", "G",
	"Dm", "Am", "G", "E7",
	"Am", "F", "C", "G",
	"F", "Em", "Dm", "E7",
	"C", "G/B", "Am", "Em",
	"F", "C/E", "Dm", "G",
	"Dm", "G", "C", "Am",
	"F", "G", "Em", "E7",
	"Am", "F", "C", "G",
	"Dm", "G", "C", "E7",
	"Am", "F", "C", "E7",
]

INTENSITY_BARS = (
	[0, 0, 1, 1]
	+ [2, 2, 2, 3]
	+ [2, 2, 2, 3]
	+ [3, 3, 3, 3]
	+ [3, 3, 3, 3]
	+ [3, 3, 3, 3]
	+ [2, 2, 2, 2]
	+ [2, 2, 2, 3]
	+ [4, 4, 4, 4]
	+ [4, 4, 4, 4]
	+ [3, 3, 3, 2]
	+ [2, 2, 1, 0]
)

MELODY_BARS = [
	# Intro
	"r r E5 - G5 A5 C6 -",
	"A5 - G5 F5 E5 - C5 -",
	"E5 G5 C6 - G5 - E5 -",
	"D5 G5 B5 - A5 G5 D5 -",
	# Section A
	"F5 A5 D6 - C6 A5 F5 -",
	"E6 - C6 A5 G5 - A5 -",
	"B5 - G5 D5 G5 - A5 -",
	"G#5 B5 D6 - E6 - r r",
	# Section A variation
	"E5 G5 A5 - C6 B5 A5 G5",
	"A5 C6 A5 G5 F5 - E5 C5",
	"G5 - E5 G5 C6 - B5 G5",
	"D5 - G5 B5 D6 - B5 A5",
	# Lift
	"A5 C6 A5 F5 A5 - C6 A5",
	"G5 B5 G5 E5 G5 - B5 G5",
	"F5 A5 D6 A5 F5 E5 D5 -",
	"G#5 B5 D6 E6 D6 B5 G#5 -",
	# Bright section
	"G5 - E5 G5 C6 - G5 E5",
	"D5 G5 B5 A5 G5 - D5 -",
	"E5 G5 A5 C6 B5 A5 G5 E5",
	"G5 B5 G6 - D6 B5 G5 -",
	# Bright variation
	"A5 C6 A5 F5 A5 C6 A5 F5",
	"G5 C6 G5 E5 G5 C6 B5 G5",
	"F5 A5 D6 - A5 F5 E5 D5",
	"D5 G5 B5 - A5 G5 D5 -",
	# Bridge
	"F5 A5 D6 C6 A5 F5 E5 D5",
	"D5 G5 B5 A5 G5 D5 B4 D5",
	"E5 G5 C6 E6 D6 C6 G5 E5",
	"E5 A5 C6 B5 A5 E5 C5 A4",
	# Bridge variation
	"C6 A5 F5 A5 C6 A5 G5 F5",
	"D5 G5 B5 D6 B5 G5 D5 B4",
	"G5 B5 G5 E5 G5 B5 D6 B5",
	"G#5 B5 D6 E6 D6 B5 G#5 -",
	# Climax
	"E6 - C6 A5 E6 - C6 A5",
	"A5 C6 A5 F5 A5 C6 G5 E5",
	"G5 C6 E6 G6 E6 C6 G5 E5",
	"D6 B5 G5 D6 B5 G5 D5 -",
	# Climax variation
	"F5 A5 D6 F6 D6 A5 F5 D5",
	"D5 G5 B5 D6 B5 G5 D5 B4",
	"E5 G5 C6 E6 D6 C6 G5 E5",
	"G#5 B5 D6 E6 D6 B5 A5 G#5",
	# Reprise
	"E5 G5 A5 C6 A5 G5 E5 D5",
	"C5 F5 A5 G5 F5 E5 C5 A4",
	"E5 G5 C6 E6 D6 C6 G5 E5",
	"G#5 B5 D6 E6 D6 B5 G#5 -",
	# Outro
	"F5 A5 D6 C6 A5 F5 D5 -",
	"D5 G5 B5 A5 G5 D5 B4 G4",
	"E5 G5 C6 E6 D6 C6 G5 E5",
	"G#5 B5 D6 E6 - - r r",
]


def note_to_midi(note: str) -> int:
	if len(note) < 2:
		raise ValueError(f"Invalid note: {note}")
	if note[1] in {"#", "b"}:
		name = note[:2]
		octave = int(note[2:])
	else:
		name = note[0]
		octave = int(note[1:])
	return (octave + 1) * 12 + NOTE_OFFSETS[name]


def midi_to_hz(midi_note: int) -> float:
	return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))


def seconds_to_samples(seconds: float) -> int:
	return max(1, int(round(seconds * SAMPLE_RATE)))


def pan_gains(pan: float) -> tuple[float, float]:
	angle = (pan + 1.0) * (math.pi / 4.0)
	return math.cos(angle), math.sin(angle)


def make_env(
	note_samples: int,
	release_samples: int,
	attack_seconds: float,
	decay_seconds: float,
	sustain_level: float,
) -> np.ndarray:
	attack_samples = min(note_samples, seconds_to_samples(attack_seconds))
	remaining = max(0, note_samples - attack_samples)
	decay_samples = min(remaining, seconds_to_samples(decay_seconds))
	sustain_samples = max(0, note_samples - attack_samples - decay_samples)
	parts = []
	if attack_samples:
		parts.append(np.linspace(0.0, 1.0, attack_samples, endpoint=False))
	if decay_samples:
		parts.append(np.linspace(1.0, sustain_level, decay_samples, endpoint=False))
	if sustain_samples:
		parts.append(np.full(sustain_samples, sustain_level))
	if release_samples:
		release_start = sustain_level if note_samples > attack_samples else 1.0
		parts.append(np.linspace(release_start, 0.0, release_samples, endpoint=False))
	env = np.concatenate(parts) if parts else np.zeros(note_samples + release_samples)
	total = note_samples + release_samples
	if env.size < total:
		env = np.pad(env, (0, total - env.size))
	return env[:total]


def oscillator(
	kind: str,
	frequency: float,
	length: int,
	duty: float = 0.5,
	vibrato_rate: float = 0.0,
	vibrato_depth: float = 0.0,
) -> np.ndarray:
	t = np.arange(length, dtype=np.float64) / SAMPLE_RATE
	if vibrato_depth:
		inst_freq = frequency * (1.0 + vibrato_depth * np.sin(2.0 * math.pi * vibrato_rate * t))
	else:
		inst_freq = np.full(length, frequency, dtype=np.float64)
	phase = np.cumsum(inst_freq) / SAMPLE_RATE
	cycle = np.mod(phase, 1.0)
	if kind == "pulse":
		return np.where(cycle < duty, 1.0, -1.0)
	if kind == "triangle":
		return 2.0 * np.abs(2.0 * cycle - 1.0) - 1.0
	if kind == "saw":
		return 2.0 * cycle - 1.0
	if kind == "sine":
		return np.sin(2.0 * math.pi * phase)
	raise ValueError(f"Unknown oscillator kind: {kind}")


def lead_tone(frequency: float, length: int) -> np.ndarray:
	main = oscillator("pulse", frequency, length, duty=0.22, vibrato_rate=5.4, vibrato_depth=0.0035)
	detuned = oscillator("pulse", frequency * 1.003, length, duty=0.12, vibrato_rate=5.8, vibrato_depth=0.0025)
	sub = oscillator("triangle", frequency * 0.5, length)
	return 0.58 * main + 0.24 * detuned + 0.18 * sub


def arp_tone(frequency: float, length: int) -> np.ndarray:
	main = oscillator("pulse", frequency, length, duty=0.11)
	top = oscillator("pulse", frequency * 2.0, length, duty=0.05)
	return 0.74 * main + 0.26 * top


def pad_tone(frequency: float, length: int) -> np.ndarray:
	triangle = oscillator("triangle", frequency, length)
	sine = oscillator("sine", frequency * 0.5, length)
	return 0.7 * triangle + 0.3 * sine


def bass_tone(frequency: float, length: int) -> np.ndarray:
	triangle = oscillator("triangle", frequency, length)
	pulse = oscillator("pulse", frequency * 0.5, length, duty=0.40)
	return 0.72 * triangle + 0.28 * pulse


def add_signal(mix: np.ndarray, start_seconds: float, signal: np.ndarray, pan: float, volume: float) -> None:
	start = seconds_to_samples(start_seconds)
	if start >= mix.shape[0]:
		return
	end = min(mix.shape[0], start + signal.size)
	if end <= start:
		return
	left_gain, right_gain = pan_gains(pan)
	segment = signal[: end - start] * volume
	mix[start:end, 0] += segment * left_gain
	mix[start:end, 1] += segment * right_gain


def add_note(
	mix: np.ndarray,
	start_seconds: float,
	duration_seconds: float,
	note: str,
	synth,
	volume: float,
	pan: float,
	attack_seconds: float,
	decay_seconds: float,
	sustain_level: float,
	release_seconds: float,
) -> None:
	note_samples = seconds_to_samples(duration_seconds)
	release_samples = seconds_to_samples(release_seconds)
	total = note_samples + release_samples
	env = make_env(note_samples, release_samples, attack_seconds, decay_seconds, sustain_level)
	frequency = midi_to_hz(note_to_midi(note))
	signal = synth(frequency, total) * env
	add_signal(mix, start_seconds, signal, pan, volume)


def add_noise_hit(
	mix: np.ndarray,
	start_seconds: float,
	duration_seconds: float,
	volume: float,
	pan: float,
	color_window: int,
	decay_rate: float,
) -> None:
	length = seconds_to_samples(duration_seconds)
	noise = RNG.standard_normal(length)
	smoothed = np.convolve(noise, np.ones(color_window) / color_window, mode="same")
	bright = noise - smoothed
	t = np.arange(length, dtype=np.float64) / SAMPLE_RATE
	env = np.exp(-t * decay_rate)
	add_signal(mix, start_seconds, bright * env, pan, volume)


def add_kick(mix: np.ndarray, start_seconds: float, volume: float) -> None:
	length = seconds_to_samples(0.24)
	t = np.arange(length, dtype=np.float64) / SAMPLE_RATE
	freq = 110.0 * np.exp(-t * 8.2) + 38.0
	phase = 2.0 * math.pi * np.cumsum(freq) / SAMPLE_RATE
	body = np.sin(phase)
	click = np.sin(2.0 * math.pi * 185.0 * t) * np.exp(-t * 48.0)
	env = np.exp(-t * 11.0)
	add_signal(mix, start_seconds, (0.9 * body + 0.28 * click) * env, 0.0, volume)


def add_snare(mix: np.ndarray, start_seconds: float, volume: float) -> None:
	length = seconds_to_samples(0.18)
	t = np.arange(length, dtype=np.float64) / SAMPLE_RATE
	noise = RNG.standard_normal(length)
	bright = noise - np.convolve(noise, np.ones(18) / 18.0, mode="same")
	tone = np.sin(2.0 * math.pi * 176.0 * t) * np.exp(-t * 18.0)
	env = np.exp(-t * 22.0)
	add_signal(mix, start_seconds, (0.78 * bright + 0.22 * tone) * env, 0.0, volume)


def schedule_melody(mix: np.ndarray) -> None:
	for bar_index, pattern in enumerate(MELODY_BARS):
		tokens = pattern.split()
		if len(tokens) != 8:
			raise ValueError(f"Expected 8 eighth-note slots in bar {bar_index + 1}, got {len(tokens)}")
		slot = 0
		while slot < 8:
			token = tokens[slot]
			if token == "r":
				slot += 1
				continue
			if token == "-":
				raise ValueError(f"Unexpected sustain marker at bar {bar_index + 1}, slot {slot + 1}")
			length_slots = 1
			while slot + length_slots < 8 and tokens[slot + length_slots] == "-":
				length_slots += 1
			start = bar_index * BAR_SECONDS + slot * EIGHTH_SECONDS
			duration = length_slots * EIGHTH_SECONDS * 0.96
			intensity = INTENSITY_BARS[bar_index]
			pan = -0.18 if intensity < 4 else -0.10
			volume = 0.12 + intensity * 0.016
			add_note(
				mix,
				start,
				duration,
				token,
				lead_tone,
				volume=volume,
				pan=pan,
				attack_seconds=0.003,
				decay_seconds=0.045,
				sustain_level=0.78,
				release_seconds=0.055,
			)
			if intensity >= 4 and slot in {0, 4}:
				harmony_note = transpose_note(token, -4)
				add_note(
					mix,
					start,
					duration * 0.94,
					harmony_note,
					lead_tone,
					volume=volume * 0.46,
					pan=0.18,
					attack_seconds=0.003,
					decay_seconds=0.04,
					sustain_level=0.72,
					release_seconds=0.045,
				)
			slot += length_slots


def transpose_note(note: str, semitones: int) -> str:
	midi_note = note_to_midi(note) + semitones
	octave = midi_note // 12 - 1
	pc = midi_note % 12
	names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return f"{names[pc]}{octave}"


def schedule_arps_and_pads(mix: np.ndarray) -> None:
	light_pattern = [0, 1, 2, 1, 0, 1, 2, 3]
	dense_pattern = [0, 1, 2, 3, 2, 1, 2, 1, 0, 1, 2, 3, 2, 1, 2, 3]
	for bar_index, chord_name in enumerate(PROGRESSION):
		chord = CHORDS[chord_name]
		intensity = INTENSITY_BARS[bar_index]
		bar_start = bar_index * BAR_SECONDS
		for pad_index, pad_note in enumerate(chord["pad"]):
			pan = (-0.28, -0.08, 0.12, 0.28)[pad_index]
			add_note(
				mix,
				bar_start,
				BAR_SECONDS * (0.92 if intensity <= 1 else 0.98),
				pad_note,
				pad_tone,
				volume=0.028 + intensity * 0.006,
				pan=pan,
				attack_seconds=0.012,
				decay_seconds=0.08,
				sustain_level=0.58,
				release_seconds=0.22,
			)
		pattern = light_pattern if intensity <= 1 else dense_pattern
		step_seconds = BAR_SECONDS / len(pattern)
		arp_volume = 0.0 if intensity == 0 else 0.040 + intensity * 0.010
		if arp_volume == 0.0:
			continue
		for step_index, chord_tone_index in enumerate(pattern):
			start = bar_start + step_index * step_seconds
			pan = 0.22 if step_index % 2 == 0 else 0.30
			add_note(
				mix,
				start,
				step_seconds * (0.62 if intensity <= 1 else 0.46),
				chord["arp"][chord_tone_index],
				arp_tone,
				volume=arp_volume,
				pan=pan,
				attack_seconds=0.0015,
				decay_seconds=0.03,
				sustain_level=0.36,
				release_seconds=0.032,
			)


def schedule_bass(mix: np.ndarray) -> None:
	for bar_index, chord_name in enumerate(PROGRESSION):
		chord = CHORDS[chord_name]
		intensity = INTENSITY_BARS[bar_index]
		bar_start = bar_index * BAR_SECONDS
		root = chord["root"]
		bass = chord["bass"]
		fifth = transpose_note(root, 7)
		octave = transpose_note(root, 12)
		if intensity <= 1:
			pattern = [
				(0, 2, bass),
				(2, 2, root),
				(4, 2, fifth),
				(6, 2, root),
			]
		elif intensity == 2:
			pattern = [
				(0, 1, bass),
				(1, 1, bass),
				(2, 1, root),
				(3, 1, fifth),
				(4, 1, root),
				(5, 1, fifth),
				(6, 1, root),
				(7, 1, octave),
			]
		else:
			pattern = [
				(0, 1, bass),
				(1, 1, root),
				(2, 1, fifth),
				(3, 1, octave),
				(4, 1, bass),
				(5, 1, root),
				(6, 1, fifth),
				(7, 1, root),
			]
		for slot, slot_length, note in pattern:
			start = bar_start + slot * EIGHTH_SECONDS
			duration = slot_length * EIGHTH_SECONDS * 0.92
			add_note(
				mix,
				start,
				duration,
				note,
				bass_tone,
				volume=0.12 + intensity * 0.018,
				pan=-0.02,
				attack_seconds=0.001,
				decay_seconds=0.04,
				sustain_level=0.64,
				release_seconds=0.05,
			)


def schedule_drums(mix: np.ndarray) -> None:
	for bar_index, intensity in enumerate(INTENSITY_BARS):
		bar_start = bar_index * BAR_SECONDS
		if intensity == 0:
			if bar_index >= 2:
				add_noise_hit(mix, bar_start + 1.5 * BEAT_SECONDS, 0.05, 0.025, 0.25, 10, 58.0)
				add_noise_hit(mix, bar_start + 3.5 * BEAT_SECONDS, 0.05, 0.028, -0.25, 10, 60.0)
			continue
		kicks = [0.0, 2.0]
		if intensity >= 3:
			kicks.append(3.5)
		if intensity >= 4:
			kicks.append(1.5)
		for beat in kicks:
			add_kick(mix, bar_start + beat * BEAT_SECONDS, 0.13 + intensity * 0.02)
		for beat in (1.0, 3.0):
			add_snare(mix, bar_start + beat * BEAT_SECONDS, 0.09 + intensity * 0.012)
		for step in range(8):
			hat_start = bar_start + step * EIGHTH_SECONDS
			pan = 0.18 if step % 2 == 0 else -0.18
			volume = 0.028 + intensity * 0.008 + (0.008 if step % 2 == 0 else 0.0)
			add_noise_hit(mix, hat_start, 0.042, volume, pan, 8, 76.0)
		if intensity >= 2:
			add_noise_hit(mix, bar_start + 3.5 * BEAT_SECONDS, 0.08, 0.038 + intensity * 0.005, 0.26, 12, 48.0)


def add_phrase_accents(mix: np.ndarray) -> None:
	for bar_index in range(0, len(PROGRESSION), 4):
		chord = CHORDS[PROGRESSION[bar_index]]
		note = chord["arp"][2]
		start = bar_index * BAR_SECONDS
		add_note(
			mix,
			start,
			BEAT_SECONDS * 1.5,
			note,
			arp_tone,
			volume=0.038 + INTENSITY_BARS[bar_index] * 0.004,
			pan=0.36,
			attack_seconds=0.002,
			decay_seconds=0.05,
			sustain_level=0.46,
			release_seconds=0.18,
		)


def apply_delay(mix: np.ndarray) -> np.ndarray:
	out = mix.copy()
	delays = [
		(0.18, 0.18, True),
		(0.36, 0.11, False),
		(0.54, 0.07, True),
	]
	for delay_seconds, gain, swap in delays:
		delay_samples = seconds_to_samples(delay_seconds)
		if delay_samples >= mix.shape[0]:
			continue
		if swap:
			out[delay_samples:, 0] += mix[:-delay_samples, 1] * gain
			out[delay_samples:, 1] += mix[:-delay_samples, 0] * gain
		else:
			out[delay_samples:] += mix[:-delay_samples] * gain
	return out


def finalize_mix(mix: np.ndarray) -> np.ndarray:
	mix = apply_delay(mix)
	fade_in = seconds_to_samples(0.03)
	mix[:fade_in] *= np.linspace(0.0, 1.0, fade_in, endpoint=False)[:, None]
	fade_out = seconds_to_samples(0.8)
	mix[-fade_out:] *= np.linspace(1.0, 0.0, fade_out, endpoint=False)[:, None]
	peak = float(np.max(np.abs(mix))) + 1e-9
	mix = mix / (peak * 1.22)
	mix = np.tanh(mix * 1.25)
	mix *= 0.9
	return mix


def render_track() -> np.ndarray:
	if len(PROGRESSION) != len(MELODY_BARS) or len(PROGRESSION) != len(INTENSITY_BARS):
		raise ValueError("Progression, melody, and intensity maps must have matching bar counts")
	total_seconds = len(PROGRESSION) * BAR_SECONDS + TAIL_SECONDS
	mix = np.zeros((seconds_to_samples(total_seconds), 2), dtype=np.float64)
	schedule_arps_and_pads(mix)
	schedule_bass(mix)
	schedule_melody(mix)
	schedule_drums(mix)
	add_phrase_accents(mix)
	return finalize_mix(mix)


def write_wav(path: Path, audio: np.ndarray) -> None:
	pcm = np.clip(audio, -1.0, 1.0)
	frames = (pcm * 32767.0).astype(np.int16)
	with wave.open(str(path), "wb") as wav_file:
		wav_file.setnchannels(2)
		wav_file.setsampwidth(2)
		wav_file.setframerate(SAMPLE_RATE)
		wav_file.writeframes(frames.tobytes())


def main() -> None:
	ffmpeg = shutil.which("ffmpeg")
	if ffmpeg is None:
		raise SystemExit("ffmpeg is required to encode the generated WAV to MP3")
	audio = render_track()
	OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
	with tempfile.TemporaryDirectory() as temp_dir:
		wav_path = Path(temp_dir) / "forest-ruins-adventure-theme.wav"
		write_wav(wav_path, audio)
		command = [
			ffmpeg,
			"-y",
			"-hide_banner",
			"-loglevel",
			"error",
			"-i",
			str(wav_path),
			"-codec:a",
			"libmp3lame",
			"-b:a",
			"224k",
			str(OUTPUT_PATH),
		]
		subprocess.run(command, check=True)
	duration_seconds = len(PROGRESSION) * BAR_SECONDS
	print(f"Wrote {OUTPUT_PATH.relative_to(ROOT)} ({duration_seconds:.1f}s of music)")


if __name__ == "__main__":
	main()
