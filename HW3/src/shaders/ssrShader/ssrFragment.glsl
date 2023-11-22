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

#define SAMPLE_NUM 5

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
  // if (n.z == 0.0) {
  //   sign_ = 1.0;
  // }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a,
            sign_ * b,
            -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

// void LocalBasis(vec3 n, out vec3 tangent, out vec3 bitangent) {
//     vec3 helperVec;
//     if (abs(n.x) < abs(n.y))
//         helperVec = vec3(1.0, 0.0, 0.0);
//     else
//         helperVec = vec3(0.0, 1.0, 0.0);
//     tangent = normalize(cross(helperVec, n));
//     bitangent = normalize(cross(n, tangent));
// }


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
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 screenUV) {
  vec3 reflectivity = GetGBufferDiffuse(screenUV);
  vec3 normal = GetGBufferNormalWorld(screenUV);
  float cosi = max(0., dot(normal, wi));
  vec3 f_r = reflectivity * cosi;
  return f_r;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 screenUV) {
  vec3 Li = uLightRadiance * GetGBufferuShadow(screenUV);
  return Li;
}

/*
 *  Test The Intersection from pos(world) to pos+dir*step*n(world)
 */

// #define EPS 5e-2
// #define TOTAL_STEP_TIMES 20
// #define THRESHOLD 0.1
// #define INIT_STEP 0.8
// bool outScreen(vec3 curPos){
//   vec2 uvScreen = GetScreenCoordinate(curPos);
//   return any(bvec4(lessThan(uvScreen, vec2(0.0)), greaterThan(uvScreen, vec2(1.0))));
// }
// bool testDepth(vec3 nextPos){
//   return GetDepth(nextPos) < GetGBufferDepth(GetScreenCoordinate(nextPos));
// }
// bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
//   float step = INIT_STEP;
//   bool result = false, firstIn = false;
//   vec3 nextPos, curPos = ori;
//   for(int i = 0; i < TOTAL_STEP_TIMES; i++) {
//     nextPos = curPos + dir * step;
//     if(outScreen(curPos)) break;
//     if(testDepth(nextPos)){ // 可以进步
//       curPos += dir * step;
//       if(firstIn) step *= 0.5;
//       continue;
//     }else{ // 过于进步了
//       firstIn = true;
//       if(step < EPS){
//         float s1 = GetGBufferDepth(GetScreenCoordinate(curPos)) - GetDepth(curPos) + EPS;
//         float s2 = GetDepth(nextPos) - GetGBufferDepth(GetScreenCoordinate(nextPos)) + EPS;
//         if(s1 < THRESHOLD && s2 < THRESHOLD){
//           hitPos = curPos + 2.0 * dir * step * s1 / (s1 + s2);
//           result = true;
//         }
//         break;
//       }
//       if(firstIn) step *= 0.5;
//     }
//   }
//   return result;
// }


#define INIT_STEP 0.8
#define MAX_STEPS 20
#define EPS 1e-2
#define THRES 0.1
bool outScreen(vec3 pos){
  vec2 uv = GetScreenCoordinate(pos);
  return any(bvec4(lessThan(uv, vec2(0.0)), greaterThan(uv, vec2(1.0))));
}
bool atFront(vec3 pos){
  return GetDepth(pos) < GetGBufferDepth(GetScreenCoordinate(pos));
}
bool hasInter(vec3 pos, vec3 dir, out vec3 hitPos){
  float d1 = GetGBufferDepth(GetScreenCoordinate(pos)) - GetDepth(pos) + EPS;
  float d2 = GetDepth(pos + dir) - GetGBufferDepth(GetScreenCoordinate(pos + dir)) + EPS;
  if(d1 < THRES && d2 < THRES){
    hitPos = pos + dir * d1 / (d1 + d2);
    return true;
  }  
  return false;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  bool intersect = false, firstinter = false;
  float st = INIT_STEP;
  vec3 current = ori;
  for (int i = 0;i < MAX_STEPS;i++){
    if(outScreen(current)){
      break;
    }
    else if(atFront(current + dir * st)){
      current += dir * st;
    }else{
      firstinter = true;
      if(st < EPS){
        if(hasInter(current, dir * st * 2.0, hitPos)){
          intersect = true;
        }
        break;
      }
    }
    if(firstinter)
      st *= 0.5;
  }
  return intersect;
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

vec3 EvalIndirectionLight(vec3 wi, vec3 wo, vec2 screenUV){
  vec3 L_ind = vec3(0.0);
  float s = InitRand(gl_FragCoord.xy);
  vec3 normal = GetGBufferNormalWorld(screenUV);
  vec3 b1, b2;
  LocalBasis(normal, b1, b2);

  for(int i = 0; i < SAMPLE_NUM; i++){
    float pdf;
    vec3 direction = SampleHemisphereUniform(s, pdf);
    vec3 worldDir = normalize(mat3(b1, b2, normal) * direction);

    vec3 position_1;
    if(RayMarch(vPosWorld.xyz, worldDir, position_1)){ // 采样光线碰到了 position_1
      vec2 hitScreenUV = GetScreenCoordinate(position_1);
      vec3 bsdf_d = EvalDiffuse(worldDir, wo, screenUV); // 直接光照
      vec3 bsdf_i = EvalDiffuse(wi, worldDir, hitScreenUV); // 间接光照
      L_ind += bsdf_d / pdf * bsdf_i * EvalDirectionalLight(hitScreenUV);
    }
  }
  L_ind /= float(SAMPLE_NUM);
  return L_ind;
}

// Main entry point for the shader
void main() {
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  vec2 screenUV = GetScreenCoordinate(vPosWorld.xyz);

  // Main Light coefficient
  float mainCoeff= 1.0;
  // Basic mirror-only SSR coefficient
  float ssrCoeff = 1.0;
  // Indirection Light coefficient
  float indCoeff = 1.0;

  // Direction Light
  vec3 L_d = EvalDiffuse(wi, wo, screenUV) * EvalDirectionalLight(screenUV) * mainCoeff;
  // SSR Light
  vec3 L_ssr = EvalSSR(wi, wo, screenUV) * ssrCoeff;
  // Indirection Light
  vec3 L_i = EvalIndirectionLight(wi, wo, screenUV) * indCoeff;

  vec3 result = L_d + L_i;
  // vec3 result = L_d + L_ssr;
  // vec3 result = L_d + L_ssr + L_i;
  vec3 color = pow(clamp(result, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}