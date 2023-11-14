//prtFragment.glsl

#ifdef GL_ES
precision mediump float;
#endif

varying highp vec3 vColor;

vec3 doNothing(vec3 color){
    return color;
}

vec3 filmicToneMapping(vec3 color) {
    color = max(vec3(0.0), color - vec3(0.004));
    color = (color * (6.2 * color + 0.5)) / (color * (6.2 * color + 1.7) + 0.06);
    return color;
}

vec3 toneMapping(vec3 color){
    vec3 result;

    for (int i=0; i<3; ++i) {
        if (color[i] <= 0.0031308)
            result[i] = 12.92 * color[i];
        else
            result[i] = (1.0 + 0.055) * pow(color[i], 1.0/2.4) - 0.055;
    }

    return result;
}

void main(){
    // vec3 color = doNothing(vColor);
    // vec3 color = filmicToneMapping(vColor);
    vec3 color = toneMapping(vColor);
  gl_FragColor = vec4(color, 1.0);
}