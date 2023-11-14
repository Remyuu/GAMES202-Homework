//prtVertex.glsl

attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute mat3 aPrecomputeLT;  // Precomputed Light Transfer matrix for the vertex

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat3 uPrecomputeL[3];  // Precomputed Lighting matrices
varying highp vec3 vNormal;

varying highp vec3 vColor;     // Outgoing color after the dot product calculations

float L_dot_LT(const mat3 PrecomputeL, const mat3 PrecomputeLT) {
  return dot(PrecomputeL[0], PrecomputeLT[0]) 
        + dot(PrecomputeL[1], PrecomputeLT[1]) 
        + dot(PrecomputeL[2], PrecomputeLT[2]);
}

void main(void) {
  // 防止报错，无实际作用
  // vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;
  aNormalPosition;

  for(int i = 0; i < 3; i++) {
      vColor[i] = L_dot_LT(aPrecomputeLT, uPrecomputeL[i]);
  }

  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition, 1.0);
}
