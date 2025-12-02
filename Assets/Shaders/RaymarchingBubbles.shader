// A Unity shader that renders animated bubbles inside a spherical container using raymarching and signed distance functions (SDF).
// The shader supports multiple bubbles with smooth blending, dynamic lighting, and depth-based attenuation.
// Inspired by shadertoy: https://www.shadertoy.com/view/3sySRK

Shader "Custom/RaymarchingBubbles"
{
    Properties
{
    // GENERAL
    [Header(General Settings)] [Space(5)]
    _ContainerRadius("Container Radius (Object Space)", Float) = 0.5

    // BUBBLES
    [Header(Bubble Settings)] [Space(5)]
    _BubbleColor("Global Bubble Tint", Color) = (1, 0.5, 0.25, 1)
    _BubbleRadius("Bubble Radius (OS)", Float) = 0.18

    [Range(1,16)]
    _BubbleCount("Number of Bubbles", Float) = 4

    _BubbleSpeed("Bubble Movement Speed", Float) = 1.0
    _BubbleAmplitude("Bubble Offset Amplitude (OS)", Vector) = (0.25, 0.25, 0.25, 0)

    // RAYMARCHING
    [Header(Raymarching Settings)] [Space(5)]
    _SmoothK("Smooth Union Width", Float) = 0.15

    _StepCount("Raymarch Step Count", Float) = 72
    _HitEpsilon("Surface Hit Threshold", Float) = 0.001

    _Density("Depth Color Density", Float) = 0.25

    // LIGHTING (BLINN-PHONG)
    [Header(Lighting Settings (Blinn Phong))] [Space(5)]
    _AmbientStrength("Ambient Strength", Float) = 0.2
    _SpecularStrength("Specular Strength", Float) = 0.6
    _SpecularPower("Specular Power", Float) = 32.0

    // ALPHA / TRANSPARENCY
    [Header(Transparency Settings)] [Space(5)]
    [Range(0,1)]
    _Opacity("Base Opacity", Range(0,1)) = 1.0

    [Range(0,1)]
    _AlphaDepthFactor("Depth-based Alpha Influence", Range(0,1)) = 0.3
}

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }

        LOD 150

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

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
            float  _BubbleCount;
            float  _SmoothK;

            float  _StepCount;
            float  _HitEpsilon;
            float  _Density;

            float  _BubbleSpeed;
            float4 _BubbleAmplitude;

            float  _AmbientStrength;
            float  _SpecularStrength;
            float  _SpecularPower;

            float  _Opacity;
            float  _AlphaDepthFactor;

            static const int MAX_BUBBLES = 16;

            // Palette from C# script
            float4 _BubbleColors[MAX_BUBBLES];

            // ---------- SDF helpers ----------

            // SDF of a sphere at origin
            float SdSphere(float3 p, float radius)
            {
                return length(p) - radius;
            }

            // Smooth union of two distances, reuse same "h" to mix color
            float SmoothUnionDistance(float d1, float d2, float k, out float h)
            {
                h = saturate(0.5 + 0.5 * (d2 - d1) / k);
                return lerp(d2, d1, h) - k * h * (1.0 - h);
            }

            // Smooth union without returning "h"
            float SmoothUnionDistanceNoH(float d1, float d2, float k)
            {
                float h;
                return SmoothUnionDistance(d1, d2, k, h);
            }

            // Calculate bubble center in object space
            float3 BubbleCenterOS(int i, float timeValue, float maxOffset)
            {
                float fi = (float)i;
                float3 amp = _BubbleAmplitude.xyz;

                float3 center;
                center.x = sin(timeValue * 0.7  + fi * 1.123) * amp.x;
                center.y = sin(timeValue * 0.9  + fi * 2.357 + 1.3) * amp.y;
                center.z = sin(timeValue * 0.53 + fi * 3.713 + 2.1) * amp.z;

                if (length(center) > maxOffset && maxOffset > 0.0)
                    center = normalize(center) * maxOffset;

                return center;
            }

            // SDF field + colors mixed depending on smooth union
            float MapBubbles(float3 pOS, float timeValue, out float3 outColor)
            {
                int count = (int)round(_BubbleCount);
                count = clamp(count, 1, MAX_BUBBLES);

                float maxOffset = max(0.0, _ContainerRadius - _BubbleRadius);

                float d = 1e6;
                float3 col = 0.0;
                bool first = true;

                [loop]
                for (int i = 0; i < MAX_BUBBLES; i++)
                {
                    if (i >= count) break;

                    float3 center = BubbleCenterOS(i, timeValue, maxOffset);
                    float dSphere = SdSphere(pOS - center, _BubbleRadius);

                    // color of this bubble (palette + global tint)
                    float3 bubbleCol = _BubbleColors[i].rgb * _BubbleColor.rgb;

                    if (first)
                    {
                        d = dSphere;
                        col = bubbleCol;
                        first = false;
                    }
                    else
                    {
                        float h;
                        float newD = SmoothUnionDistance(d, dSphere, _SmoothK, h);

                        // h close to 1 => keep old field/color
                        // h close to 0 => take new field/color
                        col = lerp(bubbleCol, col, h);
                        d = newD;
                    }
                }

                outColor = col;
                return d;
            }

            // Distance function without color
            float DistanceBubbles(float3 pOS, float timeValue)
            {
                float3 dummy;
                return MapBubbles(pOS, timeValue, dummy);
            }

            // Calculate normal via central differences
            float3 CalcNormal(float3 pOS, float timeValue)
            {
                const float h = 0.002;

                float3 ex = float3(h, 0, 0);
                float3 ey = float3(0, h, 0);
                float3 ez = float3(0, 0, h);

                float dx = DistanceBubbles(pOS + ex, timeValue) - DistanceBubbles(pOS - ex, timeValue);
                float dy = DistanceBubbles(pOS + ey, timeValue) - DistanceBubbles(pOS - ey, timeValue);
                float dz = DistanceBubbles(pOS + ez, timeValue) - DistanceBubbles(pOS - ez, timeValue);

                return normalize(float3(dx, dy, dz));
            }

            // Ray-sphere intersection in object space
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

            // Vertex shader
            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 worldPos = TransformObjectToWorld(input.positionOS);
                output.positionWS = worldPos;
                output.positionCS = TransformWorldToHClip(worldPos);
                return output;
            }

            // Fragment shader
            half4 frag(Varyings input) : SV_Target
            {
                float3 worldPos = input.positionWS;

                float3 roWS = _WorldSpaceCameraPos;
                float3 rdWS = normalize(worldPos - roWS);

                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                float timeValue = _Time.y * _BubbleSpeed;

                // Ray-sphere intersection to limit raymarching inside container
                float tEnter, tExit;
                if (!RaySphere(roOS, rdOS, _ContainerRadius, tEnter, tExit))
                    return half4(0, 0, 0, 0);

                if (tEnter < 0.0) tEnter = 0.0;

                float t = tEnter;
                float dist = 0.0;
                float3 pOS = roOS;

                float3 bubbleColorMixed = 0.0;

                int maxSteps = (int)_StepCount;

                [loop]
                for (int i = 0; i < maxSteps; i++)
                {
                    if (t > tExit) break;

                    pOS = roOS + rdOS * t;

                    // Get distance to closest bubble and mixed color
                    dist = MapBubbles(pOS, timeValue, bubbleColorMixed);

                    if (dist < _HitEpsilon) break;

                    t += dist;

                    if (t > tExit) break;
                }

                // If no hit
                if (t > tExit || dist > _HitEpsilon * 4.0)
                    return half4(0, 0, 0, 0);

                float3 hitOS = roOS + rdOS * t;
                float3 hitWS = mul(unity_ObjectToWorld, float4(hitOS, 1.0)).xyz;

                float3 normalOS = CalcNormal(hitOS, timeValue);
                float3 normalWS = normalize(mul((float3x3)unity_ObjectToWorld, normalOS));

                // Blinn-Phong
                float3 lightDirWS = normalize(float3(0.577, 0.577, 0.577));
                float3 viewDirWS  = normalize(_WorldSpaceCameraPos - hitWS);

                float ndotl = saturate(dot(normalWS, lightDirWS));
                float diffuse = ndotl;

                float3 halfDir = normalize(lightDirWS + viewDirWS);
                float ndoth = saturate(dot(normalWS, halfDir));
                float spec = pow(ndoth, _SpecularPower) * _SpecularStrength;

                float ambient = _AmbientStrength;

                float3 lighting = ambient + diffuse + spec;

                float3 col = bubbleColorMixed * lighting;

                // Depth-based attenuation
                float depthInside = t - tEnter;
                float depthTotal = max(tExit - tEnter, 0.0001);
                float depth01 = saturate(depthInside / depthTotal);

                col *= exp(-depthInside * _Density);

                // Alpha
                float alphaDepth = 1.0 - depth01;
                float alpha = lerp(1.0, alphaDepth, _AlphaDepthFactor);
                alpha *= _Opacity;
                alpha = saturate(alpha);

                return half4(col, alpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
