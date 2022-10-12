#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec2 normal;
varying float attr;

vec2 normalEncode(vec3 n)
{
    vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
    enc = enc*0.5+0.5;
    return enc;
}

void main()
{
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    float blockId = mc_Entity.x;
    if(gl_Normal.y > -0.9 && (mc_Entity.x == 8 || mc_Entity.x == 9))
        attr = 1.0 / 255.0;
    else
        attr = 0.0;
    gl_Position = gl_ProjectionMatrix * position;
    gl_FogFragCoord = length(position.xyz);
    color = gl_Color;
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
    normal = normalEncode(gl_NormalMatrix * gl_Normal);
}