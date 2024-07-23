#include <flutter/runtime_effect.glsl>

uniform vec2 NDISize;
uniform vec2 drawSize;
uniform sampler2D NDITexture;

out vec4 fragColor;

void main() {
    vec2 drawCoord = FlutterFragCoord().xy;
    vec2 uv = drawCoord / drawSize;
    vec2 ndiCoordFloat = uv * NDISize;
    float ndiCoordX = sign(ndiCoordFloat.x)*float(int(abs(ndiCoordFloat.x)+0.5));
    float ndiCoordY = sign(ndiCoordFloat.y)*float(int(abs(ndiCoordFloat.y)+0.5));
    vec2 ndiUv = vec2(ndiCoordX, ndiCoordY) / NDISize;
    vec4 sampled = texture(NDITexture, ndiUv);

    vec4 color;
    color.r = sampled.b;
    color.g = sampled.g;
    color.b = sampled.r;
    color.a = sampled.a;

    // color.r = 0.0;
    // color.g = ndiUv.y;
    // color.b = ndiUv.x;
    // color.a = 1.0;

    fragColor = color;
}
