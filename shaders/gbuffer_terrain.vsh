#version 120

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec3 color;
varying float blockId;

attribute vec4 mc_Entity;

void main()
{
    gl_Position = ftransform();
    color = gl_Color.rgb;
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    lightMapCoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
    blockId = mc_Entity.x;
}