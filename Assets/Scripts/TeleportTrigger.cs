using UnityEngine;

public class TeleporterTrigger : MonoBehaviour
{
    [SerializeField] private Transform teleportDestination;
    [SerializeField] private string playerTag = "Player";
    [SerializeField] private PlayerWorldState.World targetWorld;

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag(playerTag))
        {
            Teleport(other.gameObject);
        }
    }

    void Teleport(GameObject player)
    {
        if (teleportDestination == null) return;

        player.transform.position = teleportDestination.position;

        var worldState = player.GetComponent<PlayerWorldState>();
        if (worldState != null)
        {
            worldState.SetWorld(targetWorld);
        }

        Debug.Log($"[TeleporterTrigger] '{name}' -> world {targetWorld} to {teleportDestination.position}");
    }
}
