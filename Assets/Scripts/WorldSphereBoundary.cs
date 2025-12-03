using UnityEngine;

public class WorldSphereBoundary : MonoBehaviour
{
    public enum Mode
    {
        ConfineInside,
        TeleportOnExit
    }

    [Header("References")]
    [SerializeField] private SphereCollider sphereCollider;
    [SerializeField] private Transform targetTransform; 
    [SerializeField] private PlayerWorldState playerWorldState;

    [Header("World")]
    [SerializeField] private PlayerWorldState.World worldId;

    [Header("Sphere")]
    [SerializeField] private float padding = 0f;

    [Header("Mode")]
    [SerializeField] private Mode mode = Mode.ConfineInside;

    [Header("Teleportation (if TeleportOnExit)")]
    [SerializeField] private Transform teleportDestination;
    [SerializeField] private PlayerWorldState.World worldOnExit; 

    private bool wasInside;

    private void Start()
    {
        if (sphereCollider == null)
            sphereCollider = GetComponent<SphereCollider>();

        if (targetTransform == null && playerWorldState != null)
            targetTransform = playerWorldState.transform;

        if (playerWorldState == null && targetTransform != null)
            playerWorldState = targetTransform.GetComponent<PlayerWorldState>();
    }

    private void Update()
    {
        if (sphereCollider == null || targetTransform == null || playerWorldState == null)
            return;

        // Only active when the player is in THIS world
        if (playerWorldState.CurrentWorld != worldId)
        {
            wasInside = false;
            return;
        }

        // Convert the sphere's center to world space
        Vector3 center = sphereCollider.transform.TransformPoint(sphereCollider.center);

        // Compute the sphere radius in world space (taking scale into account)
        float maxRadius = sphereCollider.radius * Mathf.Max(
            sphereCollider.transform.localScale.x,
            sphereCollider.transform.localScale.y,
            sphereCollider.transform.localScale.z);

        float distance = Vector3.Distance(targetTransform.position, center);
        bool isInside = distance <= maxRadius;

        switch (mode)
        {
            case Mode.ConfineInside:
                {
                    if (!isInside) break;

                    float limitRadius = Mathf.Max(0f, maxRadius - padding);

                    if (distance > limitRadius)
                    {
                        Vector3 dir = (targetTransform.position - center).normalized;
                        targetTransform.position = center + dir * limitRadius;
                    }

                    break;
                }

            case Mode.TeleportOnExit:
                {
                    // Teleport ONLY when transitioning from inside to outside
                    if (wasInside && !isInside && teleportDestination != null)
                    {
                        Debug.Log($"[WorldSphereBoundary] Out of {worldId} -> {worldOnExit}");
                        playerWorldState.SetWorld(worldOnExit);
                        targetTransform.position = teleportDestination.position;
                    }

                    break;
                }
        }

        wasInside = isInside;
    }
}
