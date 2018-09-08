Shader "Unlit/NewUnlitShader"
{
	Properties
	{
    // TODO: define a built-in, world-space light...? And then a camera matrix I guess? And then calculate standard gouraud shading? Or use fresnel-style eqn like TomR did, if that's different.
    // TODO: also need the normals. Should be available in the vertex data and interpolatable across polygon? Although a 'correct' normal would actually be per-face but idk how this works.
    // TODO: I have my 4 cols, for a first step I should set...thresholds for each col? Ignore dither.
    // TODO: I think you can set a custom property editor? Need to look at docs again.
    // A: Yes. See https://docs.unity3d.com/Manual/SL-CustomShaderGUI.html
    // TODO: Can I parametrise this on the number of colours and have them show up well in the editor?
    // A: You can't define an array property. It can be defined in the shader and passed programatically but won't be accessible in the material editor.
    // Options are: stick with 4, which I'm tempted to do; or use a 2D texture, in which case I might have to worry about unintentional interpolation.
    // If using a texture, could make it 1xN to just set a gradient. Would have to check size matches tone map. Or could make it 3x2N, first column for the colour, second and third for the dither pattern.
    // Or actually at that point... make it 2x2N, directly draw the dither? Have texture be in 2 pixel high 'chunks'.
    // If we do that though: either tone map needs to be in terms of input light value, and so we could be mapping two different tones to the same 'colour' and it's no longer close to a palletised impl.
    // Or the texture needs to output an index (can we define a greyscale tex?) which is then used to index into palette. That makes the texture somewhat more reusable.
    // TODO: Change screen-space shader to do its tone mapping...? Crap no, because once a pixel is output I don't know if it was col1 or col4. So need to pass in tone map.
    // TODO: Will have a default one, and then change it programatically.
    _Color1 ("Color 1", Color) = (0.0, 0.0, 0.0, 1.0)
    _Color2 ("Color 2", Color) = (0.33, 0.33, 0.33, 1.0)
    _Color3 ("Color 3", Color) = (0.66, 0.66, 0.66, 1.0)
    _Color4 ("Color 4", Color) = (1.0, 1.0, 1.0, 1.0)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

      float4 _Color1;
      float4 _Color2;
      float4 _Color3;
      float4 _Color4;
      
			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return _Color1;
			}
			ENDCG
		}
	}
}
