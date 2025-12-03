using UnityEngine;
using System.Collections;

public class WorldTransitionController : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private Transform player;
    [SerializeField] private PlayerWorldState playerWorldState;
    [SerializeField] private ScreenFader screenFader;

    [Header("Durations")]
    [SerializeField] private float fadeDuration = 0.3f;
    [SerializeField] private float holdBlackTime = 0.1f; // small pause fully black

    private bool isTransitioning;

    private void Awake()
    {
        if (playerWorldState == null && player != null)
            playerWorldState = player.GetComponent<PlayerWorldState>();

        if (player == null && playerWorldState != null)
            player = playerWorldState.transform;
    }

    public void StartWorldTransition(PlayerWorldState.World targetWorld, Vector3 targetPosition)
    {
        if (!isTransitioning)
            StartCoroutine(WorldTransitionRoutine(targetWorld, targetPosition));
    }

    private IEnumerator WorldTransitionRoutine(PlayerWorldState.World targetWorld, Vector3 targetPosition)
    {
        isTransitioning = true;

        // Fade to black
        yield return screenFader.FadeIn(fadeDuration);

        // Teleport + set world while screen is black
        if (player != null)
            player.position = targetPosition;

        if (playerWorldState != null)
            playerWorldState.SetWorld(targetWorld);

        yield return new WaitForSeconds(holdBlackTime);

        // Fade back
        yield return screenFader.FadeOut(fadeDuration);

        isTransitioning = false;
    }
}
