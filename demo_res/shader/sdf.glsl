// Based on the shader in this LibGDX + Hiero + SDF tutorial:
// https://libgdx.com/wiki/graphics/2d/fonts/distance-field-fonts

uniform float smoothing;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {

    float dist = Texel(tex, texture_coords).a;
    float alpha = smoothstep(0.5 - smoothing, 0.5 + smoothing, dist);

    color.a *= alpha;
    return color;
}

