Shader "Universal Render Pipeline/RaymarchedBerry3D"
{
    Properties
    {
        // Volume dans lequel on raymarche (espace objet du mesh)
        _ContainerRadius("Container Radius (Object Space)", Float) = 0.7
        _StepCount("Raymarch Step Count", Float) = 120
        _HitEpsilon("Surface Hit Threshold", Float) = 0.0005

        // Échelle globale de la berry (SDF)
        _BerryScale("Berry Scale (Object Space)", Float) = 1.0

        // --- Subsurface Scattering ---
        _SSColor("SSS Color", Color) = (0.85, 0.05, 0.2, 1)
        _SSDensity("SSS Density", Float) = 8.0
        _SSPow("SSS Power", Float) = 3.0
        _SSScatter("SSS Scatter", Float) = 0.4
        _SSOffset("SSS Offset", Float) = 0.5
        _SSIntensity("SSS Intensity", Float) = 1.0
        [Range(0,1)] _SSMix("SSS Mix", Range(0,1)) = 1.0

        // --- Fresnel / Rim ---
        _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimPower("Rim Power", Float) = 2.5
        _RimAmount("Rim Amount", Float) = 1.0
        _FresnelConst("Fresnel F", Float) = 2.2

        // --- Lumière ---
        _LightColor("Light Color", Color) = (1,1,1,1)
        _LightPositionOS("Light Position (Object Space)", Vector) = (14,1,20,0)

        // --- Correction globale ---
        _Brightness("Global Brightness", Float) = 1.0

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

        LOD 150

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            Cull [_CullMode]
            ZWrite [_ZWriteMode]
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define SURFACE_THICKNESS 0.008

            float _ContainerRadius;
            float _StepCount;
            float _HitEpsilon;
            float _BerryScale;

            float4 _SSColor;
            float _SSDensity;
            float _SSPow;
            float _SSScatter;
            float _SSOffset;
            float _SSIntensity;
            float _SSMix;

            float4 _RimColor;
            float _RimPower;
            float _RimAmount;
            float _FresnelConst;

            float4 _LightColor;
            float4 _LightPositionOS;

            float _Brightness;

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            // -------- rotations (comme Shadertoy) --------
            float3x3 rotx(float a)
            {
                float c = cos(a);
                float s = sin(a);
                float3x3 rot;
                rot[0] = float3(1.0, 0.0, 0.0);
                rot[1] = float3(0.0, c, -s);
                rot[2] = float3(0.0, s,  c);
                return rot;
            }

            float3x3 roty(float a)
            {
                float c = cos(a);
                float s = sin(a);
                float3x3 rot;
                rot[0] = float3( c, 0.0, s);
                rot[1] = float3( 0, 1.0, 0);
                rot[2] = float3(-s, 0.0, c);
                return rot;
            }

            float3x3 rotz(float a)
            {
                float c = cos(a);
                float s = sin(a);
                float3x3 rot;
                rot[0] = float3( c, -s, 0.0);
                rot[1] = float3( s,  c, 0.0);
                rot[2] = float3( 0,  0, 1.0);
                return rot;
            }

            float3x3 GetRotation(float time)
            {
                float3x3 r = roty(sin(time * 0.5) * 2.0);
                r = mul(r, rotz(0.8));
                r = mul(r, rotx(sin(time) * 0.2));
                return r;
            }

            // -------- SDF berry + noise --------
            float sdBerry(float3 p, float s)
            {
                p.x += min(p.y, 0.0) * 0.5;
                return length(p) - s;
            }

            float mapBerry(float3 rp, float3x3 rotation)
            {
                rp = mul(rotation, rp);

                float scale = max(_BerryScale, 0.0001);
                float3 q = rp / scale;      // espace normalisé

                const float baseR = 0.055;

                float d = sdBerry(q, baseR) - dot(abs(sin(q * 140.0)), float3(0.0035, 0.0035, 0.0035));
                d = min(d, sdBerry(q, baseR) - dot(abs(sin(q * 160.0)), float3(0.0025, 0.0025, 0.0025)));
                d -= dot(abs(sin(q * 1000.0)), float3(0.0001, 0.0001, 0.0001));

                return d * scale;
            }

            float3 gradBerry(float3 rp, float3x3 rotation)
            {
                float h = 0.0001;
                float3 offx = float3(h, 0, 0);
                float3 offy = float3(0, h, 0);
                float3 offz = float3(0, 0, h);

                float gx = mapBerry(rp + offx, rotation) - mapBerry(rp - offx, rotation);
                float gy = mapBerry(rp + offy, rotation) - mapBerry(rp - offy, rotation);
                float gz = mapBerry(rp + offz, rotation) - mapBerry(rp - offz, rotation);

                return normalize(float3(gx, gy, gz));
            }

            // -------- random / SSS --------
            float rand2(float2 co)
            {
                return frac(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
            }

            float ssThickness(float3 raypos, float3 lightdir, float3 g, float3 rd, float3x3 rotation)
            {
                float3 startFrom = raypos + (-g * SURFACE_THICKNESS);
                float3 ro = raypos;

                float len = 0.0;
                const float samples = 12.0;
                float sqs = sqrt(samples);

                [loop]
                for (float s = -samples * 0.5; s < samples * 0.5; s += 1.0)
                {
                    float3 rp = startFrom;
                    float3 ld = lightdir;

                    ld.x += fmod(abs(s), sqs) * _SSScatter * sign(s);
                    ld.y += (s / sqs) * _SSScatter;

                    ld.x += rand2(rp.xy * s) * _SSScatter;
                    ld.y += rand2(rp.yx * s) * _SSScatter;
                    ld.z += rand2(rp.zx * s) * _SSScatter;

                    ld = normalize(ld);
                    float3 dir = ld;

                    [loop]
                    for (int i = 0; i < 50; ++i)
                    {
                        float dist = mapBerry(rp, rotation);
                        if (dist < 0.0) dist = min(dist, -0.0001);
                        if (dist >= 0.0) break;

                        dir = normalize(ld);
                        rp += abs(dist * 0.5) * dir;
                    }

                    len += length(ro - rp);
                }

                return len / samples;
            }

            // -------- ray / sphere container --------
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

            // -------- vertex --------
            Varyings vert (Attributes v)
            {
                Varyings o;
                float3 worldPos = TransformObjectToWorld(v.positionOS);
                o.positionWS = worldPos;
                o.positionCS = TransformWorldToHClip(worldPos);
                return o;
            }

            // -------- fragment --------
            float4 frag (Varyings i) : SV_Target
            {
                float time = _Time.y;

                // position monde du vertex (sur la sphère support)
                float3 worldPos = i.positionWS;

                // rayon en espace monde
                float3 roWS = _WorldSpaceCameraPos;
                float3 rdWS = normalize(worldPos - roWS);

                // passage en espace objet du mesh
                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                // intersection rayon / sphère conteneur
                float tEnter, tExit;
                if (!RaySphere(roOS, rdOS, _ContainerRadius, tEnter, tExit))
                {
                    // aucun volume à raymarcher sur ce pixel : on ignore complètement
                    clip(-1);
                }

                if (tEnter < 0.0) tEnter = 0.0;

                float3x3 rotation = GetRotation(time);

                float t = tEnter;
                float3 pOS = roOS;
                float dist = 0.0;
                float closest = 1e6;
                bool hit = false;

                int maxSteps = (int)_StepCount;

                [loop]
                for (int step = 0; step < maxSteps; ++step)
                {
                    if (t > tExit) break;

                    pOS = roOS + rdOS * t;
                    dist = mapBerry(pOS, rotation);

                    closest = min(closest, abs(dist));

                    if (dist < _HitEpsilon)
                    {
                        hit = true;
                        break;
                    }

                    t += max(dist * 0.5, 0.0005);
                }

                // pas de hit dans le volume : on ignore aussi ce fragment
                if (!hit)
                {
                    clip(-1);
                }

                // point d’impact en espace objet
                float3 hitOS = roOS + rdOS * t;

                // normale SDF
                float3 g = gradBerry(hitOS, rotation);

                // lumière en espace objet
                float3 lightPosOS = _LightPositionOS.xyz;
                float3 lightDirOS = normalize(lightPosOS - hitOS);
                float3 lightCol   = _LightColor.rgb;

                float ndotl = saturate(dot(g, lightDirOS));

                // -----------------
                // Fresnel / Rim
                // -----------------
                float3 r = reflect(-lightDirOS, g);
                float rimd = 1.0 - dot(r, -rdOS);
                rimd = saturate(rimd);
                rimd = pow(rimd, _RimPower);

                float frn = rimd + _FresnelConst * (1.0 - rimd);
                float3 rimColor = frn * _RimColor.rgb * _RimAmount * ndotl;

                // -----------------
                // Subsurface scattering
                // -----------------
                float tSS = ssThickness(hitOS, lightDirOS, g, rdOS, rotation);
                tSS = exp(_SSOffset - tSS * _SSDensity);
                tSS = pow(abs(tSS), _SSPow);

                float3 ssBase = _SSColor.rgb;
                float3 ssCol = tSS * ssBase * _SSIntensity;
                ssCol = lerp(ssCol, ssBase, 1.0 - _SSMix);

                float3 color = ssCol + rimColor;

                // correction globale
                color *= _Brightness;
                color = saturate(color);

                // ici on veut une berry opaque : alpha = 1
                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
