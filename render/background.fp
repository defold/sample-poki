#version 140

in mediump vec2 var_screen_position;
out lowp vec4 out_fragColor;

void main()
{
    // A broad screen-space glow brightens the play area.
    // Deep navy edges blend into the surrounding space.
    // The slight vertical tint prevents the background from looking like a flat circular vignette.
    mediump vec2 glow_position = var_screen_position - vec2(0.0, 0.08);
    mediump float distance_from_glow = length(glow_position * vec2(0.78, 1.0));
    mediump float glow = 1.0 - smoothstep(0.05, 1.38, distance_from_glow);
    mediump float upper_tint = smoothstep(-0.75, 0.85, var_screen_position.y) * glow;

    lowp vec3 edge_color = vec3(0.003, 0.005, 0.020);
    lowp vec3 center_color = vec3(0.018, 0.048, 0.115);
    lowp vec3 color = mix(edge_color, center_color, glow);
    color += vec3(0.000, 0.007, 0.016) * upper_tint;

    out_fragColor = vec4(color, 1.0);
}
