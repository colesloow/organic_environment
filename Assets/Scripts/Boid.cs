using System.Collections.Generic;
using UnityEngine;

public class Boid : MonoBehaviour
{
    // Reference to manager (set by BoidManager when spawning)
    public BoidManager Manager { get; set; }

    // Current velocity (read only from outside)
    public Vector3 Velocity => velocity;

    [Header("Movement")]
    [SerializeField] private float rotationLerpSpeed = 4f;
    [SerializeField] private float randomNoiseStrength = 0.1f;

    [Header("Visual size (absolute orb size)")]
    [SerializeField, Min(0.01f)] private float size = 0.2f; // orb visual size

    [Header("Trail controls")]
    [Tooltip("Base trail lifetime before scaling by size")]
    [SerializeField, Min(0.01f)] private float trailLifetime = -1f; // if <0, will be read from ParticleSystem

    [Tooltip("Orb particle system on this GameObject")]
    [SerializeField] private ParticleSystem orbParticleSystem;

    [Tooltip("Trail particle system on child GameObject")]
    [SerializeField] private ParticleSystem trailParticleSystem;

    // Base values read from the particle systems (for 'original' config)
    private float orbBaseSize = -1f;
    private float trailBaseSize = -1f;
    private float trailBaseLifetime = -1f;

    private Vector3 velocity;
    private float lastAppliedSize = -1f;
    private float lastAppliedTrailLifetime = -1f;

    // Public properties if you want to control from outside
    public float Size
    {
        get => size;
        set
        {
            size = Mathf.Max(0.01f, value);
            ApplySizeAndTrailToParticles();
        }
    }

    public float TrailLifetime
    {
        get => trailLifetime;
        set
        {
            trailLifetime = Mathf.Max(0.01f, value);
            ApplySizeAndTrailToParticles();
        }
    }

    private void Awake()
    {
        // Auto-assign particle systems if not set from inspector
        if (orbParticleSystem == null)
            orbParticleSystem = GetComponent<ParticleSystem>();

        if (trailParticleSystem == null)
        {
            ParticleSystem[] systems = GetComponentsInChildren<ParticleSystem>();
            foreach (ParticleSystem ps in systems)
            {
                if (ps != orbParticleSystem)
                {
                    trailParticleSystem = ps;
                    break;
                }
            }
        }

        CacheBaseParticleValues();
        ApplySizeAndTrailToParticles();
    }

#if UNITY_EDITOR
    private void OnValidate()
    {
        size = Mathf.Max(0.01f, size);

        if (!Application.isPlaying)
        {
            if (orbParticleSystem == null)
                orbParticleSystem = GetComponent<ParticleSystem>();

            if (trailParticleSystem == null)
            {
                ParticleSystem[] systems = GetComponentsInChildren<ParticleSystem>();
                foreach (ParticleSystem ps in systems)
                {
                    if (ps != orbParticleSystem)
                    {
                        trailParticleSystem = ps;
                        break;
                    }
                }
            }

            CacheBaseParticleValues();
            ApplySizeAndTrailToParticles();
        }
    }
#endif

    private void Start()
    {
        // Initialize random velocity
        if (Manager != null)
            velocity = Random.onUnitSphere * Manager.MaxSpeed;
        else
            velocity = Random.onUnitSphere * 2f;
    }

    private void Update()
    {
        if (Manager == null) return;

        List<Boid> neighbors = GetNeighbors();
        Vector3 acceleration = Vector3.zero;

        if (neighbors.Count > 0)
        {
            Vector3 cohesion = ComputeCohesion(neighbors) * Manager.CohesionWeight;
            Vector3 alignment = ComputeAlignment(neighbors) * Manager.AlignmentWeight;
            Vector3 separation = ComputeSeparation(neighbors) * Manager.SeparationWeight;

            acceleration += cohesion + alignment + separation;
        }

        // Bounds force
        Vector3 boundsForce = ComputeBoundsForce() * Manager.BoundsWeight;
        acceleration += boundsForce;

        // Small random noise so motion is not too robotic
        acceleration += Random.insideUnitSphere * randomNoiseStrength;

        // Update velocity
        velocity += acceleration * Time.deltaTime;
        velocity = Vector3.ClampMagnitude(velocity, Manager.MaxSpeed);

        // Move
        transform.position += velocity * Time.deltaTime;

        // Rotate towards movement direction
        if (velocity.sqrMagnitude > 0.0001f)
        {
            Quaternion targetRot = Quaternion.LookRotation(velocity.normalized, Vector3.up);
            transform.rotation = Quaternion.Slerp(
                transform.rotation,
                targetRot,
                Time.deltaTime * rotationLerpSpeed
            );
        }

        // Ensure particle systems follow size and trail lifetime if animated
        ApplySizeAndTrailToParticles();
    }

    // -----------------------
    // Particle helpers
    // -----------------------

