#version 120

#define SHADOW_MAP_BIAS 0.8

const int RGB8 = 0;
const int RG16 = 0;
const int colortex1Format = RGB8;
const int gnormalFormat = RG16;
const int shadowMapResolution = 2048;
const float sunPathRotation = -25.0;
const bool shadowHardwareFiltering = true;

uniform float far;
uniform vec3 sunPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D depthtex0;
uniform sampler2DShadow shadow;

varying float extShadow;
varying vec3 lightPosition;
varying vec4 texcoord;

vec3 normalDecode(vec2 enc)
{
    vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
    float l = dot(nn.xyz,-nn.xyw);
    nn.z = l;
    nn.xy *= sqrt(l);
    return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

float shadowMapping(vec4 worldPosition, float dist, vec3 normal, float alpha)
{
    if(dist > 0.9)
    {
        return extShadow;
    }
    float shade = 0.0;
    float angle = dot(lightPosition, normal);
    if(angle <= 0.1 && alpha > 0.99)
    {
        shade = 1.0;
    }
    else
    {
        vec4 shadowposition = shadowModelView * worldPosition;
        shadowposition = shadowProjection * shadowposition;
        float edgeX = abs(shadowposition.x) - 0.9;
        float edgeY = abs(shadowposition.y) - 0.9;
        float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
        float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
        shadowposition.xy /= distortFactor;
        shadowposition /= shadowposition.w;
        shadowposition = shadowposition * 0.5 + 0.5;
        shade = 1.0 - shadow2D(shadow, vec3(shadowposition.st, shadowposition.z - 0.0001)).z;
        if(angle < 0.2 && alpha > 0.99)
        {
            shade = max(shade, 1.0 - (angle - 0.1) * 10.0);
        }
	    shade -= max(0.0, edgeX * 10.0);
		shade -= max(0.0, edgeY * 10.0);
    }
    shade -= clamp((dist - 0.7) * 5.0, 0.0, 1.0);
    shade = clamp(shade, 0.0, 1.0);
    return max(shade, extShadow);
}

void main()
{
    vec4 color = texture2D(gcolor, texcoord.st);
    vec3 normal = normalDecode(texture2D(gnormal, texcoord.st).rg);
    float depth = texture2D(depthtex0, texcoord.st).x;
    vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 -1.0, 2.0 * depth - 1.0, 1.0f);
    viewPosition /= viewPosition.w;
    vec4 worldPosition = gbufferModelViewInverse * (viewPosition + vec4(normal * 0.05 * sqrt(abs(viewPosition.z)), 0.0));
    float dist = length(worldPosition.xyz) / far;
    
    float shade = shadowMapping(worldPosition, dist, normal, color.a);
    color.rgb *= 1.0 - shade * 0.5;
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 highlight = color.rgb * max(brightness - 0.25, 0.0);
/* DRAWBUFFERS:01 */
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(highlight, 1.0);
}