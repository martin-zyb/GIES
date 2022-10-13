#version 120

const int R8 = 0;
const int colortex4Format = R8;

const vec4 LF1COLOR = vec4(1.0, 1.0, 1.0, 0.1);
const vec4 LF2COLOR = vec4(0.42, 0.0, 1.0, 0.1);
const vec4 LF3COLOR = vec4(0.0, 1.0, 0.0, 0.1);
const vec4 LF4COLOR = vec4(1.0, 0.0, 0.0, 0.1);

uniform sampler2D colortex1;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform float near;
uniform float far;
uniform mat4 gbufferProjection;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

varying vec4 texcoord;
varying float sunVisibility;
varying vec2 lf1Pos;
varying vec2 lf2Pos;
varying vec2 lf3Pos;
varying vec2 lf4Pos;

#define MANHATTAN_DISTANCE(DELTA) abs(DELTA.x)+abs(DELTA.y)

#define LENS_FLARE(COLOR, UV, LFPOS, LFSIZE, LFCOLOR) { \
                vec2 delta = UV - LFPOS; delta.x *= aspectRatio; \
                if(MANHATTAN_DISTANCE(delta) < LFSIZE * 2.0) { \
                    float d = max(LFSIZE - sqrt(dot(delta, delta)), 0.0); \
                    COLOR += LFCOLOR.rgb * LFCOLOR.a * smoothstep(0.0, LFSIZE, d) * sunVisibility;\
                } }

#define LF1SIZE 0.1
#define LF2SIZE 0.15
#define LF3SIZE 0.25
#define LF4SIZE 0.25

vec3 lensFlare(vec3 color, vec2 uv) {
    if(sunVisibility <= 0.0)
        return color;
    LENS_FLARE(color, uv, lf1Pos, LF1SIZE, LF1COLOR);
    LENS_FLARE(color, uv, lf2Pos, LF2SIZE, LF2COLOR);
    LENS_FLARE(color, uv, lf3Pos, LF3SIZE, LF3COLOR);
    LENS_FLARE(color, uv, lf4Pos, LF4SIZE, LF4COLOR);
    return color;
}

vec3 vignette(vec3 color)
{
    float dist = distance(texcoord.st, vec2(0.5f));
    dist = clamp(dist * 1.7 - 0.65, 0.0, 1.0);
    dist = smoothstep(0.0, 1.0, dist);
    return color.rgb * (1.0 - dist);
}

void main()
{
    vec3 attrs =  texture2D(colortex4, texcoord.st).rgb;
    float depth = texture2D(depthtex0, texcoord.st).r;
    vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
    viewPosition /= viewPosition.w;
    float attr = attrs.r * 255.0;
    vec3 color =  texture2D(colortex1, texcoord.st).rgb;
    color = vignette(color);
    color = lensFlare(color, texcoord.st);
    gl_FragColor = vec4(color, 1.0);
}