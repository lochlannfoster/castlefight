shader_type canvas_item;

// Fog of War shader for Castle Fight
// Simple implementation that takes two textures (one for each team)

uniform sampler2D team_a_fog;  // Texture for Team A's fog of war
uniform sampler2D team_b_fog;  // Texture for Team B's fog of war
uniform bool use_team_a = true;  // Which team's fog to display (set by the renderer)

void fragment() {
    // Get the fog value from the appropriate texture
    vec4 fog_value;
    if (use_team_a) {
        fog_value = texture(team_a_fog, UV);
    } else {
        fog_value = texture(team_b_fog, UV);
    }
    
    // Output the fog color
    // Alpha of 0 = fully visible
    // Alpha of 1 = completely hidden (black)
    COLOR = vec4(0.0, 0.0, 0.0, fog_value.a);
}