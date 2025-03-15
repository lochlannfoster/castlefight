static func load_resource_with_fallback(primary_path: String, fallback_path: String, error_message: String = ""):
    var resource = load(primary_path)
    
    if resource:
        return resource
    
    # Try fallback path
    resource = load(fallback_path)
    
    if resource:
        push_warning("Using fallback resource: " + fallback_path)
        return resource
    
    # Both primary and fallback failed
    push_error("Failed to load resource: " + primary_path + 
               " or fallback: " + fallback_path + 
               (error_message.empty() ? "" : " - " + error_message))
    
    return null