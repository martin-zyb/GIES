#version 120

#define SHADOW_MAP_BIAS 0.8
#define CLOUD_MIN 400.0
#define CLOUD_MAX 430.0

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
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform sampler2D noisetex;

varying float extShadow;
varying vec3 lightPosition;
varying vec4 texcoord;
varying vec3 worldSunPosition;

varying vec3 cloudBase1;
varying vec3 cloudBase2;
varying vec3 cloudLight1;
varying vec3 cloudLight2;

vec4 cloudLighting(vec4 sum, float density, float diff)
{  
    vec4 color = vec4(mix(cloudBase1, cloudBase2, density ), density );
    vec3 lighting = mix(cloudLight1, cloudLight2, diff);
    color.xyz *= lighting;
    color.a *= 0.4;
    color.rgb *= color.a;
    return sum + color*(1.0-sum.a);
}

float noise(vec3 x)
{
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = smoothstep(0.0, 1.0, f);
    vec2 uv = (p.xy+vec2(37.0, 17.0)*p.z) + f.xy;
    float v1 = texture2D( noisetex, (uv)/256.0, -100.0 ).x;
    float v2 = texture2D( noisetex, (uv + vec2(37.0, 17.0))/256.0, -100.0 ).x;
    return mix(v1, v2, f.z);
}

float getCloudNoise(vec3 worldPos)
{
    vec3 coord = worldPos;
    float v = 1.0;
    if(coord.y < CLOUD_MIN)
    {
        v = 1.0 - smoothstep(0.0, 1.0, min(CLOUD_MIN - coord.y, 1.0));
    }
    else if(coord.y > CLOUD_MAX)
    {
        v = 1.0 - smoothstep(0.0, 1.0, min(coord.y - CLOUD_MAX, 1.0));
    }
    coord.x += frameTimeCounter * 5.0;
    coord *= 0.002;
    float n  = noise(coord) * 0.5;   coord *= 3.0;
    n += noise(coord) * 0.25;  coord *= 3.01;
    n += noise(coord) * 0.125; coord *= 3.02;
    n += noise(coord) * 0.0625;
    n *= v;
    return smoothstep(0.0, 1.0, pow(max(n - 0.5, 0.0) * (1.0 / (1.0 - 0.5)), 0.5));
}

vec3 cloudRayMarching(vec3 startPoint, vec3 direction, vec3 bgColor, float maxDis) {
    if(direction.y <= 0.1)
        return bgColor;
    vec3 testPoint = startPoint;
    float cloudMin = startPoint.y + CLOUD_MIN * (exp(-startPoint.y / CLOUD_MIN) + 0.001);
    float d = (cloudMin - startPoint.y) / direction.y;
    testPoint += direction * (d + 0.01);
    if(distance(testPoint, startPoint) > maxDis)
        return bgColor;
    float cloudMax = cloudMin + (CLOUD_MAX - CLOUD_MIN);
    direction *= 1.0 / direction.y;
    vec4 final = vec4(0.0);
    float fadeout = (1.0 - clamp(length(testPoint) / (far * 100.0) * 6.0, 0.0, 1.0));
    for(int i = 0; i < 32; i++)
    {
        if(final.a > 0.99 || testPoint.y > cloudMax)
            continue;
        testPoint += direction;
        vec3 samplePoint = vec3(testPoint.x, testPoint.y - cloudMin + CLOUD_MIN, testPoint.z);
        float density = getCloudNoise(samplePoint) * fadeout;
        if(density > 0.0)
        {
            float diff = clamp((density - getCloudNoise(samplePoint + worldSunPosition * 10.0)) * 10.0, 0.0, 1.0 );
            final = cloudLighting(final, density, diff);
        }
    }
    final = clamp(final, 0.0, 1.0);
    return bgColor * (1.0 - final.a) + final.rgb;
}

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
    vec3 rayDir = normalize(gbufferModelViewInverse * viewPosition).xyz;
    if(dist > 0.9999)
        dist = 100.0;
color.rgb = cloudRayMarching(cameraPosition, rayDir, color.rgb, dist * far);
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 highlight = color.rgb * max(brightness - 0.25, 0.0);
/* DRAWBUFFERS:01 */
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(highlight, 1.0);
}