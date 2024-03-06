Shader "Unlit/Denoise"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
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
			sampler2D _PrevFrame;
			int Frame;

			fixed4 frag(v2f i) : SV_Target
			{
				float4 col = tex2D(_MainTex, i.uv);
				float4 colPrev = tex2D(_PrevFrame, i.uv);
				float4 blendedFrame;
				if (col.x + col.y + col.z < .01f && colPrev.x + colPrev.y + colPrev.z > .0001f)
				{
					float2 newUv1 = i.uv;
					float2 newUv2 = i.uv;
					float2 newUv3 = i.uv;
					newUv1.x + 1;
					newUv2.y + 1;
					newUv3.x - 1;

					float4 blendFrame1, blendFrame2, blendFrame3, blendFrame4, blendFrame5;
					blendFrame1 = tex2D(_PrevFrame, newUv1);
					blendFrame2 = tex2D(_PrevFrame, newUv2);
					blendFrame3 = tex2D(_PrevFrame, newUv3);

					blendedFrame = (blendFrame1 + blendFrame2 + blendFrame3) / 3;
					Frame -= 1;
				}
				else
				{
					float weight = 1.0 / (Frame + 1);

					blendedFrame = saturate(colPrev * (1 - weight) + col * weight);

				}
				return blendedFrame;
			}
			ENDCG
		}
	}
}
