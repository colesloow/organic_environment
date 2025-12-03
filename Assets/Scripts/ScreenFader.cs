using UnityEngine;
using UnityEngine.UI;
using System.Collections;

[RequireComponent(typeof(CanvasGroup))]
public class ScreenFader : MonoBehaviour
{
    [SerializeField] private float defaultDuration = 0.3f;

    private CanvasGroup canvasGroup;

    private void Awake()
    {
        canvasGroup = GetComponent<CanvasGroup>();
        // Start fully transparent
        canvasGroup.alpha = 0f;
        canvasGroup.blocksRaycasts = false;
    }

    public IEnumerator FadeIn(float duration = -1f)
    {
        if (duration <= 0f) duration = defaultDuration;
        canvasGroup.blocksRaycasts = true;

        float t = 0f;
        while (t < 1f)
        {
            t += Time.deltaTime / duration;
            canvasGroup.alpha = Mathf.Clamp01(t);
            yield return null;
        }
    }

    public IEnumerator FadeOut(float duration = -1f)
    {
        if (duration <= 0f) duration = defaultDuration;

        float t = 1f;
        while (t > 0f)
        {
            t -= Time.deltaTime / duration;
            canvasGroup.alpha = Mathf.Clamp01(t);
            yield return null;
        }

        canvasGroup.blocksRaycasts = false;
    }
}
