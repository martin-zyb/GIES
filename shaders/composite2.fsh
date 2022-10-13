#version 120

uniform sampler2D colortex3;
uniform float viewWidth;
uniform float viewHeight;
uniform sampler2D gcolor;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D gnormal;
uniform float near;
uniform float far;
uniform mat4 gbufferProjection;

varying vec4 texcoord;

const float offset[9] = float[] (0.0, 1.4896, 3.4757, 5.4619, 7.4482, 9.4345, 11.421, 13.4075, 15.3941);
const float weight[9] = float[] (0.066812, 0.129101, 0.112504, 0.08782, 0.061406, 0.03846, 0.021577, 0.010843, 0.004881);

float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 13.134;

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; \
                        SEARCHPOINT+= DIRVEC * SIGN; \
                        uv = getScreenCoordByViewCoord(SEARCHPOINT); \
                        sampleDepth = linearizeDepth(texture2DLod(depthtex0, uv, 0.0).x); \
                        testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); \
                        SIGN = sign(sampleDepth - testDepth);

vec3 uncharted2Tonemap(vec3 x)
{
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 normalDecode(vec2 enc)
{
    vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
    float l = dot(nn.xyz,-nn.xyw);
    nn.z = l;
    nn.xy *= sqrt(l);
    return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

vec2 getScreenCoordByViewCoord(vec3 viewCoord)
{
    vec4 p = vec4(viewCoord, 1.0);
    p = gbufferProjection * p;
    p /= p.w;
    if(p.z < -1 || p.z > 1)
        return vec2(-1.0);
    p = p * 0.5f + 0.5f;
    return p.st;
}

float linearizeDepth(float depth)
{
    return (2.0 * near) / (far + near - depth * (far - near));
}

float getLinearDepthOfViewCoord(vec3 viewCoord)
{
    vec4 p = vec4(viewCoord, 1.0);
    p = gbufferProjection * p;
    p /= p.w;
    return linearizeDepth(p.z * 0.5 + 0.5);
}

vec3 waterRayTarcing(vec3 startPoint, vec3 direction, vec3 color, float jitter, float fresnel)
{
    const float stepBase = 0.025;
    vec3 testPoint = startPoint;
    vec3 lastPoint = testPoint;
    direction *= stepBase;
    bool hit = false;
    vec4 hitColor = vec4(0.0);
    for(int i = 0; i < 40; i++)
    {
        testPoint += direction * pow(float(i + 1 + jitter), 1.46);
        vec2 uv = getScreenCoordByViewCoord(testPoint);
        if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        {
            hit = true;
            break;
        }
        float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
        sampleDepth = linearizeDepth(sampleDepth);
        float testDepth = getLinearDepthOfViewCoord(testPoint);
        if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i)))
        {
            vec3 finalPoint = lastPoint;
            float _sign = 1.0;
            direction = testPoint - lastPoint;
            BISEARCH(finalPoint, direction, _sign);
            BISEARCH(finalPoint, direction, _sign);
            BISEARCH(finalPoint, direction, _sign);
            BISEARCH(finalPoint, direction, _sign);
            uv = getScreenCoordByViewCoord(finalPoint);
            hitColor = vec4(texture2DLod(gcolor, uv, 0.0).rgb, 1.0);
            hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
            hit = true;
            break;
        }
        lastPoint = testPoint;
    }
    if(!hit)
    {
        vec2 uv = getScreenCoordByViewCoord(lastPoint);
        float testDepth = getLinearDepthOfViewCoord(lastPoint);
        float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
        sampleDepth = linearizeDepth(sampleDepth);
        if(testDepth - sampleDepth < 0.5)
        {
            hitColor = vec4(texture2DLod(gcolor, uv, 0.0).rgb, 1.0);
            hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
        }
    }
    return mix(color, hitColor.rgb, hitColor.a * fresnel);
}

vec3 waterEffect(vec3 color, vec2 uv, vec3 viewPos, float attr)
{
    if(attr == 1.0)
    {
        vec3 normal = normalDecode(texture2D(gnormal, texcoord.st).rg);
        vec3 viewRefRay = reflect(normalize(viewPos), normal);
        vec2 uv2 = texcoord.st * vec2(viewWidth, viewHeight);
        float c = (uv2.x + uv2.y) * 0.25;
        float jitter = mod(c, 1.0);
        float fresnel = 0.02 + 0.98 * (1.0 - dot(viewRefRay, normal));
        color = waterRayTarcing(viewPos + normal * (-viewPos.z / far * 0.2 + 0.05), viewRefRay, color, jitter, fresnel);
    }
    return color;
}

vec3 tonemapping(vec3 color)
{
    color = pow(color, vec3(1.4));
    color *= 6.0;
    vec3 curr = uncharted2Tonemap(color);
    vec3 whiteScale = 1.0f/uncharted2Tonemap(vec3(W));
    color = curr * whiteScale;
    return color;
}

vec3 blur(sampler2D image, vec2 uv, vec2 direction)
{
    vec3 color = texture2D(image, uv).rgb * weight[0];
    for(int i = 1; i < 9; i++)
    {
        color += texture2D(image, uv + direction * offset[i]).rgb * weight[i];
        color += texture2D(image, uv - direction * offset[i]).rgb * weight[i];
    }
    return color;
}

vec3 bloom(vec3 color, vec2 uv)
{
    return color + blur(colortex3, uv, vec2(0.0, 1.0) / vec2(viewWidth, viewHeight));
}

void main() {
    vec3 color =  texture2D(gcolor, texcoord.st).rgb;
    vec3 attrs =  texture2D(colortex4, texcoord.st).rgb;
    float depth = texture2D(depthtex0, texcoord.st).r;
    vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
    viewPosition /= viewPosition.w;
    float attr = attrs.r * 255.0;
    color = bloom(color, texcoord.st);
    color = waterEffect(color, texcoord.st, viewPosition.xyz, attr);
    color = tonemapping(color);
/* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(color, 1.0);
}