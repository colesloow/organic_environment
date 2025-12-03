// Procedural, triplanar viscus shader
// Inspiration: https://www.shadertoy.com/view/tt2XDV

Shader "Custom/ViscusTriplanar"
{
    Properties
    {
        _Scale("Pattern Scale (frequency)", Float) = 2.0
        _Speed("Speed", Float) = 1.0
        _Sharpness("Height Sharpness", Float) = 3.0
        _TriBlendPower("Triplanar Blend Power", Float) = 4.0
        _MainTint("Main Tint", Color) = (1,0.4,0.3,1)

        [Enum(Back,2, Front,1, Off,0)]
        _CullMode("Cull Mode", Float) = 2

        [Enum(On,1, Off,0)]
        _ZWriteMode("ZWrite", Float) = 1
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
                float3 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
            };

            // --------- Properties ---------

            float  _Scale;
            float  _Speed;
            float  _Sharpness;
            float  _TriBlendPower;
            float4 _MainTint;

            // --------- Utilitaries ---------

            float2 hash(float2 x)
            {
                const float2 k = float2(0.3183099, 0.3678794);
                x = x * k + k.yx;
                return -1.0 + 2.0 * frac(16.0 * k * frac(x.x * x.y * (x.x + x.y)));
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                float2 u = f * f * (3.0 - 2.0 * f);

                float n00 = dot(hash(i + float2(0.0, 0.0)), f - float2(0.0, 0.0));
                float n10 = dot(hash(i + float2(1.0, 0.0)), f - float2(1.0, 0.0));
                float n01 = dot(hash(i + float2(0.0, 1.0)), f - float2(0.0, 1.0));
                float n11 = dot(hash(i + float2(1.0, 1.0)), f - float2(1.0, 1.0));

                float nx0 = lerp(n00, n10, u.x);
                float nx1 = lerp(n01, n11, u.x);
                return lerp(nx0, nx1, u.y);
            }

            float heightmap(float2 p, float t)
            {
                float h = 0.0;
                float2 q = 4.0 * p + noise(-4.0 * p + t * float2(-0.07, 0.03));
                float2 r = 7.0 * p + float2(37.0, 59.0) + noise(5.0 * p + t * float2(0.08, 0.03));
                float2 s = 3.0 * p + noise(5.0 * p + t * float2(0.10, 0.05) + float2(13.0, 37.0));
                float smoothAbs = 0.2;

                h += 1.0 * noise(s);
                h += 0.9 * pow(abs(noise(q)), 1.0 + smoothAbs);
                h += 0.7 * pow(abs(noise(r)), 1.0 + smoothAbs);

                h = 0.65 * h + 0.33;
                return h;
            }

            float3 getColor(float x)
            {
                float3 a = float3(0.1, 0.0, 0.03);
                float3 b = float3(1.0, 0.05, 0.07);
                float3 c = float3(0.9, 0.2, 0.3);
                return lerp(a, lerp(b, c, smoothstep(0.4, 0.9, x)), smoothstep(0.0, 0.9, x));
            }

            // Triplanar sampling of a scalar
            float SampleHeightTriplanar(float3 localPos, float3 normalWS, float scale, float t, float blendPower)
            {
                // scale = frequency
                float2 uvX = localPos.zy * scale; // YZ
                float2 uvY = localPos.xz * scale; // XZ
                float2 uvZ = localPos.xy * scale; // XY

                float3 absN = abs(normalWS);
                // Blend power > 1: make dominant axis stronger
                float3 w = pow(absN, blendPower);
                float weightSum = w.x + w.y + w.z + 1e-5;
                w /= weightSum;

                float hX = heightmap(uvX, t);
                float hY = heightmap(uvY, t);
                float hZ = heightmap(uvZ, t);

                return hX * w.x + hY * w.y + hZ * w.z;
            }

            // --------- Vertex ---------

            Varyings vert(Attributes input)
            {
                Varyings o;

                float3 localPos = input.positionOS;
                float3 worldPos = TransformObjectToWorld(localPos);
                float3 normalWS = normalize(TransformObjectToWorldNormal(input.normalOS));

                o.positionWS = worldPos;
                o.normalWS   = normalWS;
                o.positionOS = localPos;
                o.positionCS = TransformWorldToHClip(worldPos);
                return o;
            }

            // --------- Fragment ---------

            half4 frag(Varyings i) : SV_Target
            {
                float3 localPos = i.positionOS;
                float3 normalWS = normalize(i.normalWS);
                float3 worldPos = i.positionWS;

                float timeValue = _Time.y * _Speed;

                // Flip normal if backfacing
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - worldPos);
                if (dot(normalWS, viewDirWS) < 0.0)
                    normalWS = -normalWS;

                // Triplanar Height
                float scale = max(_Scale, 0.0001);
                float blendPower = max(_TriBlendPower, 1.0);
                float h = SampleHeightTriplanar(localPos, normalWS, scale, timeValue, blendPower);

                float sharp = max(_Sharpness, 0.01);
                float hSharp = pow(saturate(h), sharp);

                // Base color
                float3 mat = getColor(hSharp);
                mat = clamp(mat, 0.0, 1.0);

                // Fake lighting
                float3 ld = normalize(float3(1.0, -1.0, 1.0));        // light dir
                float3 ha = normalize(ld - float3(0.0, 0.0, -1.0));   // half-vector

                float3 nor = normalWS;

                float ndl = max(dot(nor, -ld), 0.0);
                float ndh = max(dot(nor, ha), 0.0);

                float spec1 = pow(ndl, 3.0);
                float spec2 = pow(ndh, 20.0);

                float3 col = 0.0;
                col += mat * 0.8;
                col += 0.2 * mat * spec1;
                col += 0.3 * hSharp * spec2;

                // Global tint
                col *= _MainTint.rgb;
                col = max(col, 0.0);

                return half4(col, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
