#version 140

in mediump vec3 var_normal;
in lowp vec4 var_color;
out lowp vec4 out_fragColor;

uniform toon_fs
{
    lowp vec4 tint;
    lowp vec4 skin_tint;
    lowp vec4 damage_flash;
};

void main()
{
    // View-space key light is in front of the camera, slightly left.
    mediump float lit = max(dot(normalize(var_normal), normalize(vec3(-0.35, 0.18, 0.92))), 0.0);
    lowp vec3 albedo = mix(tint.rgb, skin_tint.rgb, skin_tint.a) * var_color.rgb;
    lowp vec3 color = albedo * mix(0.62, 1.0, lit);
    out_fragColor = vec4(mix(color, damage_flash.rgb, damage_flash.a), var_color.a * tint.a);
}
