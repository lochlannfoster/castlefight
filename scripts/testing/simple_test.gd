# Simple testing framework replacement for GUT
extends Node

var tests_run = 0
var tests_passed = 0
var tests_failed = 0
var current_test = ""

func _ready():
    print("Simple Test Framework initialized")

func run_tests():
    print("=== Running Tests ===")
    tests_run = 0
    tests_passed = 0
    tests_failed = 0
    
    # Override this in child classes
    pass
    
    print("=== Tests Complete ===")
    print("Ran: ", tests_run, " Passed: ", tests_passed, " Failed: ", tests_failed)

func assert_true(condition, message=""):
    tests_run += 1
    if condition:
        tests_passed += 1
        print("✓ ", current_test, ": ", message)
    else:
        tests_failed += 1
        print("✗ ", current_test, ": ", message)

func assert_false(condition, message=""):
    assert_true(!condition, message)

func assert_eq(a, b, message=""):
    assert_true(a == b, message + " (Expected " + str(b) + ", got " + str(a) + ")")

# Add more assertions as needed