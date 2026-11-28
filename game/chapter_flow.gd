class_name ChapterFlow
extends Node
## The story sequence (DESIGN §3, §9 M40), driven by the CHAPTERS_JSON table. For every chapter the file lists its levels,
## the cutscenes to play on entry (`entry_cutscenes`), rule cutscenes (`on`), exit cutscenes (`exit_cutscenes`), the
## objectives (OBJ_* translation keys) and the completion condition (`complete`):
##   {"type": "flag", "key": k}                    a GameState flag is set
##   {"type": "level_exit", "to": level_id}        the level trigger `level:<to>` fired
##   {"type": "waves"}                             the EncounterDirector finished every wave
##   {"type": "boss_yielded", "kind": kind}        a boss yielded (Lankini)
##   {"type": "searches", "count": n}              n different search points were searched
##   {"type": "event", "name": e}                  any LevelRuntime game_event
##   {"type": "cutscenes_done"}                    the entry cutscenes have all finished
## Any condition may carry "requires": {"flag": k, "searches": n}. A level may carry an "advance" condition that moves
## on to the next level of the chapter. The flow only emits signals (level_requested, cutscene_requested ...); the main
## scene loads the levels and plays the cutscenes. Chapter 1 (the leap) is handled by bind_leap(): the gates
## (Mainaka, Surasa, Simhika) and the Surasa size puzzle. There is no game-over state anywhere in this flow.

signal chapter_started(chapter_id: StringName)
signal chapter_ready(chapter_id: StringName)
signal chapter_finished(chapter_id: StringName)
signal level_requested(level_id: StringName, options: Dictionary)
signal cutscene_requested(cutscene_id: StringName)
signal encounter_requested(chapter_number: int)
signal objectives_changed
signal all_done

## Chapter table (owned by this module; kept inline so no data file outside M40 is needed).
const CHAPTERS_JSON: String = """{
  "chapters": [
    {
      "id": "prologue",
      "entry_cutscenes": ["opening_title", "pro_jambavan_intro"],
      "levels": [{ "id": "mahendra" }],
      "objectives": [
        { "id": "talk_jambavan", "key": "OBJ_PRO_TALK", "done": "dialogue:pro_jambavan" },
        { "id": "training", "key": "OBJ_PRO_TRAIN", "done": "objective:training" },
        { "id": "reach_peak", "key": "OBJ_PRO_LEAP", "done": "dialogue:pro_leap" }
      ],
      "complete": { "type": "event", "name": "dialogue:pro_leap" }
    },
    {
      "id": "ch1",
      "unlocks": ["grow"],
      "levels": [{ "id": "ocean_leap" }],
      "objectives": [
        { "id": "mainaka", "key": "OBJ_CH1_MAINAKA", "done": "dialogue:ch1_mainaka" },
        { "id": "surasa", "key": "OBJ_CH1_SURASA", "done": "flag:surasa_blessing" },
        { "id": "simhika", "key": "OBJ_CH1_SIMHIKA", "done": "flag:ch1_done" }
      ],
      "complete": { "type": "flag", "key": "ch1_done" }
    },
    {
      "id": "ch2",
      "unlocks": ["grow", "shrink"],
      "levels": [
        {
          "id": "lanka_gate",
          "advance": { "type": "level_exit", "to": "lanka_streets", "requires": { "flag": "gate_open" } }
        },
        { "id": "lanka_streets" }
      ],
      "on": [
        { "event": "boss_yielded:boss_lankini", "cutscene": "ch2_lankini_yields" }
      ],
      "objectives": [
        { "id": "lankini", "key": "OBJ_CH2_LANKINI", "done": "boss_yielded:boss_lankini" },
        { "id": "search", "key": "OBJ_CH2_SEARCH", "done": "searches:3" },
        { "id": "vatika", "key": "OBJ_CH2_VATIKA", "done": "level:ashoka_vatika" }
      ],
      "complete": { "type": "level_exit", "to": "ashoka_vatika", "requires": { "searches": 3 } }
    },
    {
      "id": "ch3",
      "unlocks": ["grow", "shrink"],
      "levels": [{ "id": "ashoka_vatika" }],
      "objectives": [
        { "id": "sita", "key": "OBJ_CH3_SITA", "done": "dialogue:ch3_grove" }
      ],
      "complete": { "type": "flag", "key": "ch3_done" }
    },
    {
      "id": "ch4",
      "unlocks": ["grow", "shrink", "surge"],
      "entry_cutscenes": ["ch4_battle_cry"],
      "waves": 4,
      "levels": [
        {
          "id": "ashoka_vatika",
          "opts": { "size": "normal", "skip_triggers": ["t_grove_story"], "encounter_chapter": 4 }
        }
      ],
      "objectives": [
        { "id": "grove_waves", "key": "OBJ_CH4_WAVES", "done": "waves_completed" }
      ],
      "complete": { "type": "waves" },
      "exit_cutscenes": ["ch4_brahmastra"]
    },
    {
      "id": "ch5",
      "unlocks": ["grow", "shrink", "surge"],
      "levels": [
        { "id": "ravana_court", "advance": { "type": "event", "name": "dialogue:ch5_court" } },
        { "id": "lanka_rooftops" }
      ],
      "objectives": [
        { "id": "court", "key": "OBJ_CH5_COURT", "done": "dialogue:ch5_court" },
        { "id": "burn", "key": "OBJ_CH5_BURN", "done": "fire_ignited" },
        { "id": "ocean", "key": "OBJ_CH5_OCEAN", "done": "chapter_complete:ch5" }
      ],
      "complete": { "type": "event", "name": "chapter_complete:ch5" },
      "exit_cutscenes": ["ch5_return"]
    },
    {
      "id": "epilogue",
      "entry_cutscenes": ["epilogue"],
      "levels": [
        {
          "id": "mahendra",
          "opts": { "size": "normal", "skip_triggers": ["t_jambavan", "t_training_done", "t_leap"] }
        }
      ],
      "complete": { "type": "cutscenes_done" }
    },
    {
      "id": "teaser_setu",
      "entry_cutscenes": ["teaser_setu"],
      "levels": [
        {
          "id": "mahendra",
          "opts": {
            "size": "normal",
            "skip_triggers": ["t_jambavan", "t_training_done", "t_leap"],
            "extra_npcs": [{ "id": "rama", "pos": [17.0, 13.0], "facing": 270 }]
          }
        }
      ],
      "complete": { "type": "cutscenes_done" }
    }
  ]
}"""

