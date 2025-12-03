using System.Collections.Generic;
using UnityEngine;

public class BoidManager : MonoBehaviour
{
    [Header("Prefab & Spawn")]
    [SerializeField] private Boid boidPrefab;
    [SerializeField] private int boidCount = 50;
    [SerializeField] private float spawnRadius = 10f;

    [Header("Boids Settings")]
    [SerializeField] private float neighborDistance = 3f;
    [SerializeField] private float separationDistance = 1f;
    [SerializeField] private float maxSpeed = 5f;
    [SerializeField] private float maxForce = 0.5f;

    [SerializeField, Range(0f, 5f)] private float cohesionWeight = 1f;
    [SerializeField, Range(0f, 5f)] private float alignmentWeight = 1f;
    [SerializeField, Range(0f, 5f)] private float separationWeight = 1.5f;

    [Header("Bounds (living area)")]
    [SerializeField] private Vector3 boundsSize = new Vector3(30f, 15f, 30f);
    [SerializeField] private float boundsWeight = 2f;

    private readonly List<Boid> boids = new List<Boid>();

    // Read-only accessors for Boid
    public IReadOnlyList<Boid> Boids => boids;
    public float NeighborDistance => neighborDistance;
    public float SeparationDistance => separationDistance;
    public float MaxSpeed => maxSpeed;
    public float MaxForce => maxForce;
    public float CohesionWeight => cohesionWeight;
    public float AlignmentWeight => alignmentWeight;
    public float SeparationWeight => separationWeight;

    // Bounds center = GameObject position
    public Vector3 BoundsCenter => transform.position;

    public Vector3 BoundsSize => boundsSize;
    public float BoundsWeight => boundsWeight;

    private void Start()
    {
        // Initialize boids as children of this manager
        for (int i = 0; i < boidCount; i++)
        {
            Vector3 spawnPos = transform.position + Random.insideUnitSphere * spawnRadius;
            Quaternion spawnRot = Quaternion.Slerp(
                Quaternion.identity,
                Random.rotation,
                0.3f
            );

            Boid newBoid = Instantiate(boidPrefab, spawnPos, spawnRot, transform);
            newBoid.Manager = this;
            boids.Add(newBoid);
        }
    }

    private void OnDrawGizmosSelected()
    {
        // Draw bounds box in the editor around the manager
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireCube(transform.position, boundsSize);
    }
}
