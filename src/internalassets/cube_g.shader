///CUBE GEOMETRY SHADER
#version 330 core

layout(points) in vec4; 
layout(triangle_strip, max_vertices = 72) out vec4; 

out vec3 fragNormal;
out float fragU;
flat out float fragScaleX;
out float fragV;
flat out float fragScaleY;

uniform mat4 matrix; 
uniform mat4 rotation;
uniform vec3 stride; //matches scale on cube

vec3 verts[8] = vec3[]( 
	vec3(-0.5f, -0.5f, -0.5f), vec3(0.5f, -0.5f, -0.5f), 
	vec3(-0.5f, -0.5f, 0.5f), vec3(0.5f, -0.5f, 0.5f), 
	vec3(0.5f, 0.5f, -0.5f), vec3(-0.5f, 0.5f, -0.5f), 
	vec3(0.5f, 0.5f, 0.5f), vec3(-0.5f, 0.5f, 0.5f)
); 

void BuildFace(int fir, int sec, int thr, int frt, vec3 normal, vec2 scale)
{ 
    vec3 adjNormal = (rotation * vec4(normal, 1.0f)).xyz;
  
	gl_Position = matrix * vec4(verts[fir], 1.0f);
    fragNormal = adjNormal;
    fragU = -scale.x;
    fragV = scale.y;
    fragScaleX = scale.x;	
    fragScaleY = scale.y;	
    EmitVertex(); 
	gl_Position = matrix * vec4(verts[sec], 1.0f);
    fragNormal = adjNormal;
    fragU = scale.x;
    fragV = -scale.y;
    fragScaleX = scale.x;	
    fragScaleY = scale.y;
	EmitVertex(); 
	gl_Position = matrix * vec4(verts[thr], 1.0f);
    fragNormal = adjNormal;
    fragU = scale.x;
    fragV = scale.y;
    fragScaleX = scale.x;	
    fragScaleY = scale.y;
	EmitVertex(); 
	EndPrimitive();
	 
	gl_Position = matrix * vec4(verts[fir], 1.0f);
    fragNormal = adjNormal;
    fragU = scale.x;
    fragV = -scale.y;
    fragScaleX = scale.x;	
    fragScaleY = scale.y;
	EmitVertex(); 
	gl_Position = matrix * vec4(verts[frt], 1.0f);
    fragNormal = adjNormal;
    fragU = scale.x;
    fragV = scale.y;
    fragScaleX = scale.x;	
    fragScaleY = scale.y;  
    EmitVertex(); 
	gl_Position = matrix * vec4(verts[sec], 1.0f);
    fragNormal = adjNormal;
    fragU = -scale.x;
    fragV = scale.y;
    fragScaleX = scale.x;	
    fragScaleY = scale.y;
	EmitVertex(); 
	EndPrimitive(); 
} 

void main()
{ 
  //draw inside
  BuildFace(3, 0, 2, 1, vec3(0.0f, 1.0f, 0.0f),  stride.zx);
	BuildFace(2, 5, 7, 0, vec3(1.0f, 0.0f, 0.0f),  stride.zy); 
	BuildFace(6, 1, 3, 4, vec3(-1.0f, 0.0f, 0.0f), stride.yz);
	BuildFace(6, 2, 7, 3, vec3(0.0f, 0.0f, -1.0f), stride.yx); 
	BuildFace(1, 5, 0, 4, vec3(0.0f, 0.0f, 1.0f),  stride.yx);
	BuildFace(7, 4, 6, 5, vec3(0.0f, -1.0f, 0.0f), stride.xz);
  
  //draw outside
	BuildFace(0, 3, 2, 1, vec3(0.0f, 1.0f, 0.0f),  stride.zx);
	BuildFace(5, 2, 7, 0, vec3(1.0f, 0.0f, 0.0f),  stride.zy); 
	BuildFace(1, 6, 3, 4, vec3(-1.0f, 0.0f, 0.0f), stride.zy);
	BuildFace(2, 6, 7, 3, vec3(0.0f, 0.0f, -1.0f), stride.yx); 
	BuildFace(5, 1, 0, 4, vec3(0.0f, 0.0f, 1.0f),  stride.yx);
	BuildFace(4, 7, 6, 5, vec3(0.0f, -1.0f, 0.0f), stride.xz);
}