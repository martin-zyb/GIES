#version 120

const bool gdepthMipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform float viewWidth;
uniform float viewHeight;

varying vec4 texcoord;

vec4 getScale(sampler2D src, vec2 pos, vec2 anchor, int fact) {
    vec2 newCoord = (pos - anchor) * pow(2, fact);
    float padding = 0.02 * pow(2, fact);
    if(newCoord.x<0-padding || newCoord.x>1+padding || newCoord.y<0-padding || newCoord.y>1+padding) {
        return vec4(0, 0, 0, 1);
    }
    vec4 sum = texture2D(src, newCoord);
    int radius = 3;
    for(int i=0; i<radius; i++) {
        for(int j=0; j<radius; j++) {
            float weight = 1.0f - length(vec2(i, j)) / 3.5;
            vec2 offset = vec2(float(i)/viewWidth, float(j)/viewHeight) * pow(2, fact);
            sum.rgb += texture2D(src, newCoord+offset).rgb * weight;
            offset = vec2(-float(i)/viewWidth, float(j)/viewHeight) * pow(2, fact);
            sum.rgb += texture2D(src, newCoord+offset).rgb * weight;
            offset = vec2(float(i)/viewWidth, -float(j)/viewHeight) * pow(2, fact);
            sum.rgb += texture2D(src, newCoord+offset).rgb * weight;
            offset = vec2(-float(i)/viewWidth, -float(j)/viewHeight) * pow(2, fact);
            sum.rgb += texture2D(src, newCoord+offset).rgb * weight;
        }
    }
    return sum / pow(radius+1, 2);
}

/* DRAWBUFFERS: 01 */
void main()
{
    vec4 color = texture2D(colortex0, texcoord.st);
    gl_FragData[0] = color;
    vec4 bloom = vec4(0);
    bloom += getScale(colortex1, texcoord.st, vec2(0.0, 0), 2);
    bloom += getScale(colortex1, texcoord.st, vec2(0.3, 0), 3);
    bloom += getScale(colortex1, texcoord.st, vec2(0.5, 0), 4);
    bloom += getScale(colortex1, texcoord.st, vec2(0.6, 0), 5);
    bloom += getScale(colortex1, texcoord.st, vec2(0.7, 0), 6);
    bloom += getScale(colortex1, texcoord.st, vec2(0.8, 0), 7);
    bloom += getScale(colortex1, texcoord.st, vec2(0.9, 0), 8);
    gl_FragData[1] = bloom;
}