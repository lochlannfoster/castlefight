extends Node

signal player_added(player_id, team)
signal player_removed(player_id)
signal team_changed(player_id, old_team, new_team)

var players: Dictionary = {} # player_id -> player data
var team_players: Dictionary = {
    0: [], # Team A player IDs
    1: [] # Team B player IDs
}

func add_player(player_id, player_name: String, team: int) -> bool:
    # Ensure team is valid
    if team < 0 or team > 1:
        team = 0 # Default to Team A if invalid
        print("Warning: Invalid team provided, defaulting to Team A (0)")
    
    # Initialize team arrays if needed
    if not team_players.has(0):
        team_players[0] = []
    if not team_players.has(1):
        team_players[1] = []
    
    # Create player data
    var player_data = {
        "id": player_id,
        "name": player_name,
        "team": team,
        "worker": null,
        "ready": false,
        "ping": 0
    }
    
    # Add to player tracking
    players[player_id] = player_data
    team_players[team].append(player_id)
    
    emit_signal("player_added", player_id, team)
    return true

func remove_player(player_id) -> void:
    if not players.has(player_id):
        return
    
    var team = players[player_id].team
    
    # Remove from team
    if team_players.has(team):
        team_players[team].erase(player_id)
    
    # Remove player data
    players.erase(player_id)
    
    emit_signal("player_removed", player_id)

func change_team(player_id: int, new_team: int) -> bool:
    if not players.has(player_id) or new_team < 0 or new_team > 1:
        return false
    
    var current_team = players[player_id].team
    
    # No change needed
    if current_team == new_team:
        return true
    
    # Remove from current team
    if team_players.has(current_team):
        team_players[current_team].erase(player_id)
    
    # Add to new team
    if not team_players.has(new_team):
        team_players[new_team] = []
    
    team_players[new_team].append(player_id)
    
    # Update player data
    players[player_id].team = new_team
    
    emit_signal("team_changed", player_id, current_team, new_team)
    return true

func get_team(player_id) -> int:
    if players.has(player_id):
        return players[player_id].team
    return -1

func set_player_ready(player_id: int, is_ready: bool) -> void:
    if players.has(player_id):
        players[player_id].ready = is_ready

func is_player_ready(player_id: int) -> bool:
    if players.has(player_id):
        return players[player_id].get("ready", false)
    return false

func are_all_players_ready() -> bool:
    for player_id in players:
        if not is_player_ready(player_id):
            return false
    return true

func get_players_in_team(team: int) -> Array:
    if team_players.has(team):
        return team_players[team]
    return []

func clear() -> void:
    players.clear()
    team_players = {
        0: [],
        1: []
    }