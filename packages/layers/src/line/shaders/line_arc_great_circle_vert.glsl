#define LineTypeSolid 0.0
#define LineTypeDash 1.0
#define Animate 0.0
#define LineTexture 1.0

attribute vec4 a_Color;
attribute vec3 a_Position;
attribute vec4 a_Instance;
attribute float a_Size;
uniform mat4 u_ModelMatrix;
uniform mat4 u_Mvp;
uniform float segmentNumber;
uniform vec4 u_aimate: [ 0, 2., 1.0, 0.2 ];
varying vec4 v_color;
varying vec2 v_normal;

varying float v_distance_ratio;
uniform float u_line_type: 0.0;
uniform vec4 u_dash_array: [10.0, 5., 0, 0];
varying vec4 v_dash_array;

uniform float u_icon_step: 100;
uniform float u_line_texture: 0.0;
varying float v_segmentIndex;
varying float v_arcDistrance;
varying float v_pixelLen;
varying vec2 v_offset;
varying float v_a;

attribute vec2 a_iconMapUV;
varying vec2 v_iconMapUV;

#pragma include "projection"
#pragma include "project"
#pragma include "picking"

float maps (float value, float start1, float stop1, float start2, float stop2) {
    return start2 + (stop2 - start2) * ((value - start1) / (stop1 - start1));
}

float getSegmentRatio(float index) {
    return smoothstep(0.0, 1.0, index / (segmentNumber - 1.));
}

float paraboloid(vec2 source, vec2 target, float ratio) {
    vec2 x = mix(source, target, ratio);
    vec2 center = mix(source, target, 0.5);
    float dSourceCenter = distance(source, center);
    float dXCenter = distance(x, center);
    return (dSourceCenter + dXCenter) * (dSourceCenter - dXCenter);
}

vec3 getPos(vec2 source, vec2 target, float segmentRatio) {
     float vertex_height = paraboloid(source, target, segmentRatio);

    return vec3(
    mix(source, target, segmentRatio),
    sqrt(max(0.0, vertex_height))
    );
}
vec2 getExtrusionOffset(vec2 line_clipspace, float offset_direction) {
  // normalized direction of the line
  vec2 dir_screenspace = normalize(line_clipspace);
  // rotate by 90 degrees
   dir_screenspace = vec2(-dir_screenspace.y, dir_screenspace.x);
  vec2 offset = dir_screenspace * offset_direction * setPickingSize(a_Size)/ 2.0;
  return offset;
}
vec2 getNormal(vec2 line_clipspace, float offset_direction) {
  // normalized direction of the line
  vec2 dir_screenspace = normalize(line_clipspace);
  // rotate by 90 degrees
   dir_screenspace = vec2(-dir_screenspace.y, dir_screenspace.x);
   return reverse_offset_normal(vec3(dir_screenspace,1.0)).xy * sign(offset_direction);
}
float getAngularDist (vec2 source, vec2 target) {
  vec2 delta = source - target;
  vec2 sin_half_delta = sin(delta / 2.0);
  float a =
    sin_half_delta.y * sin_half_delta.y +
    cos(source.y) * cos(target.y) *
    sin_half_delta.x * sin_half_delta.x;
  return 2.0 * atan(sqrt(a), sqrt(1.0 - a));
}

vec2 midPoint(vec2 source, vec2 target) {
  vec2 center = target - source;
  float r = length(center);
  float theta = atan(center.y, center.x);
  float thetaOffset = 0.314;
  float r2 = r / 2.0 / cos(thetaOffset);
  float theta2 = theta + thetaOffset;
  vec2 mid = vec2(r2*cos(theta2) + source.x, r2*sin(theta2) + source.y);
  return mid;
}
float bezier3(vec3 arr, float t) {
  float ut = 1. - t;
  return (arr.x * ut + arr.y * t) * ut + (arr.y * ut + arr.z * t) * t;
}