## Fallback EN/HI texts for the keys this module uses (tr() wins when the translation table has the key).
const TEXTS: Dictionary = {
	"OBJ_PRO_TALK": ["Speak with Jambavan", "जाम्बवान से बात करें"],
	"OBJ_PRO_TRAIN": ["Strike the training rocks", "प्रशिक्षण-शिलाओं पर प्रहार करें"],
	"OBJ_PRO_LEAP": ["Climb to the peak and leap", "शिखर पर चढ़कर छलाँग लगाएँ"],
	"OBJ_CH1_MAINAKA": ["Greet Mainaka and fly on", "मैनाक का अभिवादन करें और आगे उड़ें"],
	"OBJ_CH1_SURASA": ["Get past Surasa: outwit her", "सुरसा को पार करें: बुद्धि से"],
	"OBJ_CH1_SIMHIKA": ["Defeat Simhika", "सिंहिका को परास्त करें"],
	"OBJ_CH2_LANKINI": ["Face Lankini at the gate", "द्वार पर लंकिनी का सामना करें"],
	"OBJ_CH2_SEARCH": ["Search Lanka: the mansions, the palace, the Pushpaka courtyard", "लंका में खोजें: भवन, राजमहल और पुष्पक-प्रांगण"],
	"OBJ_CH2_VATIKA": ["Find the Ashoka Vatika", "अशोक वाटिका खोजें"],
	"OBJ_CH3_SITA": ["Speak with Sita Mata", "सीता माता से बात करें"],
	"OBJ_CH4_WAVES": ["Break the grove's defenders", "वाटिका के रक्षकों को परास्त करें"],
	"OBJ_CH5_COURT": ["Speak before Ravana", "रावण के सम्मुख वचन कहें"],
	"OBJ_CH5_BURN": ["Spread fire to the rakshasa armouries", "राक्षसों के शस्त्रागारों में अग्नि फैलाएँ"],
	"OBJ_CH5_OCEAN": ["Reach the ocean and cool your tail", "समुद्र तक पहुँचकर पूँछ की अग्नि शांत करें"],
	"SIM_PHASE1": ["Simhika's dark pool hunts your shadow. Keep moving, and strike her!", "सिंहिका का काला भँवर आपकी छाया का पीछा कर रहा है। चलते रहिए, और उस पर प्रहार कीजिए!"],
	"SIM_SHADOW_NEAR": ["Her pool is right under you - steer or dodge away!", "भँवर ठीक आपके नीचे है - हटिए या कूदकर बचिए!"],
	"SIM_GRABBED": ["She seized your shadow!", "उसने आपकी छाया पकड़ ली!"],
	"SIM_PHASE2": ["Simhika hurls waves at you. Strike her between them!", "सिंहिका आप पर लहरें फेंक रही है। लहरों के बीच उस पर प्रहार कीजिए!"],
	"SIM_WAVE_COMING": ["A wave is coming - get out of the glowing band!", "लहर आ रही है - चमकती पट्टी से हट जाइए!"],
	"SIM_JAWS_SHUT": ["Simhika rises from the sea, jaws shut. Wait for them to open...", "सिंहिका समुद्र से उठती है, मुख बंद है। उसके खुलने की प्रतीक्षा कीजिए..."],
	"SIM_JAWS_OPEN": ["Her jaws gape - shrink now to dive inside!", "उसका मुख खुला है - अभी सिकुड़कर भीतर कूदिए!"],
	"SIM_INSIDE": ["Inside Simhika! Strike her from within!", "सिंहिका के भीतर! भीतर से प्रहार कीजिए!"],
	"SIM_BITTEN": ["Too slow - her jaws snapped shut on you. Wait for the next opening.", "देर हो गई - उसका मुख आप पर बंद हो गया। अगले अवसर की प्रतीक्षा कीजिए।"],
	"SIM_CONTROLS_FIGHT": ["%s / %s Steer    %s Dodge    %s Strike (hold: heavy)", "%s / %s दिशा    %s बचाव    %s प्रहार (दबाए रखें: भारी)"],
	"SIM_CONTROLS_JAWS": ["%s Shrink", "%s सिकुड़ें"],
	"SIM_CONTROLS_INSIDE": ["%s Strike", "%s प्रहार"],
	"SUR_START": ["Surasa bars the way: none may pass but through her jaws.", "सुरसा मार्ग रोके खड़ी है: उसके मुख से होकर ही कोई आगे जा सकता है।"],
	"SUR_OPENING": ["Surasa's jaws stretch wider than you...", "सुरसा का मुख आपसे भी बड़ा फैल रहा है..."],
	"SUR_OPEN": ["Her jaws gape wide open.", "उसका मुख पूरा खुल गया है।"],
	"SUR_WINDUP": ["Surasa rears up to swallow you!", "सुरसा आपको निगलने को झपटने वाली है!"],
	"SUR_GULPED": ["She snapped at you - you broke free. Try again.", "वह आप पर झपटी - आप छूट निकले। फिर प्रयास करें।"],
	"SUR_TINY": ["Thumb-sized! Her wide jaws close slowly...", "अँगूठे भर के! उसका चौड़ा मुख धीरे-धीरे बंद हो रहा है..."],
	"SUR_FEINT": ["She saw it coming and snaps her jaws shut!", "उसने चाल भाँप ली और झट से मुख बंद कर रही है!"],
	"SUR_CLOSED": ["Her jaws are shut. Make her open them again.", "उसका मुख बंद है। उसे फिर से खुलवाइए।"],
	"SUR_TOO_NARROW": ["Too narrow - her jaws have nearly closed.", "बहुत संकरा - उसका मुख लगभग बंद हो चुका है।"],
	"SUR_TOO_BIG": ["You are far too big to slip in.", "इतने बड़े होकर आप भीतर नहीं जा सकते।"],
	"SUR_INSIDE": ["Inside! Get out before her jaws close!", "भीतर! मुख बंद होने से पहले बाहर निकलिए!"],
	"SUR_SPAT": ["Her jaws closed on you - she spat you out. Try again.", "मुख बंद हो गया - उसने आपको बाहर थूक दिया। फिर प्रयास करें।"],
	"SUR_HINT": ["Hint: let her open as wide as she can, then suddenly become tiny.", "संकेत: उसे जितना हो सके मुख खोलने दें, फिर अचानक छोटे हो जाएँ।"],
	"SUR_CONTROLS": ["%s Grow    %s Shrink    %s Dart in / out", "%s बढ़ें    %s सिकुड़ें    %s भीतर / बाहर"],
	"UI_CREDITS_1": ["Based on the Sundara Kanda of the Valmiki Ramayana", "वाल्मीकि रामायण के सुन्दरकाण्ड पर आधारित"],
	"UI_CREDITS_2": ["Thank you for playing", "खेलने के लिए धन्यवाद"],
	"UI_CREDITS_3": ["Press any key", "कोई भी कुंजी दबाएँ"],
}


## Translated text for `key`: the translation table first, then the built-in EN/HI fallback.
static func text(key: String) -> String:
	var translated: String = TranslationServer.translate(key)
	if translated != key or not TEXTS.has(key):
		return translated
	var pair: Array = TEXTS[key] as Array
	return str(pair[1] if TranslationServer.get_locale().begins_with("hi") else pair[0])

