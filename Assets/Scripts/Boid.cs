using System.Collections.Generic;
using UnityEngine;

public class Boid : MonoBehaviour
{
    // Reference to the manager (assigned on spawn)
    public BoidManager Manager { get; set; }

    // Current velocity (read-only from outside)
    public Vector3 Velocity => velocity;

    [SerializeField] private float rotationLerpSpeed = 4f;
    [SerializeField] private float randomNoiseStrength = 0.1f;

    private Vector3 velocity;

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

        // Force to keep boids inside bounds
        Vector3 boundsForce = ComputeBoundsForce() * Manager.BoundsWeight;
        acceleration += boundsForce;

        // Add a bit of random noise to avoid robotic motion
        acceleration += Random.insideUnitSphere * randomNoiseStrength;

        // Update velocity
        velocity += acceleration * Time.deltaTime;
        velocity = Vector3.ClampMagnitude(velocity, Manager.MaxSpeed);

        // Move boid
        transform.position += velocity * Time.deltaTime;

        // Rotate boid to face its movement direction
        if (velocity.sqrMagnitude > 0.0001f)
        {
            Quaternion targetRot = Quaternion.LookRotation(velocity.normalized, Vector3.up);
            transform.rotation = Quaternion.Slerp(
                transform.rotation,
                targetRot,
                Time.deltaTime * rotationLerpSpeed
            );
        }
    }

    /// <summary>
    /// Get neighboring boids within a certain distance.
    /// </summary>
    private List<Boid> GetNeighbors()
    {
        List<Boid> neighbors = new List<Boid>();

        foreach (Boid other in Manager.Boids)
        {
            if (other == this) continue;

            float dist = Vector3.Distance(transform.position, other.transform.position);
            if (dist < Manager.NeighborDistance)
            {
                neighbors.Add(other);
            }
        }

        return neighbors;
    }

    /// <summary>
    /// Move towards the center of mass of neighbors (cohesion).
    /// </summary>
    private Vector3 ComputeCohesion(List<Boid> neighbors)
    {
        Vector3 center = Vector3.zero;
        foreach (Boid b in neighbors)
        {
            center += b.transform.position;
        }
        center /= neighbors.Count;

        Vector3 desired = center - transform.position;
        return SteerTowards(desired);
    }

    /// <summary>
    /// Align with the average velocity of neighbors (alignment).
    /// </summary>
    private Vector3 ComputeAlignment(List<Boid> neighbors)
    {
        Vector3 avgVelocity = Vector3.zero;
        foreach (Boid b in neighbors)
        {
            avgVelocity += b.Velocity;
        }
        avgVelocity /= neighbors.Count;

        return SteerTowards(avgVelocity);
    }

    /// <summary>
    /// Move away from neighbors that are too close (separation).
    /// </summary>
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

    /// <summary>
    /// Keep the boid inside the bounding box defined by the manager.
    /// </summary>
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
        {
            return SteerTowards(desired);
        }

        return Vector3.zero;
    }

    /// <summary>
    /// Compute a steering force towards the desired direction.
    /// </summary>
    private Vector3 SteerTowards(Vector3 desired)
    {
        if (desired == Vector3.zero) return Vector3.zero;

        desired = desired.normalized * Manager.MaxSpeed;
        Vector3 steer = desired - velocity;
        return Vector3.ClampMagnitude(steer, Manager.MaxForce);
    }
}
