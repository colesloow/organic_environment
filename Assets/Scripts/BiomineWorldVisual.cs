using UnityEngine;
using System.Collections;

public class BiomineWorldVisual : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private PlayerWorldState playerWorldState;

    // Material that has the shader property
    [SerializeField] private Material biomineMaterial;

    // Name of the shader float property
    [SerializeField] private string propertyName = "_WorldScale";

    [Header("Fade settings")]
    [SerializeField] private float enterValue = 0.6f;
    [SerializeField] private float exitValue = 0f;
    [SerializeField] private float fadeDuration = 1f;

    private Coroutine currentFade;

    private void OnEnable()
    {
        if (playerWorldState != null)
        {
            playerWorldState.WorldChanged += OnWorldChanged;

            // Set initial value based on start world
            float start = playerWorldState.CurrentWorld == PlayerWorldState.World.Biomine
                ? enterValue
                : exitValue;

            SetProperty(start);
        }
    }

    private void OnDisable()
    {
        if (playerWorldState != null)
            playerWorldState.WorldChanged -= OnWorldChanged;
    }

    private void OnWorldChanged(PlayerWorldState.World world)
    {
        if (currentFade != null)
            StopCoroutine(currentFade);

        if (world == PlayerWorldState.World.Biomine)
        {
            // Fade in when entering Biomine
            currentFade = StartCoroutine(FadePropertyTo(enterValue));
        }
        else
        {
            // Fade out when leaving Biomine
            currentFade = StartCoroutine(FadePropertyTo(exitValue));
        }
    }

    private IEnumerator FadePropertyTo(float target)
    {
        float start = biomineMaterial.GetFloat(propertyName);
        float t = 0f;

        while (t < fadeDuration)
        {
            t += Time.deltaTime;
            float k = Mathf.Clamp01(t / fadeDuration);
            float value = Mathf.Lerp(start, target, k);
            SetProperty(value);
            yield return null;
        }

        SetProperty(target);
        currentFade = null;
    }

    private void SetProperty(float value)
    {
        if (biomineMaterial != null)
            biomineMaterial.SetFloat(propertyName, value);
    }
}