const DEFAULT_SAVE_SLOT: int = 0
const SHRINK_UNLOCK_FLAG: StringName = &"shrink_unlocked"
const MAINAKA_FILE: String = "ch1_mainaka"
const SURASA_FILE: String = "ch1_surasa"
const SIMHIKA_FILE: String = "ch1_simhika"
const SEA_LEVEL: float = -12.0
const SURASA_SCALE: float = 6.0
const SURASA_DISTANCE: float = 34.0
## The Simhika narration warns when her shadow pool is this close to Hanuman (metres).
const SIMHIKA_SHADOW_WARN: float = 6.0
## How long "her jaws snapped shut on you" stays up after a missed dive (seconds).
const SIMHIKA_BITTEN_SHOW: float = 1.5
## The chase camera offset of the rider at normal flight size (level_runtime builds it there).
const CHASE_BASE: Vector3 = Vector3(0.0, 5.0, 17.0)
const MOUTH_MESH_RADIUS: float = 0.3
const MOUTH_LOCAL_Y: float = 3.5
const MOUTH_LOCAL_Z: float = -0.62
const HANUMAN_GIANT_HEIGHT: float = SizeShift.BODY_HEIGHT * 6.0
## Jaw width per jaw level, in Hanuman GIANT heights (0.55 x 2 = 1.1 x his height at growth 1).
const JAW_PER_STEP: float = 0.55
const CHASE_ROTATION: Vector3 = Vector3(-10.0, 0.0, 0.0)
## Direction (rider-local) of the trial camera from the midpoint of Hanuman and Surasa: to the side, a little up and
## behind, so both stand side by side and her jaws face the camera at an angle.
const SURASA_CAMERA_DIR: Vector3 = Vector3(0.85, 0.2, 0.55)
## Simhika fight camera: higher than Surasa's so the pool and wave band on the water read clearly.
const SIMHIKA_CAMERA_DIR: Vector3 = Vector3(0.8, 0.55, 0.5)
## Height of Simhika's body to keep in frame (metres).
const SIMHIKA_FRAME_HEIGHT: float = 14.0
## Breathing room around the framed pair (1 = edge to edge).
const SURASA_FRAME_MARGIN: float = 1.75
const MAINAKA_SCALE: float = 5.0
const SIMHIKA_DISTANCE: float = 26.0
const LEAP_ATTACK_RANGE: float = 40.0
const LEAP_LIGHT_DAMAGE: int = 12
const LEAP_HEAVY_DAMAGE: int = 35
const LEAP_HEAVY_HOLD: float = 0.5
## Leap gada swing timing (seconds): wind-up before the blow, then how long the blow is held.
const LEAP_SWING_WIND: float = 0.08
const LEAP_SWING_WIND_HEAVY: float = 0.16
const LEAP_SWING_HOLD: float = 0.3


## The Surasa trial (DESIGN §3 Ch1), redesigned 2026-11-27 on owner feedback ("the player should control when to
## enlarge and reduce and try to trick Surasa"). Nothing is scripted: Hanuman grows and shrinks whenever the player
## likes, and Surasa always opens her jaws one step wider than he is.
## - She opens at OPEN_SPEED. Once her jaws are fully open she holds for WINDUP_DELAY, then winds up a bite for
##   WINDUP_TIME. Growing again makes her open further (and resets the bite); at MAX_GROWTH he cannot grow further.
##   A bite that lands "gulps the air" and resets the trial (no damage, no failure state).
## - The trick: once her jaws are fully open, Shrink to a thumb's size. Committed, she can only close slowly
##   (CLOSE_SPEED); shrink while she is still opening and she sees through the feint and snaps shut (SNAP_SPEED).
## - Dart slips in while her jaws are at least ENTER_MIN wide, and Dart again (after INSIDE_MIN_TIME) slips out while
##   they are still at least EXIT_MIN wide. Too late and she spits him out: the trial resets.
## The wider he baits her, the more time the trick gives, but the longer he must outpace her bites.
class SurasaPuzzle extends RefCounted:
	enum Phase { IDLE, PLAYING, INSIDE, DONE }

	## Fired on every notable change: &"opening", &"open" (fully open), &"windup", &"gulped", &"tiny", &"feint",
	## &"closed", &"too_narrow", &"inside", &"spat", &"too_big".
	signal state_changed(state: StringName)
	## Hanuman's growth changed (0 = thumb-sized, 1..MAX_GROWTH = giant steps).
	signal growth_changed(growth: int)
	signal solved

	const MAX_GROWTH: int = 4
	## Extra scale over GIANT for growth 1..MAX_GROWTH.
	const GROWTH_SCALES: Array[float] = [1.0, 1.3, 1.6, 1.9]
	const OPEN_SPEED: float = 1.5
	const CLOSE_SPEED: float = 0.7
	const SNAP_SPEED: float = 2.5
	const WINDUP_DELAY: float = 1.0
	const WINDUP_TIME: float = 1.2
	const ENTER_MIN: float = 2.5
	const EXIT_MIN: float = 1.2
	const INSIDE_MIN_TIME: float = 0.35
	const MOUTH_CLOSED: float = 1.0
	const SIZE_SMALL: int = 0
	const SIZE_GIANT: int = 3

	var phase: Phase = Phase.IDLE
	## 0 = thumb-sized, 1..MAX_GROWTH = giant steps.
	var growth: int = 1
	## Surasa's jaw width in "steps" (1 = closed, growth + 1 = fully open for his current size).
	var mouth: float = MOUTH_CLOSED
	var hold: float = 0.0
	var windup: float = 0.0
	var inside_time: float = 0.0
	var close_speed: float = CLOSE_SPEED
	## Counters for hints and the playtest bot.
	var gulps: int = 0
	var feints: int = 0
	var spits: int = 0
	var shift: SizeShift = null

	## Starts a fresh attempt: Hanuman giant (growth 1), Surasa's jaws closed.
	func begin(size_shift: SizeShift) -> void:
		shift = size_shift
		phase = Phase.PLAYING
		_reset_round()

	func is_active() -> bool:
		return phase == Phase.PLAYING or phase == Phase.INSIDE

	## Jaw width Surasa is opening toward (growth + 1 while he is giant).
	func target_mouth() -> float:
		return float(growth + 1) if growth > 0 else MOUTH_CLOSED

	func is_fully_open() -> bool:
		return growth > 0 and mouth >= target_mouth() - 0.001

	## 0..1 progress of the bite wind-up (0 when she is not winding up).
	func windup_fraction() -> float:
		return clampf(windup / WINDUP_TIME, 0.0, 1.0)

	## Extra scale over GIANT for the current growth (1 when thumb-sized, the size table handles SMALL).
	func growth_scale() -> float:
		return GROWTH_SCALES[growth - 1] if growth > 0 else 1.0

	## The player pressed Grow. Returns true when it counted.
	func on_grow() -> bool:
		if phase != Phase.PLAYING or growth >= MAX_GROWTH:
			return false
		growth += 1
		hold = 0.0
		windup = 0.0
		_apply_size()
		growth_changed.emit(growth)
		state_changed.emit(&"opening")
		return true

	## The player pressed Shrink: straight down to a thumb's size. Returns true when it counted.
	func on_shrink() -> bool:
		if phase != Phase.PLAYING or growth == 0:
			return false
		var committed: bool = is_fully_open()
		growth = 0
		hold = 0.0
		windup = 0.0
		close_speed = CLOSE_SPEED if committed else SNAP_SPEED
		_apply_size()
		growth_changed.emit(growth)
		if committed:
			state_changed.emit(&"tiny")
		else:
			feints += 1
			state_changed.emit(&"feint")
		return true

	## The player pressed Dart: in through her jaws, or back out. Returns true when it moved him.
	func on_dart() -> bool:
		match phase:
			Phase.PLAYING:
				if growth > 0:
					state_changed.emit(&"too_big")
					return false
				if mouth < ENTER_MIN:
					state_changed.emit(&"too_narrow")
					return false
				phase = Phase.INSIDE
				inside_time = 0.0
				state_changed.emit(&"inside")
				return true
			Phase.INSIDE:
				if inside_time < INSIDE_MIN_TIME:
					return false
				phase = Phase.DONE
				solved.emit()
				return true
		return false

	## Advances Surasa by delta seconds (frame-rate independent).
	func tick(delta: float) -> void:
		if not is_active() or delta <= 0.0:
			return
		if phase == Phase.INSIDE:
			inside_time += delta
			mouth = maxf(MOUTH_CLOSED, mouth - close_speed * delta)
			if mouth < EXIT_MIN:
				spits += 1
				phase = Phase.PLAYING
				_reset_round()
				state_changed.emit(&"spat")
			return
		if growth == 0:
			if mouth > MOUTH_CLOSED:
				mouth = maxf(MOUTH_CLOSED, mouth - close_speed * delta)
				if mouth <= MOUTH_CLOSED:
					state_changed.emit(&"closed")
			return
		var target: float = target_mouth()
		if mouth < target:
			mouth = minf(target, mouth + OPEN_SPEED * delta)
			if mouth >= target:
				state_changed.emit(&"open")
			return
		if mouth > target:
			mouth = maxf(target, mouth - CLOSE_SPEED * delta)
			return
		if hold < WINDUP_DELAY:
			hold += delta
			if hold >= WINDUP_DELAY:
				state_changed.emit(&"windup")
			return
		windup += delta
		if windup >= WINDUP_TIME:
			gulps += 1
			_reset_round()
			state_changed.emit(&"gulped")

	func _reset_round() -> void:
		growth = 1
		mouth = MOUTH_CLOSED
		hold = 0.0
		windup = 0.0
		inside_time = 0.0
		close_speed = CLOSE_SPEED
		_apply_size()
		growth_changed.emit(growth)

	func _apply_size() -> void:
		if shift == null:
			return
		if growth == 0:
			shift.set_bonus_scale(1.0)
			shift.force_size(SIZE_SMALL as SizeShift.SIZE)
		else:
			shift.force_size(SIZE_GIANT as SizeShift.SIZE)
			shift.set_bonus_scale(GROWTH_SCALES[growth - 1])


