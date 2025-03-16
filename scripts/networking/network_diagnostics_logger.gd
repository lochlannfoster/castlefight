# scripts/networking/network_diagnostics_logger.gd
extends Node

# This script connects your network diagnostics system to the unified logger

var network_diagnostics
var logger
var last_log_time = 0
var log_interval = 10.0 # Log network stats every 10 seconds

func _ready():
    # Get references
    network_diagnostics = get_node_or_null("/root/NetworkDiagnostics")
    logger = get_node_or_null("/root/UnifiedLogger")
    
    if network_diagnostics and logger:
        # Connect to network diagnostic signals
        network_diagnostics.connect("diagnostic_update", self, "_on_diagnostic_update")
        network_diagnostics.connect("diagnostic_complete", self, "_on_diagnostic_complete")
        
        logger.info("Network diagnostics logger initialized", "Network")
    else:
        push_warning("Network diagnostics or logger not found")

func _process(delta):
    # Periodic logging of network statistics
    last_log_time += delta
    
    if last_log_time >= log_interval and network_diagnostics:
        last_log_time = 0
        
        # Get current network stats
        var stats = network_diagnostics.get_current_stats()
        
        # Log the stats
        _log_network_stats(stats)

func _on_diagnostic_update(stats):
    # Called when diagnostic stats are updated
    # Only log on our own interval to avoid spamming
    pass

func _on_diagnostic_complete(report):
    # Log the complete diagnostic report
    if logger:
        logger.info("Network diagnostic complete", "Network")
        
        var latency = report.performance_stats.average_latency_ms
        var packet_loss = report.performance_stats.packet_loss_percentage
        
        logger.info("Network latency: %.2f ms, Packet loss: %.2f%%", "Network", [latency, packet_loss])
        
        # Log any recommendations
        for recommendation in report.recommendations:
            logger.warning("Network recommendation: " + recommendation, "Network")

func _log_network_stats(stats):
    if not logger:
        return
        
    if stats.connected:
        logger.debug("Network stats - Latency: %d ms, Packet loss: %.2f%%, Packets sent: %d, Packets received: %d" % [
            stats.latency_ms,
            stats.packet_loss_percentage,
            stats.packets_sent,
            stats.packets_received
        ], "Network")
    else:
        logger.warning("Network disconnected", "Network")