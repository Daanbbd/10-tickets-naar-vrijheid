extends Node
## Globale event bus. UITSLUITEND signal-declaraties: geen state, geen logica.
## Alleen voor events die scene- of CanvasLayer-grenzen oversteken.

# --- Sessie / flow ---
signal character_selected(character_id: StringName)
signal game_started()
signal game_finished(escaped: bool)

# --- Tickets ---
signal ticket_state_changed(ticket_id: StringName, state: GameEnums.TicketState)
## Je bent een ticket tegengekomen: het staat nu in je inventaris.
signal ticket_discovered(ticket_id: StringName)
## Je hebt zelf gekozen waar je aan werkt. Leeg = keuze losgelaten.
signal ticket_pinned(ticket_id: StringName)
signal ticket_completed(ticket_id: StringName, result: MinigameResult)
signal all_tickets_done()

# --- State ---
signal flag_changed(flag: StringName, value: bool)
signal item_added(item_id: StringName, new_count: int)
signal item_removed(item_id: StringName, new_count: int)
## Er zijn minuten op de dag van vandaag geboekt. De HUD rolt hierop de klok
## vooruit; `total` is het nieuwe totaal, zodat een luisteraar niets hoeft op
## te tellen.
signal time_booked(minutes: int, reason: StringName, total: int)

## De Klant meldt zich. Ze is nooit een sprite en staat nooit in het kantoor:
## ze bestaat als telefoonscherm, en dit is het enige signaal dat haar oproept.
signal klant_bericht(bericht_id: StringName)

# --- Dialoog ---
signal dialogue_started(dialogue_id: StringName, speaker_id: StringName)
signal dialogue_finished(dialogue_id: StringName, outcome: StringName)

# --- Minigames ---
signal minigame_started(minigame_id: StringName)
signal minigame_finished(minigame_id: StringName, result: MinigameResult)

# --- Wereld ---
signal world_changes_requested(changes: Array)
signal camera_focus_requested(world_id: StringName, hold_sec: float)
signal follower_joined(npc_id: StringName)
signal follower_released(npc_id: StringName)

# --- UI / input ---
signal input_lock_changed(locked: bool)
signal interaction_prompt_changed(text: String, shown: bool, world_id: StringName, verb: String)
signal toast_requested(text: String, icon_id: StringName)
signal zone_entered(zone_id: StringName, zone_name: String)
signal audio_cue_requested(cue_id: StringName)
signal hint_requested()
