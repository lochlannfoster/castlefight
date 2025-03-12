# Configure GUT testing framework
extends "res://addons/gut/gut.gd"

func configure():
    # Global settings for GUT
    gutconfig.log_level = gut.LOG_LEVEL_ALL
    gutconfig.print_orphans = true
    gutconfig.unit_test_name = ''  # Leave blank to run all tests

    # Optional: Configure directories for test discovery
    gutconfig.test_directories = ['res://tests']
    
    # Optional: Configure script prefix/suffix for test scripts
    gutconfig.test_script_prefix = 'test_'
    gutconfig.test_script_suffix = ''