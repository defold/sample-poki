#version 140

in lowp vec4 var_color;
out lowp vec4 out_fragColor;

uniform mesh_fs
{
    lowp vec4 tint;
};

void main()
{
    out_fragColor = var_color * tint;
}
