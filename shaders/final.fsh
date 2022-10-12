#version 120

float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 13.134;

uniform sampler2D gcolor;
uniform sampler2D colortex1;

varying vec4 texcoord;

vec3 uncharted2Tonemap(vec3 x)
{
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

void main()
{
    vec3 color =  texture2D(gcolor, texcoord.st).rgb;
    vec3 highlight = texture2D(colortex1, texcoord.st).rgb;
    color = color + highlight;
    color = pow(color, vec3(1.4));
    color *= 6.0;
    vec3 curr = uncharted2Tonemap(color);
    vec3 whiteScale = 1.0f/uncharted2Tonemap(vec3(W));
    color = curr*whiteScale;
    gl_FragColor = vec4(color, 1.0);
}