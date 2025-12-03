// Raymarched 3D Heart Shader
// Procedural heightfields and PBR shading
// Inspired by: https://www.shadertoy.com/view/ctcGR8

Shader "Universal Render Pipeline/RaymarchedHeart3D"
{
    Properties
    {
        // Volume in which the heart is raymarched
        _ContainerRadius("Container Radius (Object Space)", Float) = 0.7
        _BaseRadius("Base Sphere Radius", Float) = 0.45
        _DisplacementScale("Displacement Scale", Float) = 1.8

        // Raymarching
        _StepCount("Raymarch Step Count", Float) = 80
        _HitEpsilon("Surface Hit Threshold", Float) = 0.0005
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

            Cull Back
            ZWrite On
            Blend Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //======================================
            // CONSTANTES
            //======================================

            #define MAX_MARCHING_STEPS   80
            #define DERIVATIVE_EPSILON   0.001
            #define MY_PI 3.14159265359

            // PBR colors for the heart
            static const float3 ALBEDO_INNER   = float3(3.0, 0.02, 0.03);
            static const float3 ALBEDO_OUTER   = float3(0.3, 0.0, 0.0);
            static const float3 ALBEDO_CREASES = float3(0.0, 0.0, 0.01);

            static const float3 SPHERE_CENTER = float3(0.0, 0.0, 0.0);
            static const float  SPHERE_RADIUS = 0.5;

            // Parameters for the procedural heightfield
            #define DETAIL               20
            #define ANIMATION_SPEED      2.0
            #define BRIGHTNESS           0.2
            #define STRUCTURE_SMOOTHNESS 1.2
            #define SATURATION           0.2

            //======================================
            // PROPRIÉTÉS
            //======================================

            float _ContainerRadius;
            float _StepCount;
            float _HitEpsilon;

            float _BaseRadius;
            float _DisplacementScale;

            //======================================
            // STRUCTURES
            //======================================

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            //======================================
            // VERTEX
            //======================================

            Varyings vert (Attributes v)
            {
                Varyings o;
                float3 worldPos = TransformObjectToWorld(v.positionOS);
                o.positionWS = worldPos;
                o.positionCS = TransformWorldToHClip(worldPos);
                return o;
            }

            //======================================
            // HELPERS
            //======================================

            float2 spherical_mapping(float2 n)
            {
                return float2(asin(n.x), asin(n.y)) / MY_PI + 0.5;
            }

            float smin(float a, float b, float k)
            {
                float h = max(k - abs(a - b), 0.0) / k;
                return min(a, b) - h * h * k * 0.25;
            }

            float distToSphere(float3 center, float radius, float3 queryPoint)
            {
                return length(center - queryPoint) - radius;
            }

            float smoothstep01(float edge0, float edge1, float x)
            {
                float t = saturate((x - edge0) / (edge1 - edge0));
                return t * t * (3.0 - 2.0 * t);
            }

            //======================================
            // PROCEDURAL HEIGHTFIELD 
            //======================================

            float OrganicHeightField(float2 uv, float2 resolution, float iTime)
            {
                // p = (fragCoord - 0.5 * iResolution) / iResolution.y
                float2 p = (uv * resolution - 0.5 * resolution) / resolution.y;
                float dist_squared = dot(p, p);
                float S = 9.0;

                float c = cos(5.0);
                float s = sin(5.0);
                float2x2 m = float2x2(c, s, -s, c);

                float a = 0.0;
                float2 n = float2(0.0, 0.0);
                float2 q;

                [loop]
                for (int idx = 0; idx < DETAIL; ++idx)
                {
                    float j = (float)(idx) + 1.0;

                    p = mul(p, m);
                    n = mul(n, m);

                    q = p * S
                        + iTime * ANIMATION_SPEED
                        + sin(iTime * ANIMATION_SPEED - dist_squared * 6.0) * 0.8
                        + j
                        + n;

                    a += dot(cos(q) / S, float2(SATURATION, SATURATION));
                    n -= sin(q);
                    S *= STRUCTURE_SMOOTHNESS;
                }

                float result = 0.2 * ((a + BRIGHTNESS) + a + a);
                return result;  // texture(iChannel0, uv).x
            }

            float organic_displacement(float3 dir, float2 resolution, float iTime)
            {
                float2 uv = spherical_mapping(normalize(dir).xy);
                return OrganicHeightField(uv, resolution, iTime);
            }

            //======================================
            // HEART DISTANCE FIELD
            //======================================

            // Return distance to scene and displacement value
            float2 distToScene(float3 queryPoint, float2 resolution, float iTime)
            {
                float3 dir = normalize(queryPoint - SPHERE_CENTER);
                float displacement = organic_displacement(dir, resolution, iTime) * _DisplacementScale;

                // big sphere with displacement
                float dist = length(SPHERE_CENTER - queryPoint) - (_BaseRadius + displacement);

                // little spheres moving inside
                float sinTime = sin(iTime * 1.8) * 0.5;
                float cosTime = cos(iTime * 1.5) * 0.5;

                dist = smin(
                    dist,
                    distToSphere(float3(sinTime * sinTime, cosTime, sinTime), 0.02, queryPoint),
                    0.4
                );
                dist = smin(
                    dist,
                    distToSphere(float3(sinTime, sinTime * cosTime, cosTime), 0.02, queryPoint),
                    0.4
                );
                dist = smin(
                    dist,
                    distToSphere(float3(cosTime * cosTime, sinTime, sinTime * cosTime), 0.02, queryPoint),
                    0.1
                );

                return float2(dist, displacement);
            }

            float3 normalScene(float3 p, float2 resolution, float iTime)
            {
                float3 e1 = float3( 1.0, -1.0, -1.0);
                float3 e2 = float3(-1.0, -1.0,  1.0);
                float3 e3 = float3(-1.0,  1.0, -1.0);
                float3 e4 = float3( 1.0,  1.0,  1.0);

                float3 n =
                    e1 * distToScene(p + e1 * DERIVATIVE_EPSILON, resolution, iTime).x +
                    e2 * distToScene(p + e2 * DERIVATIVE_EPSILON, resolution, iTime).x +
                    e3 * distToScene(p + e3 * DERIVATIVE_EPSILON, resolution, iTime).x +
                    e4 * distToScene(p + e4 * DERIVATIVE_EPSILON, resolution, iTime).x;

                return normalize(n);
            }

            //======================================
            // PBR HEART
            //======================================

            float3 fresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
            }

            float DistributionGGX(float3 N, float3 H, float roughness)
            {
                float a  = roughness * roughness;
                float a2 = a * a;
                float NdotH  = max(dot(N, H), 0.0);
                float NdotH2 = NdotH * NdotH;

                float num   = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = MY_PI * denom * denom;

                return num / max(denom, 1e-5);
            }

            float GeometrySchlickGGX(float NdotV, float roughness)
            {
                float r = (roughness + 1.0);
                float k = (r * r) / 8.0;

                float num   = NdotV;
                float denom = NdotV * (1.0 - k) + k;

                return num / max(denom, 1e-5);
            }

            float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
            {
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx2  = GeometrySchlickGGX(NdotV, roughness);
                float ggx1  = GeometrySchlickGGX(NdotL, roughness);
                return ggx1 * ggx2;
            }

            float3 lightPBR(
                float3 pos,
                float3 lightPositions[2],
                float3 lightColors[2],
                float3 eye,
                float  material,
                float2 resolution,
                float  iTime)
            {
                float tInner = smoothstep01(0.05, 0.08, material);
                float3 albedo = lerp(ALBEDO_OUTER, ALBEDO_INNER, tInner);

                float metallic  = 0.0;
                float roughness = 0.1 + 0.4 * (1.0 - smoothstep01(0.07, 0.08, material));
                float ao        = smoothstep01(0.05, 0.09, material);

                float3 N = normalScene(pos, resolution, iTime);
                float3 V = normalize(eye - pos);

                float3 F0 = float3(0.04, 0.04, 0.04);
                F0 = lerp(F0, albedo, metallic);

                float3 Lo = float3(0.0, 0.0, 0.0);

                [unroll]
                for (int i = 0; i < 2; ++i)
                {
                    float3 L = normalize(lightPositions[i] - pos);
                    float3 H = normalize(V + L);
                    float distance = length(lightPositions[i] - pos);
                    float attenuation = 1.0 / (distance * distance);
                    float3 radiance = lightColors[i] * attenuation;

                    float NDF = DistributionGGX(N, H, roughness);
                    float G   = GeometrySmith(N, V, L, roughness);
                    float3 F  = fresnelSchlick(max(dot(H, V), 0.0), F0);

                    float3 kS = F;
                    float3 kD = (1.0 - kS) * (1.0 - metallic);

                    float numerator   = NDF * G;
                    float denomScalar = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
                    float3 specular   = (numerator / denomScalar) * F;

                    float NdotL = max(dot(N, L), 0.0);
                    Lo += (kD * albedo / MY_PI + specular) * radiance * NdotL;
                }

                float3 ambient = float3(0.03, 0.03, 0.03) * albedo * ao;
                float3 color   = ambient + Lo;

                // Tone mapping + gamma
                color = color / (color + 1.0);
                float3 gamma = float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2);
                color = pow(color, gamma);

                return color;
            }

            //======================================
            // RAY-SPHERE (CONTAINER)
            //======================================

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

            //======================================
            // FRAGMENT
            //======================================

            float4 frag (Varyings i) : SV_Target
            {
                float iTime = _Time.y;
                float2 screenRes = _ScreenParams.xy;

                float3 worldPos = i.positionWS;

                float3 roWS = _WorldSpaceCameraPos;
                float3 rdWS = normalize(worldPos - roWS);

                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                // Intersection with sphere container in object space
                float tEnter, tExit;
                if (!RaySphere(roOS, rdOS, _ContainerRadius, tEnter, tExit))
                {
                    clip(-1); // nothing to draw
                    return float4(0,0,0,0);
                }

                if (tEnter < 0.0) tEnter = 0.0;

                float t = tEnter;
                float3 pOS = roOS;
                float dist = 0.0;
                float disp = 0.0;

                int maxSteps = (int)_StepCount;
                maxSteps = min(maxSteps, MAX_MARCHING_STEPS);

                [loop]
                for (int step = 0; step < maxSteps; ++step)
                {
                    if (t > tExit) break;

                    pOS = roOS + rdOS * t;

                    float2 q = distToScene(pOS, screenRes, iTime);
                    dist = q.x;
                    disp = q.y;

                    if (dist < _HitEpsilon) break;

                    t += dist;
                }

                // If no hit
                if (t > tExit || dist > _HitEpsilon * 4.0)
                {
                    clip(-1); // delete pixel
                    return float4(0,0,0,0);
                }

                // Intersection point in object and world space
                float3 hitOS = roOS + rdOS * t;
                float3 hitWS = mul(unity_ObjectToWorld, float4(hitOS, 1.0)).xyz;

                // Lights
                float3 lightPos[2];
                float3 lightColors[2];
                lightPos[0]    = float3(2.0, 0.0, 0.0);
                lightPos[1]    = float3(0.0, 1.0, 1.0);
                lightColors[0] = float3(1.0, 1.0, 1.0);
                lightColors[1] = float3(1.0, 1.0, 1.0);

                float3 col = lightPBR(hitOS, lightPos, lightColors, roOS, disp, screenRes, iTime);

                return float4(col, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