    private void CacheBaseParticleValues()
    {
        // ORB --------------------------------------------------------
        if (orbParticleSystem != null && orbBaseSize < 0f)
        {
            var main = orbParticleSystem.main;
            orbBaseSize = main.startSizeMultiplier;
        }

        // TRAIL ------------------------------------------------------
        if (trailParticleSystem != null)
        {
            var main = trailParticleSystem.main;

            if (trailBaseSize < 0f)
                trailBaseSize = main.startSizeMultiplier;

            if (trailBaseLifetime < 0f)
            {
                var lifetimeCurve = main.startLifetime;
                switch (lifetimeCurve.mode)
                {
                    case ParticleSystemCurveMode.Constant:
                        trailBaseLifetime = lifetimeCurve.constant;
                        break;
                    case ParticleSystemCurveMode.TwoConstants:
                        trailBaseLifetime = (lifetimeCurve.constantMin + lifetimeCurve.constantMax) * 0.5f;
                        break;
                    default:
                        trailBaseLifetime = 1f; // fallback
                        break;
                }
            }

            // If user didn't set trailLifetime in inspector, use PS value as default
            if (trailLifetime <= 0f)
                trailLifetime = trailBaseLifetime;
        }
    }

    // size = ABSOLUTE orb size
    // trailLifetime = base trail lifetime (at base orb size)
    // actual trail lifetime = trailLifetime * (size / orbBaseSize)
    private void ApplySizeAndTrailToParticles()
    {
        // Avoid useless work if nothing changed
        if (Mathf.Approximately(lastAppliedSize, size) &&
            Mathf.Approximately(lastAppliedTrailLifetime, trailLifetime))
        {
            return;
        }

        lastAppliedSize = size;
        lastAppliedTrailLifetime = trailLifetime;

        // Compute scale factor relative to orb base size
        float scaleFactor = 1f;
        if (orbBaseSize > 0.0001f)
            scaleFactor = size / orbBaseSize;

        // ORB --------------------------------------------------------
        if (orbParticleSystem != null)
        {
            var main = orbParticleSystem.main;
            // Orb start size is directly controlled by "size"
            main.startSizeMultiplier = size;
        }

        // TRAIL ------------------------------------------------------
        if (trailParticleSystem != null)
        {
            var main = trailParticleSystem.main;

            // Scale trail particle size proportionally to orb size
            if (trailBaseSize > 0f)
                main.startSizeMultiplier = trailBaseSize * scaleFactor;

            // Base lifetime is 'trailLifetime', scaled by factor
            if (trailLifetime > 0f)
                main.startLifetime = trailLifetime * scaleFactor;
        }
    }

    // -----------------------
    // Boids behaviour
    // -----------------------

    private List<Boid> GetNeighbors()
    {
        List<Boid> neighbors = new List<Boid>();

        foreach (Boid other in Manager.Boids)
        {
            if (other == this) continue;

            float dist = Vector3.Distance(transform.position, other.transform.position);
            if (dist < Manager.NeighborDistance)
                neighbors.Add(other);
        }

        return neighbors;
    }

    private Vector3 ComputeCohesion(List<Boid> neighbors)
    {
        Vector3 center = Vector3.zero;
        foreach (Boid b in neighbors)
            center += b.transform.position;

        center /= neighbors.Count;

        Vector3 desired = center - transform.position;
        return SteerTowards(desired);
    }

    private Vector3 ComputeAlignment(List<Boid> neighbors)
    {
        Vector3 avgVelocity = Vector3.zero;
        foreach (Boid b in neighbors)
            avgVelocity += b.Velocity;

        avgVelocity /= neighbors.Count;

        return SteerTowards(avgVelocity);
    }

    private Vector3 ComputeSeparation(List<Boid> neighbors)
    {
        Vector3 force = Vector3.zero;
        int count = 0;

        foreach (Boid b in neighbors)
        {
            float dist = Vector3.Distance(transform.position, b.transform.position);
            if (dist < Manager.SeparationDistance && dist > 0f)
            {
                Vector3 away = (transform.position - b.transform.position).normalized / dist;
                force += away;
                count++;
            }
        }

        if (count > 0)
            force /= count;

        return SteerTowards(force);
    }

    private Vector3 ComputeBoundsForce()
    {
        Vector3 halfSize = Manager.BoundsSize * 0.5f;
        Vector3 min = Manager.BoundsCenter - halfSize;
        Vector3 max = Manager.BoundsCenter + halfSize;

        Vector3 desired = Vector3.zero;
        Vector3 pos = transform.position;

        if (pos.x < min.x) desired.x = 1f;
        else if (pos.x > max.x) desired.x = -1f;

        if (pos.y < min.y) desired.y = 1f;
        else if (pos.y > max.y) desired.y = -1f;

        if (pos.z < min.z) desired.z = 1f;
        else if (pos.z > max.z) desired.z = -1f;

        if (desired != Vector3.zero)
            return SteerTowards(desired);

        return Vector3.zero;
    }

    private Vector3 SteerTowards(Vector3 desired)
    {
        if (desired == Vector3.zero) return Vector3.zero;

        desired = desired.normalized * Manager.MaxSpeed;
        Vector3 steer = desired - velocity;
        return Vector3.ClampMagnitude(steer, Manager.MaxForce);
    }
}
