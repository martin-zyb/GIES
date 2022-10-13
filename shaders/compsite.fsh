#version 120

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying vec4 texcoord;

vec4 getShadow(vec4 color, vec4 positionInWorldCoord) {
    vec4 positionInSunViewCoord = shadowModelView * positionInWorldCoord;
    vec4 positionInSunClipCoord = shadowProjection * positionInSunViewCoord;
    vec4 positionInSunNdcCoord = vec4(positionInSunClipCoord.xyz/positionInSunClipCoord.w, 1.0);
    vec4 positionInSunScreenCoord = positionInSunNdcCoord * 0.5 + 0.5;
    float currentDepth = positionInSunScreenCoord.z;
    float closest = texture2D(shadow, positionInSunScreenCoord.xy).x;
    if(closest + 0.001 <= currentDepth)
    {
        color.rgb *= 0.5;
    }
    return color;
}


/* DRAWBUFFERS: 0 */
void main() {
    vec4 color = texture2D(texture, texcoord.st);
    float depth = texture2D(depthtex0, texcoord.st).x;
    vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth*2-1, 1);
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0); 
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
    color = getShadow(color, positionInWorldCoord);
    gl_FragData[0] = color;
}