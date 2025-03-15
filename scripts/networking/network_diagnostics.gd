# Network Diagnostics Utility - Tools for debugging network issues
# Path: scripts/networking/network_diagnostics.gd
extends Node

# Reference to NetworkManager
var network_manager

# Statistics tracking
var connection_attempts = 0
var successful_connections = 0
var failed_connections = 0
var disconnections = 0
var packets_sent = 0
var packets_received = 0
var latency_samples = []
var current_latency = 0
var peak_latency = 0
var packet_loss_percentage = 0

# Timing variables for diagnostics
var last_ping_time = 0
var diagnostic_start_time = 0
var diagnostic_active = false

# Signals
signal diagnostic_update(stats)
signal diagnostic_complete(report)

func _ready():
    # Find NetworkManager reference
    network_manager = get_node_or_null("/root/NetworkManager")
    if not network_manager:
        network_manager = get_node_or_null("/root/GameManager/NetworkManager")
    
    if network_manager:
        # Connect to network manager signals
        network_manager.connect("server_started", self, "_on_server_started")
        network_manager.connect("client_connected", self, "_on_client_connected")
        network_manager.connect("client_disconnected", self, "_on_client_disconnected")
        network_manager.connect("connection_succeeded", self, "_on_connection_succeeded")
        network_manager.connect("connection_failed", self, "_on_connection_failed")
        network_manager.connect("ping_updated", self, "_on_ping_updated")
    
    print("Network diagnostics utility initialized")

# Start gathering diagnostic information
func start_diagnostics() -> void:
    if !network_manager:
        print("Cannot start diagnostics: NetworkManager not found")
        return
    
    # Reset statistics
    reset_stats()
    
    # Mark start time
    diagnostic_start_time = OS.get_ticks_msec()
    diagnostic_active = true
    
    # Start ping test if connected
    if network_manager.connection_state == network_manager.ConnectionState.CONNECTED or \
       network_manager.connection_state == network_manager.ConnectionState.SERVER_RUNNING:
        _start_ping_test()
    
    print("Network diagnostics started")

# Stop gathering diagnostic information and generate report
func stop_diagnostics() -> Dictionary:
    diagnostic_active = false
    
    # Generate diagnostic report
    var report = generate_diagnostic_report()
    
    # Emit signal with report
    emit_signal("diagnostic_complete", report)
    
    print("Network diagnostics stopped")
    return report

# Reset all statistics
func reset_stats() -> void:
    connection_attempts = 0
    successful_connections = 0
    failed_connections = 0
    disconnections = 0
    packets_sent = 0
    packets_received = 0
    latency_samples.clear()
    current_latency = 0
    peak_latency = 0
    packet_loss_percentage = 0

# Start a ping test to measure latency
func _start_ping_test() -> void:
    # Send pings to measure latency
    if network_manager and network_manager.network:
        last_ping_time = OS.get_ticks_msec()
        
        # If we're the server, ping all clients
        if network_manager.is_server:
            for player_id in network_manager.player_info.keys():
                if player_id != 1:  # Skip server (ID 1)
                    _send_ping_to_client(player_id)
        else:
            # If we're a client, ping the server
            _send_ping_to_server()

# Send ping to a specific client
func _send_ping_to_client(client_id: int) -> void:
    last_ping_time = OS.get_ticks_msec()
    network_manager.rpc_id(client_id, "_diagnostic_ping", last_ping_time)
    packets_sent += 1

# Send ping to server
func _send_ping_to_server() -> void:
    last_ping_time = OS.get_ticks_msec()
    network_manager.rpc_id(1, "_diagnostic_ping", last_ping_time)
    packets_sent += 1

# Remote function to receive ping and send pong response
remote func _diagnostic_ping(timestamp: int) -> void:
    var sender_id = get_tree().get_rpc_sender_id()
    
    # Send pong response
    network_manager.rpc_id(sender_id, "_diagnostic_pong", timestamp)
    packets_received += 1
    packets_sent += 1

# Remote function to receive pong response and calculate latency
remote func _diagnostic_pong(timestamp: int) -> void:
    var current_time = OS.get_ticks_msec()
    var latency = current_time - timestamp
    
    # Update latency statistics
    current_latency = latency
    latency_samples.append(latency)
    
    if latency > peak_latency:
        peak_latency = latency
    
    packets_received += 1
    
    # Calculate packet loss based on sent vs received
    if packets_sent > 0:
        packet_loss_percentage = (1.0 - (float(packets_received) / float(packets_sent))) * 100.0
    
    # Emit update signal
    emit_signal("diagnostic_update", get_current_stats())
    
    # Continue ping test if diagnostics still active
    if diagnostic_active:
        yield(get_tree().create_timer(1.0), "timeout")
        _start_ping_test()

# Generate a comprehensive diagnostic report
func generate_diagnostic_report() -> Dictionary:
    var report = {
        "timestamp": OS.get_datetime(),
        "duration_ms": OS.get_ticks_msec() - diagnostic_start_time,
        "network_status": {
            "connected": network_manager && network_manager.network != null,
            "is_server": network_manager && network_manager.is_server,
            "connection_state": _get_connection_state_string(),
            "game_phase": _get_game_phase_string()
        },
        "connection_stats": {
            "connection_attempts": connection_attempts,
            "successful_connections": successful_connections,
            "failed_connections": failed_connections,
            "disconnections": disconnections
        },
        "performance_stats": {
            "packets_sent": packets_sent,
            "packets_received": packets_received,
            "packet_loss_percentage": packet_loss_percentage,
            "current_latency_ms": current_latency,
            "peak_latency_ms": peak_latency,
            "average_latency_ms": _calculate_average_latency()
        },
        "player_info": _get_player_info(),
        "recommendations": _generate_recommendations()
    }
    
    # Save report to file
    _save_report_to_file(report)
    
    return report

