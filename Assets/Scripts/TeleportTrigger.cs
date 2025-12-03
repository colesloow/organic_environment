using UnityEngine;

public class TeleporterTrigger : MonoBehaviour
{
    [SerializeField] private Transform teleportDestination;
    [SerializeField] private string playerTag = "Player";

    [Header("Target world")]
    [SerializeField] private PlayerWorldState.World targetWorld;

    [Header("Transition")]
    [SerializeField] private WorldTransitionController transitionController;

    private void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag(playerTag)) return;

        if (teleportDestination == null || transitionController == null) return;

        // Launch smooth transition
        transitionController.StartWorldTransition(targetWorld, teleportDestination.position);
    }
}
