#version 120

const int shadowMapResolution = 4096;   // 阴影分辨率 默认 1024
const float	sunPathRotation	= -25.0;    // 太阳偏移角 默认 0

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform float viewWidth;
uniform float viewHeight;

varying vec4 texcoord;

vec4 getBloomOriginColor(vec4 color)
{
    float brightness = 0.299*color.r + 0.587*color.g + 0.114*color.b;
    if(brightness < 0.5)
    {
        color.rgb = vec3(0);
    }
    return color;
}

vec3 getBloom()
{
    int radius = 25;	// 半径 
    vec3 sum = vec3(0);
    
    for(int i=-radius; i<=radius; i++)
    {
        for(int j=-radius; j<=radius; j++)
        {
            vec2 offset = vec2(i/viewWidth, j/viewHeight);
            sum += getBloomOriginColor(texture2D(texture, texcoord.st+offset)).rgb;
        }
    }
    
    sum /= pow(radius+1, 2);
    return sum*0.3;
}

vec2 getFishEyeCoord(vec2 positionInNdcCoord)
{
    return positionInNdcCoord / (0.15 + 0.8*length(positionInNdcCoord.xy));
}

vec4 getShadow(vec4 color, vec4 positionInWorldCoord)
{
    vec4 positionInSunViewCoord = shadowModelView * positionInWorldCoord;
    vec4 positionInSunClipCoord = shadowProjection * positionInSunViewCoord;
    vec4 positionInSunNdcCoord = vec4(positionInSunClipCoord.xyz/positionInSunClipCoord.w, 1.0);
    positionInSunNdcCoord.xy = getFishEyeCoord(positionInSunNdcCoord.xy);
    vec4 positionInSunScreenCoord = positionInSunNdcCoord * 0.5 + 0.5;
    float currentDepth = positionInSunScreenCoord.z;
    float dis = length(positionInWorldCoord.xyz) / far;
    int radius = 1;
    float sum = pow(radius*2+1, 2);
    float shadowStrength = 0.6 * (1 - dis);
    for(int x=-radius; x<=radius; x++)
    {
        for(int y=-radius; y<=radius; y++)
        {
            vec2 offset = vec2(x,y) / shadowMapResolution;
            float closest = texture2D(shadow, positionInSunScreenCoord.xy + offset).x;   
            if(closest+0.001 <= currentDepth && dis<0.99)
            {
                sum -= 1;
            }
        }
    }
    sum /= pow(radius*2+1, 2);
    color.rgb *= sum*shadowStrength + (1-shadowStrength);
    return color;
}

/* DRAWBUFFERS: 01 */
void main()
{
    vec4 color = texture2D(texture, texcoord.st);
    float depth = texture2D(depthtex0, texcoord.st).x;
    vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth*2-1, 1);
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0); 
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
    //color.rgb += getBloom();
    color = getShadow(color, positionInWorldCoord);
    vec4 bloom = color;
    float id = texture2D(colortex2, texcoord.st).x;
    if(id==10089)
    {
        bloom.rgb *= vec3(0.7, 0.4, 0.2);
    }
    else if(id==10090)
    {
        float brightness = dot(bloom.rgb, vec3(0.2, 0.7, 0.1));
        if(brightness < 0.5)
        {
            bloom.rgb = vec3(0);
        }
        bloom.rgb *= (brightness-0.5)*2;
    } 
    else
    {
    	bloom.rgb *= 0.03;
    }
    gl_FragData[0] = color;
    gl_FragData[1] = bloom;
}