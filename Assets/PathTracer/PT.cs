using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class PT : MonoBehaviour
{
    public bool denoise;

    [SerializeField, Range(0, 32)] int maxBounceCount = 4;
    [SerializeField, Range(0, 64)] int numRaysPerPixel = 2;

    [SerializeField] int numRenderedFrames;

    [SerializeField] Shader rayTracingShader;
    [SerializeField] Shader temporalShader;

    ComputeBuffer cubeBuffer;

    Material rayTracingMaterial;
    RenderTexture resultTexture;
    Material temporalMaterials;


    public Vector3 camPos;

    [Serializable]
    public struct RayTracingMaterial
    {
        public Color colour;
        public Color emissionColor;
        public float emissionStrength;
        public float smoothness;
    }

    public struct Cube
    {
        public Vector3 min, max;
        public RayTracingMaterial material;
    }

    void Start()
    {
        numRenderedFrames = 0;
    }

    void InitFrame()
    {
        // Create materials used in blits
        ShaderHelper.InitMaterial(rayTracingShader, ref rayTracingMaterial);
        // Create result render texture
        ShaderHelper.CreateRenderTexture(ref resultTexture, Screen.width, Screen.height, FilterMode.Bilinear, ShaderHelper.RGBA_SFloat, "Result");

        // Update data
        Temporal();
        UpdateCameraParams(Camera.current);
        CreateSpheres();
        updateShader();
    }

    void OnRenderImage(RenderTexture src, RenderTexture target)
    {
        bool isSceneCam = Camera.current.name == "SceneCamera";
        numRenderedFrames += 1;

      
        if (isSceneCam)
        {

            InitFrame();
            Graphics.Blit(null, target, rayTracingMaterial);

        }
        else
        {
            if(denoise)
            {
                InitFrame();

                // Create copy of prev frame
                RenderTexture prevFrameCopy = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
                Graphics.Blit(resultTexture, prevFrameCopy);

                // Run the ray tracing shader and draw the result to a temp texture
                rayTracingMaterial.SetInt("Frame", numRenderedFrames);
                temporalMaterials.SetInt("Frame", numRenderedFrames);

                RenderTexture currentFrame = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
                Graphics.Blit(null, currentFrame, rayTracingMaterial);

                if (Camera.main.transform.position == camPos)
                {
                    temporalMaterials.SetTexture("_PrevFrame", prevFrameCopy);

                }
                else
                {
                    temporalMaterials.SetTexture("_PrevFrame", currentFrame);
                    numRenderedFrames = 0;
                    camPos = Camera.main.transform.position;
                }

                Graphics.Blit(currentFrame, resultTexture, temporalMaterials);

                Graphics.Blit(resultTexture, target);

                RenderTexture.ReleaseTemporary(currentFrame);
                RenderTexture.ReleaseTemporary(prevFrameCopy);
                RenderTexture.ReleaseTemporary(currentFrame);
            }
            else
            {
                InitFrame();

                // Create copy of prev frame
                RenderTexture prevFrameCopy = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
                Graphics.Blit(resultTexture, prevFrameCopy);

                // Run the ray tracing shader and draw the result to a temp texture
                rayTracingMaterial.SetInt("Frame", numRenderedFrames);
                RenderTexture currentFrame = RenderTexture.GetTemporary(src.width, src.height, 0, ShaderHelper.RGBA_SFloat);
                Graphics.Blit(null, currentFrame, rayTracingMaterial);


                Graphics.Blit(currentFrame, target);

                RenderTexture.ReleaseTemporary(currentFrame);
                RenderTexture.ReleaseTemporary(prevFrameCopy);
                RenderTexture.ReleaseTemporary(currentFrame);
            }
            


        }

    }
    void updateShader()
    {
       // rayTracingMaterial.SetColor("GroundColor", GroundColor);
       // rayTracingMaterial.SetColor("SkyColorHorizon", SkyColorHorizon);
        //rayTracingMaterial.SetColor("SkyColorZenith", SkyColorZenith);
        rayTracingMaterial.SetFloat("NumRaysPerPixel", numRaysPerPixel);
        rayTracingMaterial.SetFloat("MaxBounceCount", maxBounceCount);
        rayTracingMaterial.SetFloat("Frame", numRenderedFrames);
       // rayTracingMaterial.SetFloat("SunFocus", SunFocus);
       //rayTracingMaterial.SetFloat("SunIntensity", SunIntensity);
      //  rayTracingMaterial.SetFloat("useSkybox", Convert.ToSingle(UseSkybox));
    }

    void UpdateCameraParams(Camera cam)
    {
        float planeHeight = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
        float planeWidth = planeHeight * cam.aspect;
        // Send data to shader
        rayTracingMaterial.SetVector("ViewParams", new Vector3(planeWidth, planeHeight, cam.nearClipPlane));
        rayTracingMaterial.SetMatrix("CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);
    }


    void CreateSpheres()
    {
        // Create sphere data from the sphere objects in the scene
        TracedCube[] sphereObjects = FindObjectsOfType<TracedCube>();
        Cube[] spheres = new Cube[sphereObjects.Length];

        for (int i = 0; i < sphereObjects.Length; i++)
        {
            spheres[i] = new Cube()
            {
                min = sphereObjects[i].transform.position,
                max = sphereObjects[i].transform.lossyScale,
                material = sphereObjects[i].material
            };
        }

        // Create buffer containing all sphere data, and send it to the shader
        ShaderHelper.CreateStructuredBuffer(ref cubeBuffer, spheres);
        rayTracingMaterial.SetBuffer("Cubes", cubeBuffer);
        rayTracingMaterial.SetInt("NumCubes", sphereObjects.Length);
    }

    void Temporal()
    {
        ShaderHelper.InitMaterial(temporalShader, ref temporalMaterials);
    }
}
