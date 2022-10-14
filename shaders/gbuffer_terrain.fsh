#version 120

const int R32F = 114;
const int colortex2Format = R32F;

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec3 color;
varying float blockId;

/* DRAWBUFFERS:02 */
void main()
{
    vec4 blockColor = texture2D(texture, texcoord.st);
    blockColor.rgb *= color;
    vec3 light = texture2D(lightmap, lightMapCoord.st).rgb; 
    blockColor.rgb *= light;
    gl_FragData[0] = blockColor;
    gl_FragData[1] = vec4(blockId);
}