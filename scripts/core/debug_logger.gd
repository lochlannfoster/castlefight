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
  if log_file:
    log_file.close()

func log(message, level = LogLevel.INFO, context = ""):
  if level > current_log_level:
    return
    
  var prefix = ""
  match level:
    LogLevel.ERROR: prefix = "[ERROR]"
    LogLevel.WARNING: prefix = "[WARNING]"
    LogLevel.INFO: prefix = "[INFO]"
    LogLevel.DEBUG: prefix = "[DEBUG]"
    LogLevel.VERBOSE: prefix = "[VERBOSE]"
  
  var context_str = ""
  if context != "":
    context_str = "[" + context + "] "
  
  var final_message = prefix + " " + context_str + message
  print(final_message)
  
  if log_to_file:
    log_file = File.new()
    log_file.open(log_file_path, File.APPEND)
    log_file.store_string(final_message + "\n")
    log_file.close()

func error(message, context = ""):
  log(message, LogLevel.ERROR, context)

func warning(message, context = ""):
  log(message, LogLevel.WARNING, context)

func info(message, context = ""):
  log(message, LogLevel.INFO, context)

func debug(message, context = ""):
  log(message, LogLevel.DEBUG, context)

func verbose(message, context = ""):
  log(message, LogLevel.VERBOSE, context)