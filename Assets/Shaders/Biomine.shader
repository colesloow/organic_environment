// Raymarching "Biomine" style tunnel inside a mesh (object-space raymarch).
// URP, unlit, controllable culling and ZWrite, with internal world scaling.
// Original shader from Shadertoy: https://www.shadertoy.com/view/4lyGzR

Shader "Custom/Biomine_ObjectRaymarch_URP_Scaled_Controls"
{
    Properties
    {
        _TimeScale("Time Scale", Float) = 1.0
        _Brightness("Brightness", Float) = 1.0
        _WorldScale("Internal World Scale", Range(0.0, 1.0)) = 1.0

        // Rendering controls (material-driven)
        [Enum(Mesh,0, SkySphere,1)]
        _RenderMode("Render Mode (info)", Float) = 0

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
            "Queue"="Geometry"
            "RenderPipeline"="UniversalPipeline"
        }

        Pass
        {
            Name "Forward"
            Tags{ "LightMode" = "UniversalForwardOnly" }

            // These are controlled per material from the inspector
            Cull   [_CullMode]
            ZWrite [_ZWriteMode]
            Blend One Zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // User parameters
            float _TimeScale;
            float _Brightness;
            float _WorldScale;

            float _RenderMode;   // Mesh / SkySphere (info, not used yet)
            float _CullMode;     // Back / Front / Off (drives Cull state above)
            float _ZWriteMode;   // On / Off (drives ZWrite state above)

            static const float FAR = 50.0;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 worldPos    : TEXCOORD1;
            };

            // ------------------------------------------------
            // Utility functions
            // ------------------------------------------------

            float hash(float n) { return frac(cos(n) * 45758.5453); }

            float2x2 rot2(float a)
            {
                float2 v = sin(float2(1.570796, 0.0) + a);
                return float2x2(
                    v.x,  v.y,
                   -v.y,  v.x
                );
            }

            // ------------------------------------------------
            // 3D value noise
            // ------------------------------------------------

            float noise3D(float3 p)
            {
                const float3 s = float3(7.0, 157.0, 113.0);
                float3 ip = floor(p);
                p -= ip;

                float n = dot(ip, s);
                float4 h = float4(0.0, s.y, s.z, s.y + s.z) + n;

                p = p * p * (3.0 - 2.0 * p);

                float4 sinH  = sin(h) * 43758.5453;
                float4 sinH2 = sin(h + s.x) * 43758.5453;

                float4 hmix = lerp(frac(sinH), frac(sinH2), p.x);
                hmix.xy = lerp(hmix.xz, hmix.yw, p.y);

                return lerp(hmix.x, hmix.y, p.z);
            }

            // ------------------------------------------------
            // Cellular tile helper
            // ------------------------------------------------

            float drawSphere(float3 p)
            {
                p = frac(p) - 0.5;
                return dot(p, p);
            }

            float cellTile(float3 p)
            {
                float4 v, d;

                d.x = drawSphere(p - float3(0.81, 0.62, 0.53));
                p.xy = float2(p.y - p.x, p.y + p.x) * 0.7071;
                d.y = drawSphere(p - float3(0.39, 0.20, 0.11));
                p.yz = float2(p.z - p.y, p.z + p.y) * 0.7071;
                d.z = drawSphere(p - float3(0.62, 0.24, 0.06));
                p.xz = float2(p.z - p.x, p.z + p.x) * 0.7071;
                d.w = drawSphere(p - float3(0.20, 0.82, 0.64));

                v.xy = min(d.xz, d.yw);
                v.z  = min(max(d.x, d.y), max(d.z, d.w));
                v.w  = max(v.x, v.y);

                d.x = min(v.z, v.w) - min(v.x, v.y);
                return d.x * 2.66;
            }

            // ------------------------------------------------
            // Path (for tunnel bending)
            // ------------------------------------------------

            float2 path(float z)
            {
                float a = sin(z * 0.11);
                float b = cos(z * 0.14);
                return float2(a * 4.0 - b * 1.5, b * 1.7 + a * 1.5);
            }

            float smaxP(float a, float b, float s)
            {
                float h = clamp(0.5 + 0.5 * (a - b) / s, 0.0, 1.0);
                return lerp(b, a, h) + h * (1.0 - h) * s;
            }

            // ------------------------------------------------
            // Scene SDF in object space + internal scale
            // ------------------------------------------------

            float mapScene(float3 p, out float objID)
            {
                // p is in object space of the mesh
                // Internal world scaling: >1 = smaller world, <1 = larger world
                p *= _WorldScale;

                p.xy -= path(p.z);
                p += cos(p.zxy * 1.5707963) * 0.2;

                float d = dot(cos(p * 1.5707963), sin(p.yzx * 1.5707963)) + 1.0;

                float iTime = _Time.y * _TimeScale;
                float3 sinArg = p * 1.0 + iTime * 6.283 + sin(p.yzx * 0.5);
                float bio = d + 0.25 + dot(sin(sinArg), float3(0.033, 0.033, 0.033));

                float tun = smaxP(
                    3.25 - length(p.xy - float2(0.0, 1.0)) + 0.5 * cos(p.z * 3.14159 / 32.0),
                    0.75 - d,
                    1.0
                ) - abs(1.5 - d) * 0.375;

                objID = step(tun, bio); // 0 = biotubes, 1 = tunnel walls
                return min(tun, bio);
            }

            float mapScene(float3 p)
            {
                float dummy;
                return mapScene(p, dummy);
            }

            // ------------------------------------------------
            // Bump mapping helpers
            // ------------------------------------------------

            float bumpSurf3D(float3 p, float saveID)
            {
                float bmp;
                float noi = noise3D(p * 96.0);

                if (saveID > 0.5)
                {
                    float sf  = cellTile(p * 0.75);
                    float vor = cellTile(p * 1.50);
                    bmp = sf * 0.66 + (vor * 0.94 + noi * 0.06) * 0.34;
                }
                else
                {
                    p /= 3.0;
                    float ct = cellTile(p * 2.0  + sin(p * 12.0) * 0.5) * 0.66 +
                               cellTile(p * 6.0  + sin(p * 36.0) * 0.5) * 0.34;
                    bmp = (1.0 - smoothstep(-0.2, 0.25, ct)) * 0.9 + noi * 0.1;
                }

                return bmp;
            }

            float3 doBumpMap(float3 p, float3 nor, float bumpfactor, float saveID)
            {
                const float2 e = float2(0.001, 0.0);
                float ref = bumpSurf3D(p, saveID);

                float3 grad;
                grad.x = bumpSurf3D(p - float3(e.x, e.y, e.y), saveID);
                grad.y = bumpSurf3D(p - float3(e.y, e.x, e.y), saveID);
                grad.z = bumpSurf3D(p - float3(e.y, e.y, e.x), saveID);
                grad = (grad - ref) / e.x;

                grad -= nor * dot(nor, grad);
                return normalize(nor + grad * bumpfactor);
            }

            // ------------------------------------------------
            // Raymarching
            // ------------------------------------------------

            float traceRM(float3 ro, float3 rd, out float objIDOut)
            {
                float t = 0.0;
                float h = 0.0;
                float objIDLocal = 0.0;

                [loop]
                for (int i = 0; i < 72; i++)
                {
                    float3 pos = ro + rd * t;
                    h = mapScene(pos, objIDLocal);

                    if (abs(h) < 0.002 * (t * 0.125 + 1.0) || t > FAR)
                        break;

                    float step1 = step(h, 1.0) * h * 0.2;
                    float step2 = h * 0.5;
                    t += step1 + step2;
                }

                objIDOut = objIDLocal;
                return min(t, FAR);
            }

            // ------------------------------------------------
            // Normal
            // ------------------------------------------------

            float3 getNormal(float3 p)
            {
                const float2 e = float2(0.002, 0.0);
                float3 n;
                n.x = mapScene(p + float3(e.x, e.y, e.y)) - mapScene(p - float3(e.x, e.y, e.y));
                n.y = mapScene(p + float3(e.y, e.x, e.y)) - mapScene(p - float3(e.y, e.x, e.y));
                n.z = mapScene(p + float3(e.y, e.y, e.x)) - mapScene(p - float3(e.y, e.y, e.x));
                return normalize(n);
            }

            // ------------------------------------------------
            // Thickness / SSS
            // ------------------------------------------------

            float thickness(float3 p, float3 n, float maxDist, float falloff)
            {
                const int nbIte = 6;
                float ao = 0.0;

                for (int i = 1; i <= nbIte; i++)
                {
                    float fi = (float)i;
                    float l = (fi * 0.75 + frac(cos(fi) * 45758.5453) * 0.25) / nbIte * maxDist;
                    ao += (l + mapScene(p - n * l)) / pow(1.0 + l, falloff);
                }

                return clamp(1.0 - ao / nbIte, 0.0, 1.0);
            }

            // ------------------------------------------------
            // Ambient occlusion
            // ------------------------------------------------

            float calculateAO(float3 p, float3 n)
            {
                const float maxDist = 4.0;
                const int   nbIte   = 6;

                float ao = 0.0;

                for (int i = 1; i <= nbIte; i++)
                {
                    float fi = (float)i;
                    float l = (fi + hash(fi)) * 0.5 / nbIte * maxDist;
                    ao += (l - mapScene(p + n * l)) / (1.0 + l);
                }

                return clamp(1.0 - ao / nbIte, 0.0, 1.0);
            }

            // ------------------------------------------------
            // Environment map helper
            // ------------------------------------------------

            float3 eMap(float3 rd, float3 sn)
            {
                float iTime = _Time.y * _TimeScale;
                rd.y += iTime;
                rd   /= 3.0;

                float ct = cellTile(rd * 2.0 + sin(rd * 12.0) * 0.5) * 0.66 +
                           cellTile(rd * 6.0 + sin(rd * 36.0) * 0.5) * 0.34;

                float3 texCol = float3(0.25, 0.20, 0.15) * (1.0 - smoothstep(-0.1, 0.3, ct)) +
                                float3(0.02, 0.02, 0.53) / 6.0;

                return saturate(texCol);
            }

            // ------------------------------------------------
            // Vertex
            // ------------------------------------------------

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                OUT.uv = IN.uv;
                OUT.worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            // ------------------------------------------------
            // Fragment
            // ------------------------------------------------

            float4 frag(Varyings i) : SV_Target
            {
                float iTime = _Time.y * _TimeScale;

                // Build ray from real camera to the mesh fragment, in world space
                float3 worldPos = i.worldPos;
                float3 roWorld  = _WorldSpaceCameraPos;
                float3 rdWorld  = normalize(worldPos - roWorld);

                // Convert ray to object space
                float3 roObj = mul(unity_WorldToObject, float4(roWorld, 1.0)).xyz;
                float3 rdObj = normalize(mul(unity_WorldToObject, float4(rdWorld, 0.0)).xyz);

                float3 camPos  = roObj;
                float3 rd      = rdObj;

                // Simple light position in object space (relative to camera)
                float3 lightPos = camPos + float3(0.0, 0.5, 5.0);

                // Raymarch
                float objID;
                float t = traceRM(camPos, rd, objID);

                float3 sceneCol = float3(0.0, 0.0, 0.0);

                if (t < FAR)
                {
                    float3 sp = camPos + rd * t;
                    float3 sn = getNormal(sp);

                    if (objID > 0.5)
                        sn = doBumpMap(sp, sn, 0.2,   objID); // tunnel
                    else
                        sn = doBumpMap(sp, sn, 0.008, objID); // tubes

                    float ao = calculateAO(sp, sn);

                    float3 ld = lightPos - sp;
                    float distlpsp = max(length(ld), 0.001);
                    ld /= distlpsp;

                    float atten = 1.0 / (1.0 + distlpsp * 0.25);

                    float ambience = 0.5;
                    float diff = max(dot(sn, ld), 0.0);
                    float spec = pow(max(dot(reflect(-ld, sn), -rd), 0.0), 32.0);
                    float fre  = pow(saturate(dot(sn, rd) + 1.0), 1.0);

                    float3 texCol;

                    if (objID > 0.5)
                    {
                        texCol = float3(0.3, 0.3, 0.3) *
                                 (noise3D(sp * 32.0) * 0.66 + noise3D(sp * 64.0) * 0.34) *
                                 (1.0 - cellTile(sp * 16.0) * 0.75);

                        texCol *= smoothstep(-0.1, 0.5,
                                             cellTile(sp * 0.75) * 0.66 +
                                             cellTile(sp * 1.50) * 0.34) * 0.85 + 0.15;
                    }
                    else
                    {
                        float3 sps = sp / 3.0;
                        float ct = cellTile(sps * 2.0 + sin(sps * 12.0) * 0.5) * 0.66 +
                                   cellTile(sps * 6.0 + sin(sps * 36.0) * 0.5) * 0.34;

                        texCol = float3(0.35, 0.25, 0.20) * (1.0 - smoothstep(-0.1, 0.25, ct)) +
                                 float3(0.10, 0.01, 0.004);
                    }

                    float3 hf = normalize(ld + sn);
                    float th   = thickness(sp, sn, 1.0, 1.0);
                    float tdiff = pow(saturate(dot(rd, -hf)), 1.0);
                    float trans = pow(tdiff * th, 4.0);

                    float shading = 1.0;

                    sceneCol = texCol * (diff + ambience) + float3(0.7, 0.9, 1.0) * spec;
                    if (objID < 0.5)
                        sceneCol += float3(0.7, 0.9, 1.0) * spec * spec;

                    sceneCol += texCol * float3(0.8, 0.95, 1.0) * pow(fre, 4.0) * 2.0;
                    sceneCol += float3(1.0, 0.07, 0.15) * trans * 1.5;

                    if (objID < 0.5)
                    {
                        float3 refv = reflect(rd, sn);
                        float3 em   = eMap(refv, sn);
                        sceneCol += em * 0.5;

                        float3 refr = refract(rd, sn, 1.0 / 1.3);
                        em = eMap(refr, sn);
                        sceneCol += em * float3(2.0, 0.2, 0.3) * 1.5;
                    }

                    sceneCol *= atten * shading * ao;
                }

                // Simple background if the ray did not hit anything
                float3 sky = float3(2.0, 0.9, 0.8);
                float fogFactor = 1.0 / (t * t / (FAR * FAR) * 8.0 + 1.0);
                float3 col = lerp(sky, sceneCol, fogFactor);

                col = sqrt(saturate(col)) * _Brightness;

                return float4(col, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
