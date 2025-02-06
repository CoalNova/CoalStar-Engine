///CUBE FRAGMENT SHADER
#version 330 core

out vec4 outColor;
in vec3 fragNormal;
in float fragU;
flat in float fragScaleX;
in float fragV;
flat in float fragScaleY;

uniform float ambientLuminance;
uniform vec4 ambientChroma;
uniform vec4 colorA;
uniform vec4 colorB;
uniform vec3 sunRotation;
uniform vec4 sun;

float edge = 0.2f;

void main()
{
    //edge color
    vec4 baseColor = ((abs(fragU) > (fragScaleX - edge) || 
        abs(fragV) > (fragScaleY - edge)) ? colorB : colorA); 
    outColor =
        vec4((ambientChroma.rgb + baseColor.rgb) * ambientLuminance 
            + max(0.0, dot(-sunRotation, fragNormal)) * sun.rgb, baseColor.a);
        
}