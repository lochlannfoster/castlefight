# scripts/core/debug_logger.gd
extends Node

enum LogLevel {
  ERROR = 0,
  WARNING = 1,
  INFO = 2,
  DEBUG = 3,
  VERBOSE = 4
}

var current_log_level = LogLevel.DEBUG
var log_to_file = true
var log_file_path = "user://debug_log.txt"
var log_file = null

func _ready():
  if log_to_file:
    log_file = File.new()
    log_file.open(log_file_path, File.WRITE)
    log_file.store_string("=== Debug Log Started at " + str(OS.get_datetime()) + " ===\n")
    log_file.close()

func _exit_tree():
  if log_file and log_file.is_open():
    log_file.close()

# Core logging implementation - no longer calls log()
func _write_log_entry(message: String, level_prefix: String, context: String = "") -> void:
  if context != "":
    message = "[" + context + "] " + message
  
  var final_message = level_prefix + " " + message
  print(final_message)
  
  if log_to_file:
    log_file = File.new()
    if log_file.open(log_file_path, File.READ_WRITE) == OK:
      log_file.seek_end()
      log_file.store_string(final_message + "\n")
      log_file.close()

# Helper functions that directly implement logging without calling log()
func error(message: String, context: String = "") -> void:
  if current_log_level >= LogLevel.ERROR:
    _write_log_entry(message, "[ERROR]", context)

func warning(message: String, context: String = "") -> void:
  if current_log_level >= LogLevel.WARNING:
    _write_log_entry(message, "[WARNING]", context)

func info(message: String, context: String = "") -> void:
  if current_log_level >= LogLevel.INFO:
    _write_log_entry(message, "[INFO]", context)

func debug(message: String, context: String = "") -> void:
  if current_log_level >= LogLevel.DEBUG:
    _write_log_entry(message, "[DEBUG]", context)

func verbose(message: String, context: String = "") -> void:
  if current_log_level >= LogLevel.VERBOSE:
    _write_log_entry(message, "[VERBOSE]", context)