## Test hook: when false the flow does not write its save slot.
var autosave: bool = true
## The GameState save slot used for chapter starts and Continue (shrines also save to slot 0).
var save_slot: int = DEFAULT_SAVE_SLOT
## Overrides the autoload lookups (tests).
var event_bus: Node = null
var game_state: Node = null

var _chapters: Array[Dictionary] = []
var _index: int = -1
var _level_pos: int = 0
var _searches: Array[String] = []
var _objectives: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _busy: bool = false
var _entry_pending: bool = false
var _awaiting_ready: bool = false
var _completing: bool = false
var _finished: bool = false
var _fired_rules: Array[int] = []

# --- leap (chapter 1) ---
var _rt: LevelRuntime = null
var _puzzle: SurasaPuzzle = null
var _surasa: Node3D = null
var _mouth: MeshInstance3D = null
var _surasa_status: String = "SUR_START"
var _mainaka: Node3D = null
var _boss: BossSimhika = null
var _surasa_stage: int = 0
var _simhika_stage: int = 0
var _simhika_status: String = ""
var _simhika_bitten: float = 0.0
var _swing_time: float = -1.0
var _swing_wind: float = 0.08
var _gate: StringName = &""
var _heavy_hold: float = 0.0


func _init() -> void:
	load_text(CHAPTERS_JSON)


# ---------------------------------------------------------------- data

