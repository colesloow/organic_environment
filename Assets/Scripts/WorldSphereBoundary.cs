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
    [SerializeField] private float padding = 0f; // also used as early-exit margin

    [Header("Mode")]
    [SerializeField] private Mode mode = Mode.ConfineInside;

    [Header("Teleportation (if TeleportOnExit)")]
    [SerializeField] private Transform teleportDestination;
    [SerializeField] private PlayerWorldState.World worldOnExit;

    [Header("Smooth transition (optional)")]
    [SerializeField] private WorldTransitionController transitionController;

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

        // Sphere center in world space
        Vector3 center = sphereCollider.transform.TransformPoint(sphereCollider.center);

        // Sphere radius in world space (with scale)
        float maxRadius = sphereCollider.radius * Mathf.Max(
            sphereCollider.transform.localScale.x,
            sphereCollider.transform.localScale.y,
            sphereCollider.transform.localScale.z);

        // Distance player -> center
        float distance = Vector3.Distance(targetTransform.position, center);

        switch (mode)
        {
            case Mode.ConfineInside:
                {
                    bool isInside = distance <= maxRadius;
                    if (!isInside) break;

                    float limitRadius = Mathf.Max(0f, maxRadius - padding);

                    if (distance > limitRadius)
                    {
                        Vector3 dir = (targetTransform.position - center).normalized;
                        targetTransform.position = center + dir * limitRadius;
                    }

                    wasInside = isInside;
                    break;
                }

            case Mode.TeleportOnExit:
                {
                    // Use a smaller radius so exit triggers before touching the visual boundary
                    float exitRadius = Mathf.Max(0f, maxRadius - padding);
                    bool isInsideForExit = distance <= exitRadius;

                    // Transition only when going from inside -> outside this inner radius
                    if (wasInside && !isInsideForExit && teleportDestination != null)
                    {
                        Debug.Log($"[WorldSphereBoundary] Out of {worldId} -> {worldOnExit}");

                        if (transitionController != null)
                        {
                            transitionController.StartWorldTransition(
                                worldOnExit,
                                teleportDestination.position
                            );
                        }
                        else
                        {
                            // Fallback: instant teleport
                            playerWorldState.SetWorld(worldOnExit);
                            targetTransform.position = teleportDestination.position;
                        }
                    }

                    wasInside = isInsideForExit;
                    break;
                }
        }
    }
}
