Shader "Custom/SingleBubbleVolume"
{
    Properties
    {
        _BubbleColor     ("Bubble Color", Color) = (1, 0.5, 0.25, 1)
        _ContainerRadius ("Container Radius (OS)", Float) = 0.5
        _BubbleRadius    ("Bubble Radius (OS)", Float) = 0.25
        _StepCount       ("Raymarch Steps", Float) = 64
        _HitEpsilon      ("Hit Epsilon", Float) = 0.001
        _Density         ("Depth Density", Float) = 0.2
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }

        LOD 100

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back        // Front if you want only inside view

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            float4 _BubbleColor;
            float  _ContainerRadius;
            float  _BubbleRadius;
            float  _StepCount;
            float  _HitEpsilon;
            float  _Density;

            // Signed distance to a sphere centered at origin
            float SdSphere(float3 p, float radius)
            {
                return length(p) - radius;
            }

            // Ray / sphere intersection (sphere centered at origin)
            bool RaySphere(float3 ro, float3 rd, float radius, out float tEnter, out float tExit)
            {
                float3 oc = ro;
                float b = dot(oc, rd);
                float c = dot(oc, oc) - radius * radius;
                float disc = b * b - c;

                if (disc < 0.0)
                {
                    tEnter = 0.0;
                    tExit  = 0.0;
                    return false;
                }

                float s = sqrt(disc);
                float t0 = -b - s;
                float t1 = -b + s;

                tEnter = min(t0, t1);
                tExit  = max(t0, t1);
                return true;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 worldPos = TransformObjectToWorld(input.positionOS);
                output.positionWS = worldPos;
                output.positionCS = TransformWorldToHClip(worldPos);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float3 worldPos = input.positionWS;

                // World-space ray from camera to this pixel
                float3 roWS = _WorldSpaceCameraPos;
                float3 rdWS = normalize(worldPos - roWS);

                // Transform ray into object space
                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                // Intersect ray with container sphere in object space
                float tEnter, tExit;
                if (!RaySphere(roOS, rdOS, _ContainerRadius, tEnter, tExit))
                {
                    // Ray never enters the container volume
                    return half4(0, 0, 0, 0);
                }

                // If camera is inside the container, start at t = 0
                if (tEnter < 0.0) tEnter = 0.0;

                float t = tEnter;
                float dist = 0.0;
                float3 pOS = roOS;

                int maxSteps = (int)_StepCount;

                // Simple sphere SDF: single bubble at the origin
                [loop]
                for (int i = 0; i < maxSteps; i++)
                {
                    if (t > tExit) break;

                    pOS = roOS + rdOS * t;

                    dist = SdSphere(pOS, _BubbleRadius);

                    // We reached the bubble surface
                    if (dist < _HitEpsilon)
                        break;

                    t += dist;

                    if (t > tExit) break;
                }

                // If we left the container or never got close enough, nothing to show
                if (t > tExit || dist > _HitEpsilon * 4.0)
                {
                    return half4(0, 0, 0, 0);
                }

                // Hit position in object and world space
                float3 hitOS = roOS + rdOS * t;
                float3 hitWS = mul(unity_ObjectToWorld, float4(hitOS, 1.0)).xyz;

                // Normal for a sphere SDF is simply p normalized
                float3 normalOS = normalize(hitOS);
                float3 normalWS = normalize(mul((float3x3)unity_ObjectToWorld, normalOS));

                // Simple directional light
                float3 lightDirWS = normalize(float3(0.577, 0.577, 0.577));
                float ndotl = saturate(dot(normalWS, lightDirWS));
                float diffuse = 0.3 + 0.7 * ndotl;

                float3 col = _BubbleColor.rgb * diffuse;

                // Depth inside the container: closer to camera = more opaque
                float depthInside = t - tEnter;
                float depthTotal = max(tExit - tEnter, 0.0001);
                float depth01 = saturate(depthInside / depthTotal);

                // Exponential attenuation to suggest thickness
                col *= exp(-depthInside * _Density);

                // Alpha based on relative depth: front of the bubble more solid
                float alpha = 1.0 - depth01;
                alpha = saturate(alpha);

                return half4(col, alpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
