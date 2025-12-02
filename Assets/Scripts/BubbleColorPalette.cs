using UnityEngine;

[ExecuteAlways]
public class BubbleColorPalette : MonoBehaviour
{
    public Renderer targetRenderer;
    [Tooltip("Colors used for the bubbles. Will be repeated if less than 16.")]
    public Color[] palette;

    const int MaxBubbles = 16;
    static readonly int BubbleColorsId = Shader.PropertyToID("_BubbleColors");

    void OnEnable()
    {
        ApplyColors();
    }

    void OnValidate()
    {
        ApplyColors();
    }

    void ApplyColors()
    {
        if (targetRenderer == null || palette == null || palette.Length == 0)
            return;

        Material mat = Application.isPlaying
            ? targetRenderer.material      // instance in play mode
            : targetRenderer.sharedMaterial; // edit mode

        if (mat == null) return;

        Vector4[] colorArray = new Vector4[MaxBubbles];

        for (int i = 0; i < MaxBubbles; i++)
        {
            Color c = palette[i % palette.Length];
            colorArray[i] = (Vector4)c; // Color -> Vector4
        }

        mat.SetVectorArray(BubbleColorsId, colorArray);
    }
}