## Reads the chapter list from a JSON file. Returns OK, ERR_FILE_NOT_FOUND or ERR_PARSE_ERROR.
func load_data(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return load_text(FileAccess.get_file_as_string(path))


## Reads the chapter list from JSON text. Returns OK or ERR_PARSE_ERROR.
func load_text(json_text: String) -> Error:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return ERR_PARSE_ERROR
	var raw: Variant = (parsed as Dictionary).get("chapters", null)
	if not (raw is Array):
		return ERR_PARSE_ERROR
	_chapters.clear()
	for entry: Variant in raw as Array:
		if entry is Dictionary:
			_chapters.append(entry as Dictionary)
	return OK


func chapter_count() -> int:
	return _chapters.size()


func chapter_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for chapter: Dictionary in _chapters:
		out.append(StringName(str(chapter.get("id", ""))))
	return out


func chapter_data(index: int) -> Dictionary:
	if index < 0 or index >= _chapters.size():
		return {}
	return _chapters[index]


func current_index() -> int:
	return _index


func current_id() -> StringName:
	if _index < 0 or _index >= _chapters.size():
		return &""
	return StringName(str(_chapters[_index].get("id", "")))


func current_level() -> StringName:
	return StringName(str(_level_def(_level_pos).get("id", "")))


func is_finished() -> bool:
	return _finished


func search_count() -> int:
	return _searches.size()


func objective_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for obj: Dictionary in _objectives:
		out.append(StringName(str(obj["id"])))
	return out


func is_objective_done(id: StringName) -> bool:
	for obj: Dictionary in _objectives:
		if str(obj["id"]) == str(id):
			return obj["complete"] as bool
	return false


func is_busy_with_cutscene() -> bool:
	return _busy


func queued_cutscenes() -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Dictionary in _queue:
		out.append(StringName(str(item["id"])))
	return out


func _chapter() -> Dictionary:
	return chapter_data(_index)


func _level_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = _chapter().get("levels", [])
	if raw is Array:
		for entry: Variant in raw as Array:
			if entry is Dictionary:
				out.append(entry as Dictionary)
			else:
				out.append({"id": str(entry)})
	return out


func _level_def(pos: int) -> Dictionary:
	var defs: Array[Dictionary] = _level_defs()
	if pos < 0 or pos >= defs.size():
		return {}
	return defs[pos]


# ---------------------------------------------------------------- starting and continuing

## New game: wipes GameState and the objective list and starts chapter 0.
func new_game() -> void:
	var gs: Node = _state()
	if gs != null:
		gs.call("reset")
	_reset_objectives_autoload()
	_finished = false
	start_chapter(0)


## True when a save exists in slot 0.
func has_save() -> bool:
	return FileAccess.file_exists("user://save_%d.json" % save_slot)


## Continue: loads slot 0 and resumes at the start of the saved chapter. Returns false when there is no usable save.
func continue_game() -> bool:
	var gs: Node = _state()
	if gs == null or not has_save():
		return false
	if (gs.call("load_game", save_slot) as int) != OK:
		return false
	var saved: StringName = gs.get("chapter") as StringName
	var found: int = chapter_ids().find(saved)
	if found < 0:
		found = 0
	_reset_objectives_autoload()
	_finished = false
	start_chapter(found, false)
	return true


## Starts the chapter at `index`: unlocks its abilities, saves (chapter start), and asks for its first level.
func start_chapter(index: int, save: bool = true) -> void:
	if index < 0 or index >= _chapters.size():
		_finished = true
		all_done.emit()
		return
	_index = index
	_level_pos = 0
	_searches.clear()
	_queue.clear()
	_busy = false
	_completing = false
	_fired_rules.clear()
	_entry_pending = true
	_awaiting_ready = false
	_build_objectives()
	var gs: Node = _state()
	if gs != null:
		gs.set("chapter", current_id())
		for ability: Variant in _chapter().get("unlocks", []) as Array:
			gs.call("unlock", StringName(str(ability)))
		LevelRuntime.sync_unlocks(gs)
		if save and autosave:
			gs.call("save_game", save_slot)
	chapter_started.emit(current_id())
	_request_level()


func _request_level() -> void:
	var def: Dictionary = _level_def(_level_pos)
	var opts: Dictionary = {}
	var raw: Variant = def.get("opts", {})
	if raw is Dictionary:
		opts = (raw as Dictionary).duplicate(true)
	level_requested.emit(StringName(str(def.get("id", ""))), opts)


# ---------------------------------------------------------------- objectives

func _build_objectives() -> void:
	_objectives.clear()
	var raw: Variant = _chapter().get("objectives", [])
	if raw is Array:
		for entry: Variant in raw as Array:
			if not (entry is Dictionary):
				continue
			var source: Dictionary = entry as Dictionary
			_objectives.append({
				"id": str(source.get("id", "")),
				"key": str(source.get("key", "")),
				"done": str(source.get("done", "")),
				"complete": false,
			})
	var objectives: Node = _autoload("Objectives")
	if objectives != null:
		for obj: Dictionary in _objectives:
			objectives.call("add", StringName(str(obj["id"])), ChapterFlow.text(str(obj["key"])))


func _reset_objectives_autoload() -> void:
	var objectives: Node = _autoload("Objectives")
	if objectives != null:
		objectives.set("_texts", {})
		objectives.set("_done", {})


func _announce_objectives() -> void:
	var bus: Node = _bus()
	if bus == null:
		return
	for obj: Dictionary in _objectives:
		bus.emit_signal("objective_updated", StringName(str(obj["id"])), ChapterFlow.text(str(obj["key"])), obj["complete"] as bool)


func _complete_objective(obj: Dictionary) -> void:
	if obj["complete"] as bool:
		return
	obj["complete"] = true
	var objectives: Node = _autoload("Objectives")
	if objectives != null:
		objectives.call("complete", StringName(str(obj["id"])))
	objectives_changed.emit()


func _update_objectives(event_name: String) -> void:
	for obj: Dictionary in _objectives:
		if obj["complete"] as bool:
			continue
		var done: String = str(obj["done"])
		if done == "":
			continue
		if done == event_name or _state_condition(done):
			_complete_objective(obj)


## "flag:<k>" and "searches:<n>" objective triggers are checked against the current state on every event.
func _state_condition(text: String) -> bool:
	if text.begins_with("flag:"):
		return _flag(text.substr(5))
	if text.begins_with("searches:"):
		return _searches.size() >= text.substr(9).to_int()
	return false


# ---------------------------------------------------------------- level loading and events

## Called by the main scene after a LevelRuntime finished loading `level_id`.
func notify_level_loaded(level_id: StringName, runtime: LevelRuntime) -> void:
	_announce_objectives()
	if runtime != null and runtime.leap() != null:
		bind_leap(runtime)
	if not _entry_pending:
		_after_level_ready()
		return
	_entry_pending = false
	_awaiting_ready = true
	var entry: Variant = _chapter().get("entry_cutscenes", [])
	if entry is Array:
		for id: Variant in entry as Array:
			_queue.append({"id": str(id), "kind": "entry"})
	_pump()
	if level_id == &"":
		return


func _after_level_ready() -> void:
	chapter_ready.emit(current_id())
	var waves: int = (_chapter().get("waves", 0) as int)
	if waves > 0:
		encounter_requested.emit(waves)
	var complete: Dictionary = _chapter().get("complete", {}) as Dictionary
	if str(complete.get("type", "")) == "cutscenes_done":
		_complete_chapter()


## The generic entry point: every LevelRuntime.game_event is forwarded here.
func handle_event(event_name: String) -> void:
	if _index < 0 or _finished or _completing:
		return
	if event_name.begins_with("search:"):
		var search_id: String = event_name.substr(7)
		if not _searches.has(search_id):
			_searches.append(search_id)
	_update_objectives(event_name)
	var rules: Variant = _chapter().get("on", [])
	if rules is Array:
		var rule_list: Array = rules as Array
		for i: int in range(rule_list.size()):
			var rule: Dictionary = rule_list[i] as Dictionary
			if str(rule.get("event", "")) == event_name and not _fired_rules.has(i):
				_fired_rules.append(i)
				_queue.append({"id": str(rule.get("cutscene", "")), "kind": "rule"})
	var advance: Dictionary = _level_def(_level_pos).get("advance", {}) as Dictionary
	if not advance.is_empty() and _level_pos < _level_defs().size() - 1 and condition_met(advance, event_name):
		_level_pos += 1
		_request_level()
		_pump()
		return
	var complete: Dictionary = _chapter().get("complete", {}) as Dictionary
	if condition_met(complete, event_name):
		_complete_chapter()
		return
	_pump()


## Does `condition` hold for `event_name`? Event-type conditions match the event; flag and search ones read the state.
func condition_met(condition: Dictionary, event_name: String) -> bool:
	if condition.is_empty():
		return false
	var requires: Variant = condition.get("requires", {})
	if requires is Dictionary and not _requires_met(requires as Dictionary):
		return false
	match str(condition.get("type", "")):
		"flag":
			return _flag(str(condition.get("key", "")))
		"level_exit":
			return event_name == "level:%s" % str(condition.get("to", ""))
		"waves":
			return event_name == "waves_completed"
		"boss_yielded":
			return event_name == "boss_yielded:%s" % str(condition.get("kind", ""))
		"searches":
			return _searches.size() >= (condition.get("count", 1) as int)
		"event":
			return event_name == str(condition.get("name", ""))
	return false


func _requires_met(requires: Dictionary) -> bool:
	if requires.has("flag") and not _flag(str(requires["flag"])):
		return false
	if requires.has("searches") and _searches.size() < (requires["searches"] as int):
		return false
	return true


func _flag(key: String) -> bool:
	var gs: Node = _state()
	if gs == null:
		return false
	return gs.call("get_flag", StringName(key), false) as bool


# ---------------------------------------------------------------- cutscene queue

func _pump() -> void:
	if _busy:
		return
	if _queue.is_empty():
		_on_queue_empty()
		return
	_busy = true
	cutscene_requested.emit(StringName(str(_queue[0]["id"])))


## The main scene calls this when a cutscene it started has finished (or could not be played).
func notify_cutscene_finished(_cutscene_id: StringName) -> void:
	if not _busy:
		return
	_busy = false
	if not _queue.is_empty():
		_queue.pop_front()
	_pump()


func _on_queue_empty() -> void:
	if _completing:
		_finish_chapter()
	elif _awaiting_ready:
		_awaiting_ready = false
		_after_level_ready()


func _complete_chapter() -> void:
	if _completing or _finished:
		return
	_completing = true
	var exits: Variant = _chapter().get("exit_cutscenes", [])
	if exits is Array:
		for id: Variant in exits as Array:
			_queue.append({"id": str(id), "kind": "exit"})
	_pump()


func _finish_chapter() -> void:
	var finished_id: StringName = current_id()
	for obj: Dictionary in _objectives:
		_complete_objective(obj)
	var gs: Node = _state()
	if gs != null:
		gs.call("set_flag", StringName("chapter_%s_done" % str(finished_id)), true)
	_completing = false
	chapter_finished.emit(finished_id)
	var bus: Node = _bus()
	if bus != null:
		bus.emit_signal("chapter_completed", finished_id)
	if _index + 1 < _chapters.size():
		start_chapter(_index + 1)
	else:
		_finished = true
		all_done.emit()


# ---------------------------------------------------------------- the leap (chapter 1)

## Wires the leap gates of a runtime built for ocean_leap: Mainaka (dialogue, the ring heals), Surasa (the size
## puzzle) and Simhika (BossSimhika.attach_leap). Called by notify_level_loaded.
func bind_leap(runtime: LevelRuntime) -> void:
	_rt = runtime
	var controller: LeapController = runtime.leap()
	if controller == null:
		return
	_surasa_stage = 0
	_simhika_stage = 0
	_puzzle = SurasaPuzzle.new()
	_puzzle.state_changed.connect(_on_surasa_state)
	_puzzle.solved.connect(_on_puzzle_solved)
	controller.gate_reached.connect(_on_gate_reached)
	controller.failed.connect(_on_leap_failed)
	runtime.dialogue_done.connect(_on_leap_dialogue_done)
	if not runtime.game_event.is_connected(handle_event):
		runtime.game_event.connect(handle_event)
	_rt.show_prompt("")


func puzzle() -> SurasaPuzzle:
	return _puzzle


func _on_gate_reached(gate_id: StringName) -> void:
	_gate = gate_id
	if _rt == null:
		return
	match gate_id:
		&"mainaka":
			_place_mainaka()
			_rt.play_dialogue(MAINAKA_FILE)
		&"surasa":
			_place_surasa()
			_surasa_stage = 0
			_rt.play_dialogue("%s#n1" % SURASA_FILE)
		&"simhika":
			_place_simhika()
			_simhika_stage = 0
			_rt.play_dialogue("%s#n1" % SIMHIKA_FILE)


func _on_leap_dialogue_done(file_id: StringName) -> void:
	var controller: LeapController = _rt.leap() if _rt != null else null
	if controller == null:
		return
	match str(file_id):
		MAINAKA_FILE:
			_remove(_mainaka)
			_mainaka = null
			controller.resume()
		SURASA_FILE:
			if _surasa_stage == 0:
				_surasa_stage = 1
				_surasa_status = "SUR_START"
				_puzzle.begin(_rt.size_shift())
				_update_surasa_prompt()
			elif _surasa_stage == 2:
				_surasa_stage = 3
				var gs: Node = _state()
				if gs != null:
					gs.call("set_flag", SHRINK_UNLOCK_FLAG, true)
					LevelRuntime.sync_unlocks(gs)
				_rt.size_shift().set_bonus_scale(1.0)
				_rt.size_shift().force_size(SizeShift.SIZE.GIANT)
				_set_rider_dart(0.0)
				_set_chase_scale(1.0)
				_remove(_surasa)
				_surasa = null
				controller.resume()
		SIMHIKA_FILE:
			if _simhika_stage == 0:
				_simhika_stage = 1
				_boss.engage(_rt.rider())
			elif _simhika_stage == 2:
				_simhika_stage = 3


func _remove(node: Node3D) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _gate_origin(extra: float) -> Vector3:
	var controller: LeapController = _rt.leap()
	var pos: Vector3 = controller.rider_position()
	var ahead: Vector3 = controller.rail_tangent(controller.distance)
	var spot: Vector3 = pos + ahead * extra
	spot.y = SEA_LEVEL
	return spot


func _face_rider(node: Node3D) -> void:
	var rider: Node3D = _rt.rider()
	var to: Vector3 = rider.global_position - node.global_position
	to.y = 0.0
	if to.length() > 0.01:
		node.rotation.y = atan2(-to.x, -to.z)


func _place_mainaka() -> void:
	_mainaka = NpcModels.build(&"mainaka")
	_mainaka.scale = Vector3.ONE * MAINAKA_SCALE
	_rt.add_child(_mainaka)
	var controller: LeapController = _rt.leap()
	var side: Vector3 = controller.rail_tangent(controller.distance).cross(Vector3.UP).normalized()
	_mainaka.global_position = _gate_origin(12.0) - side * 30.0


func _place_surasa() -> void:
	_surasa = NpcModels.build(&"surasa")
	_surasa.scale = Vector3.ONE * SURASA_SCALE
	_rt.add_child(_surasa)
	_surasa.global_position = _gate_origin(SURASA_DISTANCE)
	_face_rider(_surasa)
	_mouth = MeshInstance3D.new()
	_mouth.name = "Mouth"
	_mouth.mesh = _maw_mesh()
	_mouth.material_override = MeshKit.flat_material()
	_mouth.position = Vector3(0.0, MOUTH_LOCAL_Y, MOUTH_LOCAL_Z)
	_surasa.add_child(_mouth)
	_update_surasa_visuals()


## Surasa's open maw, facing -Z (toward Hanuman): a dark throat disc of radius MOUTH_MESH_RADIUS in a sindoor-red
## rim of lips, with two fangs above and two below. Scaled as a whole so its width matches the jaw level.
static func _maw_mesh() -> ArrayMesh:
	var r: float = MOUTH_MESH_RADIUS
	var face_z: Basis = Basis(Vector3.RIGHT, PI * 0.5)  # cylinder axis Y -> Z
	var parts: Array[Dictionary] = [
		{"mesh": MeshKit.cylinder(r * 1.18, r * 1.18, r * 0.25, 20, Palette.SINDOOR),
			"transform": Transform3D(face_z, Vector3(0.0, 0.0, r * 0.12))},
		{"mesh": MeshKit.cylinder(r, r, r * 0.3, 20, Palette.UI_DARK),
			"transform": Transform3D(face_z, Vector3(0.0, 0.0, -r * 0.05))},
	]
	for side: float in [-0.4, 0.4]:
		parts.append({"mesh": MeshKit.cone(r * 0.12, r * 0.42, 6, Palette.MOON),
			"transform": Transform3D(Basis(Vector3.BACK, PI), Vector3(side * r, r * 0.95, -r * 0.22))})
		parts.append({"mesh": MeshKit.cone(r * 0.1, r * 0.32, 6, Palette.MOON),
			"transform": Transform3D(Basis(), Vector3(side * r * 0.8, -r * 0.95, -r * 0.22))})
	return MeshKit.merge(parts)


func _place_simhika() -> void:
	_boss = BossSimhika.new()
	_boss.name = "BossSimhika"
	_rt.add_child(_boss)
	_boss.global_position = _gate_origin(SIMHIKA_DISTANCE)
	_face_rider(_boss)
	_boss.attach_leap(_rt.leap(), _rt.rider())
	_boss.bind_hud(_rt.hud())
	_boss.defeated.connect(_on_simhika_defeated)
	_boss.inner_phase_cleared.connect(_on_simhika_inside_done)
	_boss.window_missed.connect(_restore_rider_size)
	_boss.window_missed.connect(func() -> void: _simhika_bitten = SIMHIKA_BITTEN_SHOW)
	_boss.event_bus = _bus()
	_rt.hook_boss_hints(_boss, "boss_simhika")


func _on_simhika_defeated() -> void:
	_simhika_stage = 2
	_simhika_status = ""
	_set_chase_scale(1.0)
	if _rt != null:
		_rt.show_prompt("")
	_restore_rider_size()
	_rt.play_dialogue("%s#w1" % SIMHIKA_FILE)


func _on_simhika_inside_done(_inner: int) -> void:
	_restore_rider_size()


func _restore_rider_size() -> void:
	if _rt != null and _rt.size_shift() != null:
		_rt.size_shift().force_size(SizeShift.SIZE.GIANT)


## Width of Surasa's open jaws in metres for a jaw level (1 = closed, growth + 1 = fully open).
static func jaw_width_metres(mouth: float) -> float:
	return HANUMAN_GIANT_HEIGHT * JAW_PER_STEP * mouth


## Hanuman's height in metres at a trial growth (1..MAX_GROWTH), for comparing with her jaws.
static func hanuman_height_metres(growth: int) -> float:
	if growth <= 0:
		return SizeShift.BODY_HEIGHT * SizeShift.SCALES[SizeShift.SIZE.SMALL]
	return HANUMAN_GIANT_HEIGHT * SurasaPuzzle.GROWTH_SCALES[growth - 1]


## Narration for the Simhika fight (owner 2026-11-28: "not clear what the player needs to do"). One line says what
## Simhika is doing right now, the next lists the controls that matter in this phase.
func simhika_status_key() -> String:
	if _boss == null or not is_instance_valid(_boss):
		return ""
	if _simhika_bitten > 0.0:
		return "SIM_BITTEN"
	if _boss.player_stun_left > 0.0:
		return "SIM_GRABBED"
	match _boss.phase:
		1:
			if _boss.shadow_active and _rt != null and _rt.rider() != null:
				var rider: Vector3 = _rt.rider().global_position
				var gap: Vector3 = Vector3(rider.x, 0.0, rider.z) - _boss.shadow_pos
				if gap.length() < SIMHIKA_SHADOW_WARN:
					return "SIM_SHADOW_NEAR"
			return "SIM_PHASE1"
		2:
			return "SIM_WAVE_COMING" if _boss.wave_telegraph_visible() else "SIM_PHASE2"
	if _boss.is_inside():
		return "SIM_INSIDE"
	if _boss.window_open():
		return "SIM_JAWS_OPEN"
	return "SIM_JAWS_SHUT"


func _update_simhika_prompt() -> void:
	var key: String = simhika_status_key()
	if key.is_empty() or _rt == null:
		return
	var controls: String
	if _boss.phase < 3:
		controls = ChapterFlow.text("SIM_CONTROLS_FIGHT") % [KeyGlyph.text_for(&"move_left"), KeyGlyph.text_for(&"move_right"),
			KeyGlyph.text_for(&"leap"), KeyGlyph.text_for(&"attack_light")]
	elif _boss.is_inside():
		controls = ChapterFlow.text("SIM_CONTROLS_INSIDE") % KeyGlyph.text_for(&"attack_light")
	else:
		controls = ChapterFlow.text("SIM_CONTROLS_JAWS") % KeyGlyph.text_for(&"shrink")
	var text: String = ChapterFlow.text(key) + "\n" + controls
	if text != _simhika_status:
		_simhika_status = text
		_rt.show_prompt(text)


## Narration for each moment of the Surasa trial. It describes what Surasa does, never which key to press next;
## the control strip below it lists the three verbs.
const SURASA_STATUS_KEYS: Dictionary = {
	&"opening": "SUR_OPENING",
	&"open": "SUR_OPEN",
	&"windup": "SUR_WINDUP",
	&"gulped": "SUR_GULPED",
	&"tiny": "SUR_TINY",
	&"feint": "SUR_FEINT",
	&"closed": "SUR_CLOSED",
	&"too_narrow": "SUR_TOO_NARROW",
	&"too_big": "SUR_TOO_BIG",
	&"inside": "SUR_INSIDE",
	&"spat": "SUR_SPAT",
}
## After this many failed tricks (gulps + feints + spits) the narration adds a gentle hint.
const SURASA_HINT_AFTER: int = 3


func _on_surasa_state(state: StringName) -> void:
	_surasa_status = str(SURASA_STATUS_KEYS.get(state, _surasa_status))
	if state == &"inside":
		_set_rider_dart(1.0)
	elif state == &"spat" or state == &"gulped":
		_set_rider_dart(0.0)
	_update_surasa_prompt()


func _update_surasa_prompt() -> void:
	if _rt == null or _puzzle == null or not _puzzle.is_active():
		return
	var lines: Array[String] = [ChapterFlow.text(_surasa_status)]
	var fails: int = _puzzle.gulps + _puzzle.feints + _puzzle.spits
	if fails >= SURASA_HINT_AFTER and _puzzle.phase == SurasaPuzzle.Phase.PLAYING:
		lines.append(ChapterFlow.text("SUR_HINT"))
	lines.append(ChapterFlow.text("SUR_CONTROLS") % [KeyGlyph.text_for(&"grow"), KeyGlyph.text_for(&"shrink"),
		KeyGlyph.text_for(&"interact")])
	_rt.show_prompt("\n".join(lines))


## Mouth size, the bite wind-up shudder and the chase camera follow the trial every frame.
func _update_surasa_visuals() -> void:
	if _puzzle == null:
		return
	# Owner 2026-11-27: her jaws must read against Hanuman's size. Jaw width in metres is JAW_PER_STEP x mouth, in
	# units of Hanuman's GIANT height, so fully open (growth + 1) is always a little taller than he is. Surasa's
	# body grows with her jaws so the maw still sits on her head.
	var body: float = SURASA_SCALE * (0.6 + 0.4 * _puzzle.mouth)
	if _surasa != null and is_instance_valid(_surasa):
		_surasa.scale = Vector3.ONE * body
	if _mouth != null and is_instance_valid(_mouth):
		var radius: float = jaw_width_metres(_puzzle.mouth) * 0.5 / body
		var k: float = radius / MOUTH_MESH_RADIUS
		_mouth.scale = Vector3(k, k, k)
		_mouth.position = Vector3(0.0, MOUTH_LOCAL_Y, MOUTH_LOCAL_Z - radius * 0.15)
	if _surasa != null and is_instance_valid(_surasa):
		var shake: float = _puzzle.windup_fraction()
		_surasa.rotation.z = sin(float(Time.get_ticks_msec()) * 0.03) * 0.06 * shake
	if _puzzle.is_active():
		_frame_surasa(_puzzle.growth_scale())


## 0 = Hanuman in his place, 1 = inside Surasa's jaws (the rider's model darts to her mouth and vanishes).
func _set_rider_dart(amount: float) -> void:
	if _rt == null or _rt.rider() == null:
		return
	var pivot: Node3D = _rt.rider().get_node_or_null("Pivot") as Node3D
	if pivot == null:
		return
	if amount <= 0.0 or _mouth == null or not is_instance_valid(_mouth) or not _mouth.is_inside_tree():
		pivot.position = Vector3.ZERO
		pivot.visible = true
		return
	pivot.position = _rt.rider().to_local(_mouth.global_position) * amount
	pivot.visible = amount < 1.0


## Puts the chase camera back to its flight offset (factor 1) or scales the offset.
func _set_chase_scale(factor: float) -> void:
	var chase: Camera3D = _chase_camera()
	if chase != null:
		chase.position = CHASE_BASE * factor
		chase.rotation_degrees = CHASE_ROTATION


## During the trial: a three-quarter side view that always frames both Hanuman (whole body) and Surasa's jaws, so
## the player can compare his height with how wide she has opened (owner 2026-11-27).
func _frame_surasa(_factor: float) -> void:
	var chase: Camera3D = _chase_camera()
	var rider: Node3D = _rt.rider() if _rt != null else null
	if chase == null or rider == null or _mouth == null or not is_instance_valid(_mouth) or not _mouth.is_inside_tree():
		return
	if not rider.is_inside_tree():
		return
	var tall: float = hanuman_height_metres(_puzzle.growth) if _puzzle != null else HANUMAN_GIANT_HEIGHT
	var jaw: float = jaw_width_metres(_puzzle.mouth) if _puzzle != null else 0.0
	var mouth_local: Vector3 = rider.to_local(_mouth.global_position)
	var top: float = maxf(tall, mouth_local.y + jaw * 0.5)
	var bottom: float = minf(0.0, mouth_local.y - jaw * 0.5)
	var centre: Vector3 = Vector3(mouth_local.x * 0.5, (top + bottom) * 0.5, mouth_local.z * 0.5)
	var extent: float = maxf(top - bottom, absf(mouth_local.z) + jaw * 0.5)
	var distance: float = extent * SURASA_FRAME_MARGIN / tan(deg_to_rad(chase.fov) * 0.5) * 0.5
	chase.position = centre + SURASA_CAMERA_DIR.normalized() * distance
	chase.look_at(rider.to_global(centre), Vector3.UP)


## During the Simhika fight: the same three-quarter view, framing Hanuman, Simhika and the water between them (her
## shadow pool and wave band), so the giant Hanuman never hides her (owner 2026-11-28).
func _frame_simhika() -> void:
	var chase: Camera3D = _chase_camera()
	var rider: Node3D = _rt.rider() if _rt != null else null
	if chase == null or rider == null or not rider.is_inside_tree() or not _boss.is_inside_tree():
		return
	var tall: float = HANUMAN_GIANT_HEIGHT * _rt.size_shift().get_visual_scale() / SizeShift.SCALES[SizeShift.SIZE.GIANT] \
		if _rt.size_shift() != null else HANUMAN_GIANT_HEIGHT
	var boss_local: Vector3 = rider.to_local(_boss.global_position)
	var top: float = maxf(tall, boss_local.y + SIMHIKA_FRAME_HEIGHT)
	var bottom: float = minf(0.0, boss_local.y)
	var centre: Vector3 = Vector3(boss_local.x * 0.5, (top + bottom) * 0.5, boss_local.z * 0.5)
	var extent: float = maxf(top - bottom, Vector2(boss_local.x, boss_local.z).length() + SIMHIKA_FRAME_HEIGHT * 0.5)
	var distance: float = extent * SURASA_FRAME_MARGIN / tan(deg_to_rad(chase.fov) * 0.5) * 0.5
	chase.position = centre + SIMHIKA_CAMERA_DIR.normalized() * distance
	chase.look_at(rider.to_global(centre), Vector3.UP)


func _chase_camera() -> Camera3D:
	if _rt == null or _rt.rider() == null:
		return null
	return _rt.rider().get_node_or_null("ChaseCamera") as Camera3D


func _on_puzzle_solved() -> void:
	_surasa_stage = 2
	_set_rider_dart(0.0)
	if _rt != null:
		_rt.show_prompt("")
		_rt.play_dialogue("%s#w1" % SURASA_FILE)


## A failed flight (the rail's health ran out) heals Hanuman and, between gates, restarts the flight from the last
## gate. Nothing in the game can end the run.
func _on_leap_failed() -> void:
	if _rt == null or _rt.leap() == null:
		return
	var controller: LeapController = _rt.leap()
	controller.health.heal(controller.health.max_value)
	var bus: Node = _bus()
	if bus != null:
		bus.emit_signal("vitality_changed", controller.health.value, controller.health.max_value)
	if not controller.paused_at_gate:
		var checkpoint: float = 0.0
		for gate: Dictionary in controller.gate_defs:
			var d: float = gate.get("d", 0.0) as float
			if d <= controller.distance and d > checkpoint:
				checkpoint = d
		controller.distance = checkpoint


func _process(delta: float) -> void:
	if _rt == null or not is_instance_valid(_rt):
		return
	tick_leap(delta)


## Drives the puzzle clock and reads the leap inputs. Public so tests can step it.
func tick_leap(delta: float) -> void:
	if _puzzle != null:
		_puzzle.tick(delta)
		_update_surasa_visuals()
	_tick_leap_swing(delta)
	if _boss != null and is_instance_valid(_boss) and _boss.active and not _boss.is_defeated():
		_simhika_bitten = maxf(_simhika_bitten - delta, 0.0)
		_update_simhika_prompt()
		_frame_simhika()
	if _rt == null or _rt.input_locked():
		return
	if _puzzle != null and _puzzle.is_active():
		if Input.is_action_just_pressed(&"grow"):
			_puzzle.on_grow()
		if Input.is_action_just_pressed(&"shrink"):
			_puzzle.on_shrink()
		if Input.is_action_just_pressed(&"interact"):
			_puzzle.on_dart()
	elif _boss != null and is_instance_valid(_boss) and _boss.active:
		if Input.is_action_just_pressed(&"shrink") and _rt.size_shift() != null:
			_rt.size_shift().shrink()
		if Input.is_action_just_pressed(&"attack_light"):
			leap_attack(LEAP_LIGHT_DAMAGE, false)
		if Input.is_action_pressed(&"attack_light"):
			_heavy_hold += delta
			if _heavy_hold >= LEAP_HEAVY_HOLD:
				_heavy_hold = 0.0
				leap_attack(LEAP_HEAVY_DAMAGE, true)
		else:
			_heavy_hold = 0.0


## Plays a gada swing on the flying Hanuman: wind-up, blow, then back to the flight pose. Every strike press swings,
## hit or miss, so the player always sees the input (owner 2026-11-28).
func start_leap_swing(heavy: bool) -> void:
	var model: HanumanModel = _rider_model()
	if model == null:
		return
	_swing_time = 0.0
	_swing_wind = LEAP_SWING_WIND_HEAVY if heavy else LEAP_SWING_WIND
	model.set_pose(&"attack_wind")
	SoundPlayer.cue(model, &"gada_swing_heavy" if heavy else &"gada_swing_light")


## The pose the flying Hanuman shows right now (for tests).
func leap_rider_pose() -> StringName:
	var model: HanumanModel = _rider_model()
	return model.current_pose() if model != null else &""


func _tick_leap_swing(delta: float) -> void:
	if _swing_time < 0.0:
		return
	var model: HanumanModel = _rider_model()
	if model == null:
		_swing_time = -1.0
		return
	var before: float = _swing_time
	_swing_time += delta
	if before < _swing_wind and _swing_time >= _swing_wind:
		model.set_pose(&"attack_strike")
	if _swing_time >= _swing_wind + LEAP_SWING_HOLD:
		_swing_time = -1.0
		model.set_pose(LevelRuntime.FLIGHT_POSE)


func _rider_model() -> HanumanModel:
	if _rt == null or _rt.rider() == null:
		return null
	var pivot: Node = _rt.rider().get_node_or_null("Pivot")
	if pivot == null:
		return null
	for child: Node in pivot.get_children():
		if child is HanumanModel:
			return child as HanumanModel
	return null


## Hanuman strikes at Simhika while flying: lands only within range and while she is vulnerable.
func leap_attack(amount: int, heavy: bool) -> bool:
	start_leap_swing(heavy)
	if _boss == null or not is_instance_valid(_boss) or _rt == null or _rt.rider() == null:
		return false
	var flat: Vector3 = _boss.global_position - _rt.rider().global_position
	flat.y = 0.0
	if flat.length() > LEAP_ATTACK_RANGE and not _boss.is_inside():
		return false
	if not _boss.is_vulnerable():
		return false
	_boss.apply_hit(amount, Vector3.ZERO, heavy)
	return true


# ---------------------------------------------------------------- autoloads

func _bus() -> Node:
	if event_bus != null:
		return event_bus
	return _autoload("EventBus")


func _state() -> Node:
	if game_state != null:
		return game_state
	return _autoload("GameState")


func _autoload(autoload_name: String) -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(autoload_name)
