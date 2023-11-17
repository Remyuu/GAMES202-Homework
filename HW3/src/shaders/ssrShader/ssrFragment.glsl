#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 reflectivity = GetGBufferDiffuse(uv);
  vec3 normal = GetGBufferNormalWorld(uv);
  float cosi = max(0., dot(normal, wi));
  vec3 f_r = reflectivity * cosi;
  return f_r;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  vec3 Li = uLightRadiance * GetGBufferuShadow(uv);
  return Li;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  const int totalStepTimes = 70;
  const float threshold = 0.0001;
  float step = 0.05;
  vec3 stepDir = normalize(dir) * step;
  vec3 curPos = ori;

  for(int i = 0; i < totalStepTimes; i++) {
    vec2 screenUV = GetScreenCoordinate(curPos);
    float rayDepth = GetDepth(curPos);
    float gBufferDepth = GetGBufferDepth(screenUV);

    // Check if the ray has hit an object
    if(rayDepth > gBufferDepth + threshold){
      hitPos = curPos;
      return true;
    }
    curPos += stepDir;
  }
  return false;
}

vec3 EvalSSR(vec3 wi, vec3 wo, vec2 screenUV) {
  vec3 worldNormal = GetGBufferNormalWorld(screenUV);
  vec3 relfectDir = normalize(reflect(-wo, worldNormal));
  vec3 hitPos;
  if(RayMarch(vPosWorld.xyz, relfectDir, hitPos)){
    vec2 INV_screenUV = GetScreenCoordinate(hitPos);
    return GetGBufferDiffuse(INV_screenUV);
  }
  else{
    return vec3(0.); 
  }
}

#define SAMPLE_NUM 1

vec3 EvalIndirectionLight(vec3 wi, vec3 wo, vec2 screenUV){
  float s = InitRand(gl_FragCoord.xy);
  vec3 L_ind = vec3(0.0);

  for(int i = 0; i < SAMPLE_NUM; i++){
    float pdf;
    vec3 localDir = SampleHemisphereUniform(s, pdf);
    vec3 normal = GetGBufferNormalWorld(screenUV);
    vec3 b1, b2;
    LocalBasis(normal, b1, b2);
    vec3 dir = normalize(mat3(b1, b2, normal) * localDir);

    vec3 position_1;
    if(RayMarch(vPosWorld.xyz, dir, position_1)){
      vec2 hitScreenUV = GetScreenCoordinate(position_1);
      L_ind += EvalDiffuse(dir, wo, screenUV) / pdf * EvalDiffuse(wi, dir, hitScreenUV) * EvalDirectionalLight(hitScreenUV);
    }
  }
  L_ind /= float(SAMPLE_NUM);
  return L_ind;
}

// vec3 EvalIndirectionLight(vec3 pos){
//   float pdf, seed = dot(pos, vec3(100.0));
//   vec3 Li = vec3(0.0), dir, hitPos;
//   vec3 normal = GetGBufferNormalWorld(GetScreenCoordinate(pos)), b1, b2;
//   LocalBasis(normal, b1, b2);
//   mat3 TBN = mat3(b1, b2, normal);
//   for(int i = 0; i < SAMPLE_NUM;i++){
//     dir = normalize(TBN * SampleHemisphereCos(seed, pdf));
//     if(RayMarch(pos, dir, hitPos)){
//       vec3 wo = normalize(uCameraPos - pos);
//       vec3 L = EvalDiffuse(dir, wo, GetScreenCoordinate(pos)) / pdf;
//       wo = normalize(uCameraPos - hitPos);
//       vec3 wi = normalize(uLightDir);
//       L *= EvalDiffuse(wi, wo, GetScreenCoordinate(hitPos)) * EvalDirectionalLight(GetScreenCoordinate(hitPos));
//       Li += L;
//     }
//   }
//   return Li / float(SAMPLE_NUM);
// }

// Main entry point for the shader
void main() {
  // float s = InitRand(gl_FragCoord.xy);
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  vec2 screenUV = GetScreenCoordinate(vPosWorld.xyz);

  // Basic mirror-only SSR
  float reflectivity = 0.0;

  // Direction Light
  vec3 L_d = EvalDiffuse(wi, wo, screenUV) * EvalDirectionalLight(screenUV);
  // SSR Light
  // vec3 L_ssr = EvalSSR(wi, wo, screenUV) * reflectivity;
  vec3 L_ssr =  vec3(0);
  // Indirection Light
  vec3 L_i = EvalIndirectionLight(wi, wo, screenUV);

  vec3 result = L_d + L_ssr + L_i;
  vec3 color = pow(clamp(result, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}