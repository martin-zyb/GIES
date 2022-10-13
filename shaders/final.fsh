#version 120

const int R8 = 0;
const int colortex4Format = R8;

const vec4 LF1COLOR = vec4(1.0, 1.0, 1.0, 0.1);
const vec4 LF2COLOR = vec4(0.42, 0.0, 1.0, 0.1);
const vec4 LF3COLOR = vec4(0.0, 1.0, 0.0, 0.1);
const vec4 LF4COLOR = vec4(1.0, 0.0, 0.0, 0.1);

const float centerDepthHalflife = 0.5;

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
uniform float centerDepthSmooth;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

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

#define DOF_NEARVIEWBLUR            //TODO  :  Remove or comment out "DOF_ NEARVIEWBLUR" will turn off close-up blur.
#define DOF_FADE_RANGE 0.15
#define DOF_CLEAR_RADIUS 0.2

#define MOTIONBLUR_THRESHOLD 0.01
#define MOTIONBLUR_MAX 0.18
#define MOTIONBLUR_STRENGTH 0.45
#define MOTIONBLUR_SAMPLE 4

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

vec3 dof(vec3 color, vec2 uv, float depth) {
    float linearFragDepth = linearizeDepth(depth);
    float linearCenterDepth = linearizeDepth(centerDepthSmooth);
    float delta = linearFragDepth - linearCenterDepth;
    #ifdef DOF_NEARVIEWBLUR
    float fade = smoothstep(0.0, DOF_FADE_RANGE, clamp(abs(delta) - DOF_CLEAR_RADIUS, 0.0, DOF_FADE_RANGE));
    #else
    float fade = smoothstep(0.0, DOF_FADE_RANGE, clamp(delta - DOF_CLEAR_RADIUS, 0.0, DOF_FADE_RANGE));
    #endif
    if(fade < 0.001)
        return color;
    vec2 offset = vec2(1.33333 * aspectRatio / viewWidth, 1.33333 / viewHeight);
    vec3 blurColor = vec3(0.0);
    //0.12456 0.10381 0.12456
    //0.10380 0.08651 0.10380
    //0.12456 0.10381 0.12456
    blurColor += texture2D(colortex1, uv + offset * vec2(-1.0, -1.0)).rgb * 0.12456;
    blurColor += texture2D(colortex1, uv + offset * vec2(0.0, -1.0)).rgb * 0.10381;
    blurColor += texture2D(colortex1, uv + offset * vec2(1.0, -1.0)).rgb * 0.12456;
    blurColor += texture2D(colortex1, uv + offset * vec2(-1.0, 0.0)).rgb * 0.10381;
    blurColor += texture2D(colortex1, uv).rgb * 0.08651;
    blurColor += texture2D(colortex1, uv + offset * vec2(1.0, 0.0)).rgb * 0.10381;
    blurColor += texture2D(colortex1, uv + offset * vec2(-1.0, 1.0)).rgb * 0.12456;
    blurColor += texture2D(colortex1, uv + offset * vec2(0.0, 1.0)).rgb * 0.10381;
    blurColor += texture2D(colortex1, uv + offset * vec2(1.0, 1.0)).rgb * 0.12456;
    return mix(color, blurColor, fade);
}

vec3 motionBlur(vec3 color, vec2 uv, vec4 viewPosition)
{
    vec4 worldPosition = gbufferModelViewInverse * viewPosition + vec4(cameraPosition, 0.0);
    vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
    vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
    vec2 prevUv = (prevNdcPosition * 0.5 + 0.5).st;
    vec2 delta = uv - prevUv;
    float dist = length(delta);
    if(dist > MOTIONBLUR_THRESHOLD)
    {
        delta = normalize(delta);
        dist = min(dist, MOTIONBLUR_MAX) - MOTIONBLUR_THRESHOLD;
        dist *= MOTIONBLUR_STRENGTH;
        delta *= dist / float(MOTIONBLUR_SAMPLE);
        int sampleNum = 1;
        for(int i = 0; i < MOTIONBLUR_SAMPLE; i++)
        {
            uv += delta;
            if(uv.s <= 0.0 || uv.s >= 1.0 || uv.t <= 0.0 || uv.t >= 1.0)
                break;
            color += texture2D(colortex1, uv).rgb;
            sampleNum++;
        }
        color /= float(sampleNum);
    }
    return color;
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
    color = dof(color, texcoord.st, depth);
    color = motionBlur(color, texcoord.st, viewPosition);
    gl_FragColor = vec4(color, 1.0);
}