///CUBE GEOMETRY SHADER
#version 330 core

layout(points) in; 
layout(triangle_strip, max_vertices = 6) out; 

// pos_x, pos_y, width, height
uniform vec4 base;
uniform float index;

void main() {
    float x = base.x;
    float y = base.y;
    float w = base.z;
    float h = base.w;
    float z = 0.0f;//index;
    float k = 1.0f;

    gl_Position = vec4(x, y, z, k);
    EmitVertex(); 
    gl_Position = vec4(x + w, y + h, z, k);
    EmitVertex(); 
    gl_Position = vec4(x, y + h, z, k);
    EmitVertex(); 

    EndPrimitive();

    gl_Position = vec4(x, y, z, k);
    EmitVertex(); 
    gl_Position = vec4(x + w, y, z, k);
    EmitVertex(); 
    gl_Position = vec4(x + w, y + h, z, k);
    EmitVertex(); 
    
    EndPrimitive();
}