vec2 interpolate (vec2 source, vec2 target, float angularDist, float t) {
  // if the angularDist is PI, linear interpolation is applied. otherwise, use spherical interpolation
  if(u_CoordinateSystem == COORDINATE_SYSTEM_P20_2) { // gaode2.x
    vec2 mid = midPoint(source, target);
    vec3 x = vec3(source.x, mid.x, target.x);
    vec3 y = vec3(source.y, mid.y, target.y);
    return vec2(bezier3(x ,t), bezier3(y,t));
  }else {
    if(abs(angularDist - PI) < 0.001) {
      return (1.0 - t) * source + t * target;
    }
    float a = sin((1.0 - t) * angularDist) / sin(angularDist);
    float b = sin(t * angularDist) / sin(angularDist);
    vec2 sin_source = sin(source);
    vec2 cos_source = cos(source);
    vec2 sin_target = sin(target);
    vec2 cos_target = cos(target);
    float x = a * cos_source.y * cos_source.x + b * cos_target.y * cos_target.x;
    float y = a * cos_source.y * sin_source.x + b * cos_target.y * sin_target.x;
    float z = a * sin_source.y + b * sin_target.y;
    return vec2(atan(y, x), atan(z, sqrt(x * x + y * y)));
  }
}

void main() {
  v_color = a_Color;
  vec2 source = radians(a_Instance.rg);
  vec2 target = radians(a_Instance.ba);
  float angularDist = getAngularDist(source, target);
  float segmentIndex = a_Position.x;
  float segmentRatio = getSegmentRatio(segmentIndex);
  float indexDir = mix(-1.0, 1.0, step(segmentIndex, 0.0));
  if(u_line_type == LineTypeDash) {
    v_distance_ratio = segmentIndex / segmentNumber;
    vec2 s = source;
    vec2 t = target;
    
    if(u_CoordinateSystem == COORDINATE_SYSTEM_P20_2) { // gaode2.x
      s = unProjCustomCoord(source);
      t = unProjCustomCoord(target);
    }
    float total_Distance = pixelDistance(s, t) / 2.0 * PI;
    total_Distance = total_Distance*8.0;
    // float total_Distance = pixelDistance(a_Instance.rg, a_Instance.ba);
    v_dash_array = pow(2.0, 20.0 - u_Zoom) * u_dash_array / (total_Distance / segmentNumber * segmentIndex);
  }
  if(u_aimate.x == Animate) {
      v_distance_ratio = segmentIndex / segmentNumber;
  }
  float nextSegmentRatio = getSegmentRatio(segmentIndex + indexDir);
  v_distance_ratio = segmentIndex / segmentNumber;
  vec4 curr = project_position(vec4(degrees(interpolate(source, target, angularDist, segmentRatio)), 0.0, 1.0));
  vec4 next = project_position(vec4(degrees(interpolate(source, target, angularDist, nextSegmentRatio)), 0.0, 1.0));
  v_normal = getNormal((next.xy - curr.xy) * indexDir, a_Position.y);
  vec2 offset = project_pixel(getExtrusionOffset((next.xy - curr.xy) * indexDir, a_Position.y));
  //  vec4 project_pos = project_position(vec4(curr.xy, 0, 1.0));
  // gl_Position = project_common_position_to_clipspace(vec4(curr.xy + offset, curr.z, 1.0));

  v_segmentIndex = a_Position.x;
  if(LineTexture == u_line_texture) { // 开启贴图模式  
    v_arcDistrance = length(source - target);
    v_pixelLen = project_pixel(u_icon_step)/8.0;

    v_a = project_pixel(a_Size);
    v_offset = offset + offset * sign(a_Position.y);
    v_iconMapUV = a_iconMapUV;
  }

  if(u_CoordinateSystem == COORDINATE_SYSTEM_P20_2) { // gaode2.x
    gl_Position = u_Mvp * (vec4(curr.xy + offset, curr.z, 1.0));
  } else {
    gl_Position = project_common_position_to_clipspace(vec4(curr.xy + offset, curr.z, 1.0));
  }
  setPickingColor(a_PickingColor);
}

