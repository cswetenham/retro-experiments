Shader "Hidden/PostEffectShader"
{
  Properties
  {
    _MainTex("Texture", 2D) = "white" {}
  }
    SubShader
  {
    // No culling or depth
    Cull Off ZWrite Off ZTest Always

    Pass
  {
    CGPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

  struct appdata
  {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
  };

  struct v2f
  {
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
  };

  v2f vert(appdata v)
  {
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    return o;
  }

  sampler2D _MainTex;

  float Epsilon = 1e-10;

  float3 HUEtoRGB(in float H)
  {
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R, G, B));
  }

  float3 RGBtoHCV(in float3 RGB)
  {
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0 / 3.0) : float4(RGB.gb, 0.0, -1.0 / 3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
  }

  float3 HSLtoRGB(in float3 HSL)
  {
    float3 RGB = HUEtoRGB(HSL.x);
    float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
    return (RGB - 0.5) * C + HSL.z;
  }

  float3 HSVtoRGB(in float3 HSV)
  {
    float3 RGB = HUEtoRGB(HSV.x);
    return ((RGB - 1) * HSV.y + 1) * HSV.z;
  }

  float3 RGBtoHSL(in float3 RGB)
  {
    float3 HCV = RGBtoHCV(RGB);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1 - abs(L * 2 - 1) + Epsilon);
    return float3(HCV.x, S, L);
  }

  float3 RGBtoHSV(in float3 RGB)
  {
    float3 HCV = RGBtoHCV(RGB);
    float S = HCV.y / (HCV.z + Epsilon);
    return float3(HCV.x, S, HCV.z);
  }

  // 2x2 Bayer ordered dither matrix (transpose of version on web)
  static int bayerMatrix2x2[4] =
  {
    0, 2,
    3, 1
  };

  // 4x2 Bayer ordered dither matrix (trying to reverse-eng Jesus II)
  // NOTE: 4x2 to improve repeating patterns, but only 4 discrete values in matrix!
  static int bayerMatrix4x2[8] =
  {
    0, 2, 3, 1,
    3, 1, 0, 2
  };

  static int jesusMatrix4x2x5[40] =
  {
    0, 0, 0, 0,
    0, 0, 0, 0,

    0, 0, 1, 0,
    1, 0, 0, 0,

    0, 1, 0, 1,
    1, 0, 1, 0,

    1, 1, 1, 0,
    1, 0, 1, 1,

    1, 1, 1, 1,
    1, 1, 1, 1
  };

  // 4x4 Bayer ordered dither matrix (transpose of version on web)
  static int bayerMatrix4x4[16] =
  {
    0,  8,  2, 10,
    12,  4, 14,  6,
    3, 11,  1,  9,
    15,  7, 13,  5
  };

  // 8x8 Bayer ordered dither matrix (transpose of version on web)
  static int bayerMatrix8x8[64] =
  {
    0,  32, 8,  40, 2,  34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44, 4,  36, 14, 46, 6,  38,
    60, 28, 52, 20, 62, 30, 54, 22,
    3,  35, 11, 43, 1,  33, 9,  41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7,  39, 13, 45, 5,  37,
    63, 31, 55, 23, 61, 29, 53, 21
  };

  // 8x8 cluster dot matrix
  static int clusterDotMatrix8x8[64] =
  {
    24, 8, 22, 30, 34, 44, 42, 32,
    10, 0, 6, 20, 46, 58, 56, 40,
    12, 2, 4, 18, 48, 60, 62, 54,
    26, 14, 16, 28, 36, 50, 52, 38,
    35, 45, 43, 33, 25, 9, 23, 31,
    47, 59, 57, 41, 11, 1, 7, 21,
    49, 61, 63, 55, 13, 3, 5, 19,
    37, 51, 53, 39, 27, 15, 17, 29
  };

  float indexValue(float2 xy) {
#if 0
    return 0.5;
#elif 0
    // This is a weird one
    // y is first divided by 2 with floor
    xy.y = floor(xy.y / 2.0);

    int x_size = 4;
    int y_size = 2;
    int distinct_value_count = 4;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    return (1.0 + bayerMatrix4x2[(x + y * x_size)]) / (1.0 + distinct_value_count);
#elif 0
    int x_size = 2;
    int y_size = 2;
    int distinct_value_count = 4;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    return (1.0 + bayerMatrix2x2[(x + y * x_size)]) / (1.0 + distinct_value_count);
#elif 0
    int x_size = 4;
    int y_size = 4;
    int distinct_value_count = 16;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    return (1.0 + bayerMatrix4x4[(x + y * x_size)]) / (1.0 + distinct_value_count);
#elif 0
    int x_size = 8;
    int y_size = 8;
    int distinct_value_count = 64;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    return (1.0 + bayerMatrix8x8[(x + y * x_size)]) / (1.0 + distinct_value_count);
#elif 0
    int x_size = 8;
    int y_size = 8;
    int distinct_value_count = 64;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    return (1.0 + clusterDotMatrix8x8[(x + y * x_size)]) / (1.0 + distinct_value_count);
#endif
  }

  float dither(float color, float2 xy) {
    float closestColor = (color < 0.5) ? 0 : 1;
    float secondClosestColor = 1 - closestColor;
    float d = indexValue(xy);
    float distance = abs(closestColor - color);
    return (distance < d) ? closestColor : secondClosestColor;
  }

  // num_levels must be >= 2.0
  float ditherQuantized(float color, float num_levels, float2 xy) {
    num_levels -= 1.0;
    float ip = 0;
    float fp = modf(color * num_levels, ip);
    if (ip >= num_levels) { ip = (num_levels - 1.0); fp = 1.0; } // idk if this happens
                                                                 // Here we've converted a value in the range (0.0, 1.0) to an interval ip {0, 1, 2, 3} and a fraction within the range [0.0, 1.0]
#if 0
    fp = dither(fp, xy);
#elif 0
    // This is a weirder one!
    // y is first divided by 2 with floor
    xy.y = floor(xy.y / 2.0);

    int x_size = 4;
    int y_size = 2;
    // This could be simplified since we just have 1 and 0, but eh
    int distinct_value_count = 2;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    float closestColor = (fp < 0.5) ? 0 : 1;
    float secondClosestColor = 1 - closestColor;
    float distance = abs(closestColor - fp);

    // Now we compute a 'layer' instead of having a bayer pattern selection
    int layer = floor((fp * 4.0) + 0.5); // TODO not sure

    float d = (1.0 + jesusMatrix4x2x5[x + (y * x_size) + (layer * x_size * y_size)]) / (1.0 + distinct_value_count);

    fp = (distance < d) ? closestColor : secondClosestColor;
#else // simplified AND CORRECTED version of the above
    xy.y = floor(xy.y / 2.0);

    int x_size = 4;
    int y_size = 2;
    // This could be simplified since we just have 1 and 0, but eh
    int distinct_value_count = 2;

    int x = int(fmod(xy.x, x_size));
    int y = int(fmod(xy.y, y_size));

    float closestColor = (fp < 0.5) ? 0 : 1;
    float distance = (fp < 0.5) ? fp : (1 - fp);

    // Now we compute a 'layer' instead of having a bayer pattern selection
    int layer = floor((fp * 4.0) + 0.5); // TODO not sure

    fp = jesusMatrix4x2x5[x + (y * x_size) + (layer * x_size * y_size)];
#endif

    return clamp((ip + fp) / num_levels, 0.0, 1.0);
  }

  fixed4 frag(v2f i) : SV_Target
  {
    fixed4 col = tex2D(_MainTex, i.uv);

  float2 xy = i.uv * _ScreenParams.xy;

  // Going to do something simple to start with:
  // - convert colour to HSL
  // - dither L channel
  // - convert back to RGB

  // Unclear to me how gamma-correction enters the Unity shader pipeline.
  // It's a project setting??

  // num_levels must be >= 2.0
  // 2.0: 3-bit color
  // 4.0: 6-bit color
  float num_levels = 2.0;

  // just invert the colors
  float3 col_rgb = col.rgb;

#if 0   // dither V
  // NOTE: hsv is what I want - in HSL, L = 1.0 is always pure white;
  // in HSV, V = 1.0 is a strong saturated colour if S = 1.0.

  float3 col_hsv = RGBtoHSV(col_rgb);

  // strategy for > 2 colours in gradient: if colours are A,B,C,D then find which of the three intervals
  // the value falls into and then dither within that interval.

  // quantize the hue channel

  // max out the saturation

  // dither the lightness channel
  col_hsv.z = ditherQuantized(col_hsv.z, num_levels, i.uv);
  // col_hsv.z = dither(col_hsv.z, i.uv);
  col_hsv.z = clamp(col_hsv.z, 0.0, 1.0);

  col_rgb = HSVtoRGB(col_hsv);
#else // dither R, G, B independently
  // TODO for nice-looking patterns, offset R, G, B from each other by 1 px?
  // JESUS II had 3-bit colour (8 colours, each of r,g,b on or off) with iirc a 4x1 dither matrix?
  // Okay, it was fancier than that.
  // First of all, the graphics are all in a 425x240 subwindow. Within that subwindow the palette is 8 primary colours.
  // However, every row is doubled - for the sake of argument let's treat this as a post-process, with an initial image size of 425x120.
  // After scaling, looking at large areas of uniform colour, we see repeating patterns that suggest an underlying matrix of 4x2, 2x4 or 4x4 but not smaller.
  // We also see alternating vertical lines, and checkerboards. We see some patterns that are definitely 4x2 repeating.
  // 4x2 sort of makes sense if this then gets stretched to 4x4. Could simulate by quantising the y value to closest multiple of 2?
  // However it's done, is the matrix is well-balanced so high-threshold red doesn't end up in same place as high-threshold green and blue? Perhaps not, e.g. a 4x2 repeating area:
  //  cyan   red black   red
  //   red black white black
  // Aha, it's not a bayer matrix, it's 3 different patterns for each level (plus empty / full)!
  // Will have to implement later and figure out
  // Also, might not be same patterns everywhere - probably hand-authored to some extent? Options in fill tools, etc?
  // I want to try 3-bit or 6-bit colour

  // especially in RGB mode, even with Project Settings > Player set to 'Linear' rather than 'Gamma',
  // feels like there's a bias towards light vs dark; areas of pure black aren't pure black, etc.
  // Occurs with several different dithering modes.
  // Fixed: return (1.0 + Matrix[k]) / (1.0 + num_distinct_values)
  col_rgb.x = ditherQuantized(col_rgb.x, num_levels, xy + float2(0.0, 0.0));
  col_rgb.y = ditherQuantized(col_rgb.y, num_levels, xy + float2(1.0, 0.0));
  col_rgb.z = ditherQuantized(col_rgb.z, num_levels, xy + float2(0.0, 2.0));
#endif
  col.rgb = col_rgb;
  return col;
  }
    ENDCG
  }
  }
}