# Get current statistics for updates
func get_current_stats() -> Dictionary:
    return {
        "connected": network_manager && network_manager.network != null,
        "latency_ms": current_latency,
        "packet_loss_percentage": packet_loss_percentage,
        "packets_sent": packets_sent,
        "packets_received": packets_received
    }

# Calculate average latency from samples
func _calculate_average_latency() -> float:
    if latency_samples.empty():
        return 0.0
    
    var sum = 0.0
    for latency in latency_samples:
        sum += latency
    
    return sum / latency_samples.size()

# Get string representation of connection state
func _get_connection_state_string() -> String:
    if !network_manager:
        return "Unknown"
    
    match network_manager.connection_state:
        network_manager.ConnectionState.DISCONNECTED:
            return "Disconnected"
        network_manager.ConnectionState.CONNECTING:
            return "Connecting"
        network_manager.ConnectionState.CONNECTED:
            return "Connected"
        network_manager.ConnectionState.SERVER_RUNNING:
            return "Server Running"
        _:
            return "Unknown"

# Get string representation of game phase
func _get_game_phase_string() -> String:
    if !network_manager:
        return "Unknown"
    
    match network_manager.game_phase:
        network_manager.GamePhase.LOBBY:
            return "Lobby"
        network_manager.GamePhase.PREGAME:
            return "Pregame"
        network_manager.GamePhase.LOADING:
            return "Loading"
        network_manager.GamePhase.ACTIVE:
            return "Active"
        network_manager.GamePhase.PAUSED:
            return "Paused"
        network_manager.GamePhase.ENDED:
            return "Ended"
        _:
            return "Unknown"

# Get player information
func _get_player_info() -> Dictionary:
    var info = {}
    
    if network_manager:
        for player_id in network_manager.player_info.keys():
            var player_data = network_manager.player_info[player_id]
            
            info[str(player_id)] = {
                "name": player_data.get("name", "Unknown"),
                "team": player_data.get("team", -1),
                "is_host": player_data.get("is_host", false),
                "ping_ms": player_data.get("ping", -1)
            }
    
    return info

# Generate recommendations based on diagnostic results
func _generate_recommendations() -> Array:
    var recommendations = []
    
    # Connection recommendations
    if !network_manager || !network_manager.network:
        recommendations.append("Not connected to any server.")
    
    # Latency recommendations
    var avg_latency = _calculate_average_latency()
    if avg_latency > 200:
        recommendations.append("High latency detected (>200ms). Consider connecting to a server closer to your location.")
    elif avg_latency > 100:
        recommendations.append("Moderate latency detected (>100ms). This may cause some gameplay interruptions.")
    
    # Packet loss recommendations
    if packet_loss_percentage > 10.0:
        recommendations.append("High packet loss detected (>10%). Check your network connection stability.")
    elif packet_loss_percentage > 2.0:
        recommendations.append("Moderate packet loss detected (>2%). This may cause some gameplay interruptions.")
    
    # General recommendations if no specific issues
    if recommendations.empty():
        recommendations.append("Network performance appears to be good.")
    
    return recommendations

# Save diagnostic report to file
func _save_report_to_file(report: Dictionary) -> void:
    var dir = Directory.new()
    var path = "user://network_diagnostics"
    
    # Create directory if it doesn't exist
    if !dir.dir_exists(path):
        dir.make_dir_recursive(path)
    
    # Generate filename with timestamp
    var datetime = OS.get_datetime()
    var filename = "%s/network_report_%d-%02d-%02d_%02d-%02d-%02d.json" % [
        path,
        datetime.year,
        datetime.month,
        datetime.day,
        datetime.hour,
        datetime.minute,
        datetime.second
    ]
    
    # Save file
    var file = File.new()
    if file.open(filename, File.WRITE) == OK:
        file.store_string(JSON.print(report, "  "))
        file.close()
        print("Network diagnostic report saved to: " + filename)
    else:
        push_error("Failed to save network diagnostic report")

# Signal handlers
func _on_server_started() -> void:
    if diagnostic_active:
        connection_attempts += 1
        successful_connections += 1

func _on_client_connected(_player_id: int) -> void:
    if diagnostic_active:
        connection_attempts += 1
        successful_connections += 1

func _on_client_disconnected(_player_id: int) -> void:
    if diagnostic_active:
        disconnections += 1

func _on_connection_succeeded() -> void:
    if diagnostic_active:
        connection_attempts += 1
        successful_connections += 1

func _on_connection_failed() -> void:
    if diagnostic_active:
        connection_attempts += 1
        failed_connections += 1

func _on_ping_updated(_player_id: int, ping: int) -> void:
    if diagnostic_active:
        current_latency = ping
        latency_samples.append(ping)
        
        if ping > peak_latency:
            peak_latency = ping
        
        # Emit update signal
        emit_signal("diagnostic_update", get_current_stats())