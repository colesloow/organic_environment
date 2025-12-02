// Organic, procedural shader simulating "guts" or "internal organs" appearance.
// Adapted from a Shadertoy shader: https://www.shadertoy.com/view/clXXDl

Shader "Custom/OrganicGuts"
{
    Properties
    {
        // Controls
        _Scale ("Pattern Scale", Float) = 2.0
        _Speed ("Speed", Float) = 1.0
        _Rotation ("Rotation", Float) = 5.0
        _DispAmp ("Displacement Amount", Float) = 0.3
        _DispFreq ("Displacement Scale", Float) = 2.0
        _MainTint ("Main Tint", Color) = (1,0.5,0.25,1)

        // Rendering controls (set per material in the inspector)
        [Enum(Mesh,0, SkySphere,1)]
        _RenderMode ("Render Mode (info)", Float) = 0

        [Enum(Back,2, Front,1, Off,0)]
        _CullMode ("Cull Mode", Float) = 2

        [Enum(On,1, Off,0)]
        _ZWriteMode ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }

        LOD 200

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            Blend One Zero
            Cull [_CullMode]
            ZWrite [_ZWriteMode]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // --------- Structs ---------

            struct Attributes
            {
                float3 positionOS : POSITION; // object-space position
                float3 normalOS   : NORMAL;   // object-space normal
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION; // clip-space position
                float3 positionWS : TEXCOORD0;   // world-space position
                float3 normalWS   : TEXCOORD1;   // world-space normal
                float3 positionOS : TEXCOORD2;   // object-space position (for procedural UVs)
            };

            // --------- Properties ---------

            float _Scale;
            float _Speed;
            float _Rotation;
            float _DispAmp;
            float _DispFreq;
            float4 _MainTint;
            float _RenderMode; // informative only

            // --------- Helpers ---------

            // 2D rotation matrix
            float2x2 Rotate2D(float angle)
            {
                float sineValue;
                float cosineValue;
                sincos(angle, sineValue, cosineValue);
                return float2x2(cosineValue, sineValue, -sineValue, cosineValue);
            }

            // ---------- Pattern Sampling ---------

            // Returns a scalar used to drive vertex displacement
            float SamplePatternScalar(float2 baseUv, float timeValue)
            {
                float2 feedbackOffset = float2(0.0, 0.0);
                float2 phase = float2(0.0, 0.0);
                float2 currentUv = baseUv;

                float radiusSquared = dot(currentUv, currentUv);
                float scaleFactor = 6.0;
                float accumulatedValue = 0.0;

                float2x2 rotationMatrix = Rotate2D(_Rotation);

                // Fewer iterations = cheaper to run in the vertex stage
                [unroll]
                for (int iteration = 0; iteration < 6; iteration++)
                {
                    currentUv = mul(rotationMatrix, currentUv);
                    feedbackOffset = mul(rotationMatrix, feedbackOffset);

                    phase = currentUv * scaleFactor
                          + timeValue * 3.0
                          + sin(timeValue * 3.0 - radiusSquared * 4.0) * 0.6
                          + iteration
                          + feedbackOffset;

                    // Cosine pattern, scaled by the current scaleFactor
                    float2 cosValue = cos(phase);
                    accumulatedValue += dot(cosValue / scaleFactor, float2(0.2, 0.2));

                    // Feedback makes the pattern more organic / turbulent
                    feedbackOffset -= sin(phase);

                    // Increase spatial frequency for the next octave
                    scaleFactor *= 1.3;
                }

                return accumulatedValue;
            }

            // Returns an RGB color (similar to the original Shadertoy "col")
            float3 SamplePatternColor(float2 baseUv, float timeValue)
            {
                float3 color = float3(0.0, 0.0, 0.0);

                float2 feedbackOffset = float2(0.0, 0.0);
                float2 phase = float2(0.0, 0.0);
                float2 currentUv = baseUv;

                float radiusSquared = dot(currentUv, currentUv);
                float scaleFactor = 12.0;
                float accumulatedValue = 0.0;

                float2x2 rotationMatrix = Rotate2D(_Rotation);

                [unroll]
                for (int iteration = 0; iteration < 20; iteration++)
                {
                    currentUv = mul(rotationMatrix, currentUv);
                    feedbackOffset = mul(rotationMatrix, feedbackOffset);

                    phase = currentUv * scaleFactor
                          + timeValue * 4.0
                          + sin(timeValue * 4.0 - radiusSquared * 6.0) * 0.8
                          + iteration
                          + feedbackOffset;

                    float2 cosValue = cos(phase);
                    accumulatedValue += dot(cosValue / scaleFactor, float2(0.2, 0.2));

                    feedbackOffset -= sin(phase);
                    scaleFactor *= 1.2;
                }

                float a = accumulatedValue;

                // color mapping: warm colors multiplied by (a + 0.2), 
                // plus some extra contrast, and minus the radial term
                color = float3(4.0, 2.0, 1.0) * (a + 0.2) + a + a - radiusSquared;
                return color;
            }

            // --------- Vertex ---------

            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 worldPos = TransformObjectToWorld(input.positionOS);
                float3 normalWS = normalize(TransformObjectToWorldNormal(input.normalOS));
                float3 localPos = input.positionOS;

                float timeValue = _Time.y * _Speed;

                // Triplanar mapping for displacement: project object-space position
                // onto the three main planes (YZ, XZ, XY).
                float invDispFreq = 1.0 / max(_DispFreq, 0.0001);

                float2 uvX = localPos.zy * invDispFreq; // projection onto YZ plane
                float2 uvY = localPos.xz * invDispFreq; // projection onto XZ plane
                float2 uvZ = localPos.xy * invDispFreq; // projection onto XY plane

                // Blend weights based on the absolute world normal
                float3 absNormal = abs(normalWS);
                float weightSum = absNormal.x + absNormal.y + absNormal.z + 1e-5;
                float3 blendWeights = absNormal / weightSum;

                // Sample scalar pattern from each projection
                float scalarX = SamplePatternScalar(uvX, timeValue);
                float scalarY = SamplePatternScalar(uvY, timeValue);
                float scalarZ = SamplePatternScalar(uvZ, timeValue);

                // Blend the three scalar values using triplanar weights
                float scalarValue = scalarX * blendWeights.x
                                  + scalarY * blendWeights.y
                                  + scalarZ * blendWeights.z;

                // Map scalar to displacement along the normal
                float displacementStrength = saturate(scalarValue * 0.5 + 0.5) * _DispAmp;
                worldPos += normalWS * displacementStrength;

                output.positionWS = worldPos;
                output.normalWS = normalWS;
                output.positionOS = input.positionOS;
                output.positionCS = TransformWorldToHClip(worldPos);
                return output;
            }

            // --------- Fragment ---------

            half4 frag(Varyings input) : SV_Target
            {
                float3 localPos = input.positionOS;
                float3 normalWS = normalize(input.normalWS);
                float timeValue = _Time.y * _Speed;

                // Triplanar mapping for color, similar to the vertex stage
                float invScale = 1.0 / max(_Scale, 0.0001);

                float2 uvX = localPos.zy * invScale;
                float2 uvY = localPos.xz * invScale;
                float2 uvZ = localPos.xy * invScale;

                float3 absNormal = abs(normalWS);
                float weightSum = absNormal.x + absNormal.y + absNormal.z + 1e-5;
                float3 blendWeights = absNormal / weightSum;

                // Sample full color pattern from each projection
                float3 colorX = SamplePatternColor(uvX, timeValue);
                float3 colorY = SamplePatternColor(uvY, timeValue);
                float3 colorZ = SamplePatternColor(uvZ, timeValue);

                // Triplanar blend of the three color contributions
                float3 color = colorX * blendWeights.x
                             + colorY * blendWeights.y
                             + colorZ * blendWeights.z;

                // Apply biome tint / artistic color
                color *= _MainTint.rgb;
                color = max(color, 0.0);

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack Off
}
