using UnityEngine;

public class TeleporterTrigger : MonoBehaviour
{
    [SerializeField] private Transform teleportDestination;
    [SerializeField] private string playerTag = "Player";

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag(playerTag))
        {
            Teleport(other.gameObject);
        }
    }

    void Teleport(GameObject player)
    {
        if (teleportDestination != null)
        {
            player.transform.position = teleportDestination.position;
        }
    }
}
