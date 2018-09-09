Shader "Dither/DefaultDither"
{
	Properties
	{
    // TODO: define a built-in, world-space light...? And then a camera matrix I guess? And then calculate standard gouraud shading? Or use fresnel-style eqn like TomR did, if that's different.
    // TODO: also need the normals. Should be available in the vertex data and interpolatable across polygon? Although a 'correct' normal would actually be per-face but idk how this works.
    // TODO: I think you can set a custom property editor? Need to look at docs again.
    // A: Yes. See https://docs.unity3d.com/Manual/SL-CustomShaderGUI.html
    // TODO: Can I parametrise this on the number of colours and have them show up well in the editor?
    // A: You can't define an array property. It can be defined in the shader and passed programatically but won't be accessible in the material editor.
    // Options are: stick with 4, which I'm tempted to do; or use a 2D texture, in which case I might have to worry about unintentional interpolation.
    // If using a texture, could make it 1xN to just set a gradient. Would have to check size matches tone map. Or could make it 3x2N, first column for the colour, second and third for the dither pattern.
    // Or actually at that point... make it 2x2N, directly draw the dither? Have texture be in 2 pixel high 'chunks'.
    // If we do that though: either tone map needs to be in terms of input light value, and so we could be mapping two different tones to the same 'colour' and it's no longer close to a palletised impl.
    // Or the texture needs to output an index (can we define a greyscale tex?) which is then used to index into palette. That makes the texture somewhat more reusable.
    // NOTE: in general branchy code in shaders is bad, using a texture as a lookup table should be cheaper if my understanding is correct.
    // To make palette index texture more visually obvious, could use 0, 64, 128, 192 as the colours and then divide by 64?
    // For alpha, need a texture made of 2x2 blocks, which then has lum in one axis and alpha in the other axis, and either has the 4-index channel and an alpha channel, or has a 5-index lookup where 
    // the 5th index is always a fully transparent colour.
    // NOTE: In the Unity properties for the texture, set the mode to 'Point' for nearest-neighbour.
    // TODO: Change screen-space shader to do its tone mapping...? Crap no, because once a pixel is output I don't know if it was col1 or col4. So need to pass in tone map.
    // TODO: Will have a default one, and then change it programatically.

    _BlockWidth ("Dither Block Width", Int) = 2
    _BlockHeight ("Dither Block Height", Int) = 2
    _PaletteSize ("Palette Size", Int) = 4

    _DebugLightX ("Debug Light X", Float) = 0.5
    _DebugLightY ("Debug Light Y", Float) = 0.5
    _DebugLightZ ("Debug Light Z", Float) = 0.5

    // A single-channel texture, _BlockWidth x (_BlockHeight * _PaletteSize) e.g. 2x26 [for 2x2 blocksize and 4 colours], I think I want to lookup 'red' in the sampler.
    // Contains 8-bit values 0, 64, 128, or 192. Divide by 64 (round 255/_PaletteSize to the nearest power of 2) to give a colour index. Colour index will then index into 1x4 RGB texture.
    // Should be set to clamp and point sample.
    [NoScaleOffset] _DitherTex ("Dither Texture", 2D) = "dither_texture" {}
    // An RGB (sRGB? Linear? Need to look up how this works...) texture, 1x4 [for 4 colours]. Lookup via index from dither texture.
    // Should be set to clamp and point sample.
    [NoScaleOffset] _PaletteTex("Palette Texture", 2D) = "body_texture" {}

    // TODO [NoScaleOffset] _TonePaletteTex("Tone Palette Texture", 2D) = "tone_texture" {}

    // NOTE: if a texture is 1x4 then pixel centers are at (0.5, 0.5), (0.5, 1.5), (0.5, 2.5) and (0.5, 3.5). These should then be converted to UV coords by dividing by the texture size in pixels.

    // NOTE: Okay, if I have textures for all these things then I could #define BLOCK_HEIGHT, BLOCK_WIDTH, PALETTE_SIZE.
  }

  SubShader
  {
    Tags { "RenderType" = "Opaque" }
    LOD 100

    Pass
    {
      CGPROGRAM
      #pragma target 3.0
      #pragma vertex vert
      #pragma fragment frag

      #include "UnityCG.cginc"

      float _DebugLightX;
      float _DebugLightY;
      float _DebugLightZ;
      
      float _BlockWidth;
      float _BlockHeight;
      float _PaletteSize;
      // TODO conditionally compile in checks that test for texture sizes (available as special Unity variables) being correct, otherwise make all pixels magenta?

      sampler2D _DitherTex;
      float4 _DitherTex_TexelSize;
      sampler2D _PaletteTex;
      float4 _PaletteTex_TexelSize;
  
			struct v2f
			{
        // TODO I think to get flat shading I will have to split verts and recalculate normals; might be possible in the unity import settings.
        float3 normal : NORMAL;
			};

      // TODO use to compute scaling factor instead of hardcoded 64
      float round_to_pow2(float x)
      {
        return pow(2.0, floor(log2(x)));
      }

      v2f vert(
        // TODO I'm using an output var because it's what the Unity example says you have to do for VPOS,
        // I don't really understand
        float4 vertex : POSITION, // vertex position input
        float3 normal : NORMAL,
        out float4 outpos : SV_POSITION // clip space position output
      )
      {
        v2f o;
        o.normal = normal;
        outpos = UnityObjectToClipPos(vertex);
        return o;
      }
			
      // NOTE converting from pixel pos to UV of pixel centers:
      // pos_px / (size_px - 1)

      float2 get_pixel_center_from_uv(float2 pos_px, float2 inverse_size_px) {
        return (pos_px + float2(0.5, 0.5)) * inverse_size_px;
      }

      // NOTE Texture size
      // { TextureName }_TexelSize - a float4 property contains texture size information :
      // x contains 1.0 / width
      // y contains 1.0 / height
      // z contains width
      // w contains height

      // NOTE had a problem here because that result of tex2D isn't 0-255 but 0-1 no matter the datatype I use!
      // Should revisit exactly what conversions are happening here to make sure result is accurate.

			fixed4 frag (v2f i, UNITY_VPOS_TYPE screenPos : VPOS) : SV_Target
      {
        float3 light_vec = float3(_DebugLightX, _DebugLightY, _DebugLightZ);
        float3 light_brightness = length(light_vec);
        float3 light_dir = normalize(light_vec);
        
        // float lightness = _DebugLightness;
        float lightness = dot(light_dir, i.normal);

        // TODO version with screenPos.x % _BlockWidth doesn't work, giving stripes...
        float2 _BlockSize = { _BlockWidth, _BlockHeight };
        // float2 dither_offset_px = fmod(screenPos.xy, _BlockSize);
        float2 dither_offset_px = floor(frac(screenPos.xy / _BlockSize) * _BlockSize);

        // TODO var for number of dither intermediates, currently 4 below is because we have 3 intermediates
        float block_count = 1 + 4 * (_PaletteSize - 1);
        float block_idx = round(lightness * (block_count - 1));

        float2 dither_tex_px = { dither_offset_px.x, dither_offset_px.y + _BlockHeight * block_idx };
        float2 dither_tex_uv = get_pixel_center_from_uv(dither_tex_px, _DitherTex_TexelSize.xy);
        
        float index = tex2D(_DitherTex, dither_tex_uv).r;

        // TODO use round_to_pow2 above to compute the 64.0
        float2 palette_pos_px = { 0.0, ((255.0 * index) / 64.0) };
        float2 palette_pos_uv = get_pixel_center_from_uv(palette_pos_px, _PaletteTex_TexelSize.xy);
        fixed4 color = tex2D(_PaletteTex, palette_pos_uv);
        return color;
			}
			ENDCG
		}
	}
}
