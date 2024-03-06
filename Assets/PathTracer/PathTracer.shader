Shader "Unlit/PathTracer"
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


			int MaxBounceCount;
			int NumRaysPerPixel;
			int Frame;

			float3 ViewParams;
			float4x4 CamLocalToWorldMatrix;

			struct RayTracingMaterial
			{
				float4 colour;
				float4 emissionColor;
				float emissionStrength;
				float smoothness;
			};

			struct Cube
			{
				float3 min;
				float3 max;
				RayTracingMaterial material;
			};

			struct HitInfo
			{
				bool didHit;
				float dst;
				float3 hitPoint;
				float3 normal;
				RayTracingMaterial material;
			};

			struct Ray
			{
				float3 origin;
				float3 dir;
			};


			StructuredBuffer<Cube> Cubes;
			int NumCubes;


			HitInfo RayBoundingBox(Ray ray, float3 p, float3 s)
			{
				float3 m = 1. / ray.dir;
				float3 n = m * (ray.origin - p);
				float3 k = abs(m) * s;
				float3 t1 = -n - k;
				float3 t2 = -n + k;

				float tN = max(max(t1.x, t1.y), t1.z);
				float tF = min(min(t2.x, t2.y), t2.z);

				if (tN > tF || tF < 1e-6) {
					return (HitInfo)0;
				}
				if (tN > 1e-6)
				{
					HitInfo hitInfo;
					hitInfo.dst = tN;
					hitInfo.didHit = true;
					hitInfo.hitPoint = ray.origin + ray.dir * tN;
					hitInfo.normal = -sign(ray.dir) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
					return hitInfo;
				}

				return (HitInfo)0;

			};


			uint NextRandom(inout uint state)
			{
				state = state * 747796405 + 2891336453;
				uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
				result = (result >> 22) ^ result;
				return result;
			}

			float RandomValue(inout uint state)
			{
				return NextRandom(state) / 4294967295.0; // 2^32 - 1
			}

			// Random value in normal distribution (with mean=0 and sd=1)
			float RandomValueNormalDistribution(inout uint state)
			{
				// Thanks to https://stackoverflow.com/a/6178290
				float theta = 2 * 3.1415926 * RandomValue(state);
				float rho = sqrt(-2 * log(RandomValue(state)));
				return rho * cos(theta);
			}



			// Calculate a random direction
			float3 RandomDirection(inout uint state)
			{
				// Thanks to https://math.stackexchange.com/a/1585996
				float x = RandomValueNormalDistribution(state);
				float y = RandomValueNormalDistribution(state);
				float z = RandomValueNormalDistribution(state);
				return normalize(float3(x, y, z));
			}

			HitInfo CalculateRayCollision(Ray ray)
			{
				HitInfo closestHit = (HitInfo)0;
				// We haven't hit anything yet, so 'closest' hit is infinitely far away
				closestHit.dst = 1.#INF;

				// Raycast against all spheres and keep info about the closest hit
				for (int i = 0; i < NumCubes; i++)
				{
					Cube cube = Cubes[i];
					HitInfo hitInfo = RayBoundingBox(ray, cube.min, cube.max / 2);

					if (hitInfo.didHit && hitInfo.dst < closestHit.dst)
					{
						closestHit = hitInfo;
						closestHit.material = cube.material;
					}
				}


				return closestHit;

			}

			float3 Trace(Ray ray, inout uint rngState)
			{
				float3 incomingLight = 0;
				float3 rayColour = 1;

				for (int bounceIndex = 0; bounceIndex <= MaxBounceCount; bounceIndex++)
				{
					HitInfo hitInfo = CalculateRayCollision(ray);

					if (hitInfo.didHit)
					{
						RayTracingMaterial material = hitInfo.material;

						ray.origin = hitInfo.hitPoint;

						float3 diffuseDir = normalize(hitInfo.normal + RandomDirection(rngState));
						float3 specularDir = reflect(ray.dir, hitInfo.normal);
						ray.dir = normalize(lerp(diffuseDir, specularDir, material.smoothness));


						float3 emittedLight = material.emissionColor * material.emissionStrength;
						incomingLight += emittedLight * rayColour;
						rayColour *= material.colour;

						float p = max(rayColour.r, max(rayColour.g, rayColour.b));
						if (RandomValue(rngState) >= p) {
							break;
						}
						rayColour *= 1.0f / p;
					}

				}
				return incomingLight;
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
			   uint2 numPixels = _ScreenParams.xy;
			   uint2 pixelCoord = i.uv * numPixels;
			   uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
			   uint rngState = pixelIndex + Frame * 719393;
			   float3 viewPointLocal = float3(i.uv - 0.5f, 1) * ViewParams;
			   float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

			   Ray ray;
			   ray.origin = _WorldSpaceCameraPos;
			   ray.dir = normalize(viewPoint - ray.origin);

			   float3 totalIncomingLight = 0;

			   for (int rayIndex = 0; rayIndex < NumRaysPerPixel; rayIndex++)
			   {
				   totalIncomingLight += Trace(ray, rngState);
			   }

			    float3 pixelCol = totalIncomingLight / NumRaysPerPixel;

				return float4(pixelCol, 1);
			}
			ENDCG
		}
	}
}
