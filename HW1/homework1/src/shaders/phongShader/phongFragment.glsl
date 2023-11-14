#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 8
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 1

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

#define LSIZE 10.0
#define LWIDTH (LSIZE/240.0)
#define BLOKER_SIZE (LWIDTH/2.0)
#define MAX_PENUMBRA 0.5

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/255.0, 1.0/(255.0*255.0), 1.0/(255.0*255.0*255.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {
  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );// 把样本放在了一个半径为1的圆域内

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker(sampler2D shadowMap,vec2 uv,float z_shadingPoint){
  float count=0., depth_sum=0., depthOnShadowMap, is_block;
  vec2 nCoords;
  for(int i=0;i<BLOCKER_SEARCH_NUM_SAMPLES;i++){
    nCoords=uv+BLOKER_SIZE*poissonDisk[i];
    
    depthOnShadowMap=unpack(texture2D(shadowMap,nCoords));
    if(abs(depthOnShadowMap) < EPS)depthOnShadowMap=1.;
    // step函数用于比较两个值。
    is_block=step(depthOnShadowMap,z_shadingPoint-EPS);
    count+=is_block;
    depth_sum+=is_block*depthOnShadowMap;
  }
  if(count<EPS)
    return z_shadingPoint;
  return depth_sum/count;
}


float PCF(sampler2D shadowMap,vec4 shadingPoint){
  // 采样 采样结果会返回到全局变量 - poissonDisk[]
  // uniformDiskSamples(shadingPoint.xy);
  poissonDiskSamples(shadingPoint.xy);
  
  // shadow map 的大小, 越大滤波的范围越小
  float textureSize=256.;
  // 滤波的步长
  float filterStride=1.;
  // 滤波窗口的范围
  float filterRange=1./textureSize*filterStride;
  // 有多少点不在阴影里
  int noShadowCount=0;
  for(int i=0;i<NUM_SAMPLES;i++){
    vec2 sampleCoord=poissonDisk[i]*filterRange+shadingPoint.xy;
    float closestDepth=unpack(texture2D(shadowMap,sampleCoord));
    float currentDepth=shadingPoint.z;
    if(currentDepth<closestDepth+EPS){
      noShadowCount+=1;
    }
  }
  return float(noShadowCount)/float(NUM_SAMPLES);
}

float PCSS(sampler2D shadowMap,vec4 shadingPoint){
  poissonDiskSamples(shadingPoint.xy);
  float z_shadingPoint=shadingPoint.z;
  // STEP 1: avgblocker depth
  float avgblockerdep=findBlocker(shadowMap,shadingPoint.xy,z_shadingPoint);
  if(abs(avgblockerdep - z_shadingPoint) <= EPS) // No Blocker
  return 1.;
  
  // STEP 2: penumbra size
  float dBlocker=avgblockerdep,dReceiver=z_shadingPoint-avgblockerdep;
  float wPenumbra=min(LWIDTH*dReceiver/dBlocker,MAX_PENUMBRA);
  
  // STEP 3: filtering
  float _sum=0.,depthOnShadowMap,vis;
  vec2 nCoords;
  for(int i=0;i<NUM_SAMPLES;i++){
    nCoords=shadingPoint.xy+wPenumbra*poissonDisk[i];
    
    depthOnShadowMap=unpack(texture2D(shadowMap,nCoords));
    if(abs(depthOnShadowMap)<1e-5)depthOnShadowMap=1.;
    
    vis=step(z_shadingPoint-EPS,depthOnShadowMap);
    _sum+=vis;
  }
  
  return _sum/float(NUM_SAMPLES);
}



float VSSM(sampler2D shadowMap, vec4 shadingPoint){
  return 1.;
}


// 使用bias偏移值优化自遮挡
float getBias(float ctrl) {
  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float m = 200.0 / 2048.0 / 2.0; // 正交矩阵宽高/shadowmap分辨率/2
  float bias = max(m, m * (1.0 - dot(normal, lightDir))) * ctrl;
  return bias;
}

// use Hard Shadow 
float useShadowMap(sampler2D shadowMap, vec4 shadingPoint){
  // Retrieve the closest depth value from the light's perspective using the fragment's position in light space.
  float closestDepth = unpack(texture2D(shadowMap, shadingPoint.xy));
  // Compare the fragment's depth with the closest depth to determine if it's in shadow.
  return (closestDepth + EPS + getBias(.4)> shadingPoint.z) ? 1.0 : 0.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff = uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void){  
  vec3 shadingPoint = vPositionFromLight.xyz / vPositionFromLight.w;
  shadingPoint = shadingPoint*.5+.5;// 归一化至 [0,1]
  
  float visibility=1.;
  if(shadingPoint.x<0.||shadingPoint.x>1.||
  shadingPoint.y<0.||shadingPoint.y>1.){
    visibility=1.;// 光源看不见的地方，因此不会被阴影所覆盖
  }else{
    // visibility=useShadowMap(uShadowMap,vec4(shadingPoint,1.));
    // visibility=PCF(uShadowMap,vec4(shadingPoint,1.));
    visibility = PCSS(uShadowMap,vec4(shadingPoint,1.));
    // visibility=VSSM(uShadowMap,vec4(shadingPoint,1.));
  }
  vec3 phongColor=blinnPhong();
  gl_FragColor=vec4(phongColor*visibility,1.);
  // gl_FragColor = vec4(phongColor, 1.0);
}