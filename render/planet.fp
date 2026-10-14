#version 140

in highp vec3 var_normal;
#ifdef EDITOR
in highp vec3 var_view_center;
#else
flat in highp vec3 var_view_center;
#endif
in mediump vec3 var_local;
#ifdef EDITOR
in lowp vec4 var_tint;
in mediump vec4 var_bands;
#else
flat in lowp vec4 var_tint;
flat in mediump vec4 var_bands;
#endif
out lowp vec4 out_fragColor;

void main()
{
    highp vec3 toward_camera = normalize(-var_view_center);
    highp vec3 up_ref = abs(toward_camera.y) > 0.94 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    highp vec3 right = normalize(cross(up_ref, toward_camera));
    highp vec3 up = cross(toward_camera, right);
    highp vec3 light = normalize(-0.50 * right + 0.18 * up + 0.88 * toward_camera);
    highp vec3 surface_normal = var_normal;
    surface_normal *= inversesqrt(max(dot(surface_normal, surface_normal), 1e-8));
    highp float lit = clamp(dot(surface_normal, light), 0.0, 1.0);

    // Belts around local X.
    // Cartesian only, so the sphere has no longitude seam.
    // var_bands.x is stripe frequency (higher = thinner belts), instance-stepped.
    mediump vec3 dir = normalize(var_local);
    mediump float lat = dir.x;
    mediump float swirl = var_bands.y * dir.y;
    mediump float wave = lat * var_bands.x + swirl + var_bands.z;
    mediump float belt = 0.5 + 0.5 * sin(wave * 6.28318);
    mediump float fine = 0.5 + 0.5 * sin(wave * 12.5664 + var_bands.w * dir.z);
    mediump float poles = smoothstep(0.55, 0.92, abs(lat));
    lowp vec3 light_band = mix(var_tint.rgb, vec3(1.0, 0.93, 0.78), 0.10);
    lowp vec3 dark_band = var_tint.rgb * 0.78;
    lowp vec3 albedo = mix(dark_band, light_band, mix(belt, fine, 0.18));
    albedo = mix(albedo, var_tint.rgb * 0.88, poles);

    lowp vec3 color = albedo * mix(0.62, 1.0, lit);
    out_fragColor = vec4(color, var_tint.a);
}
