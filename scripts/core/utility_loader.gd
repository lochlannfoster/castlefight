# Resource and Utility Loader Helper
# Path: scripts/core/utility_loader.gd
extends Reference

# Load a resource with a fallback option
static func load_resource_with_fallback(primary_path: String, fallback_path: String, error_message: String = "") -> Resource:
    var resource = load(primary_path)
    
    if resource:
        return resource
    
    # Try fallback path
    resource = load(fallback_path)
    
    if resource:
        push_warning("Using fallback resource: " + fallback_path)
        return resource
    
    # Both primary and fallback failed
    var error_text = "Failed to load resource: " + primary_path + " or fallback: " + fallback_path
    if !error_message.empty():
        error_text += " - " + error_message
        
    push_error(error_text)
    
    return null