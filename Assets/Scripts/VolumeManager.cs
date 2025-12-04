using UnityEngine;
using UnityEngine.Audio;
using System.Collections;

public class VolumeManager : MonoBehaviour
{
    [Header("Mixer")]
    [SerializeField] private AudioMixer mixer;

    [Header("World state")]
    [SerializeField] private PlayerWorldState playerWorldState;

    [Header("Fade")]
    [SerializeField] private float fadeDuration = 1f;

    private Coroutine currentFade;

    private void OnEnable()
    {
        if (playerWorldState != null)
        {
            playerWorldState.WorldChanged += OnWorldChanged;

            // Apply start world profile instantly (no fade)
            ApplyProfileImmediately(playerWorldState.CurrentWorld);
        }
    }

    private void OnDisable()
    {
        if (playerWorldState != null)
            playerWorldState.WorldChanged -= OnWorldChanged;
    }

    private void OnWorldChanged(PlayerWorldState.World world)
    {
        // Stop any existing fade
        if (currentFade != null)
            StopCoroutine(currentFade);

        // Start new fade
        currentFade = StartCoroutine(FadeToProfile(world));
    }

    private IEnumerator FadeToProfile(PlayerWorldState.World targetWorld)
    {
        // Read current mixer volumes (converted to linear 0-1)
        float startGuts = GetLinear("GutsVolume");
        float startBiomine = GetLinear("BiomineVolume");
        float startViscus = GetLinear("ViscusVolume");

        Vector3 start = new Vector3(startGuts, startBiomine, startViscus);
        Vector3 target = GetProfileForWorld(targetWorld);

        float t = 0f;
        while (t < fadeDuration)
        {
            t += Time.deltaTime;
            float k = Mathf.Clamp01(t / fadeDuration);

            Vector3 v = Vector3.Lerp(start, target, k);

            SetVolume("GutsVolume", v.x);
            SetVolume("BiomineVolume", v.y);
            SetVolume("ViscusVolume", v.z);

            yield return null;
        }

        // Ensure exact final profile
        ApplyProfileImmediately(targetWorld);
        currentFade = null;
    }

    private void ApplyProfileImmediately(PlayerWorldState.World world)
    {
        Vector3 p = GetProfileForWorld(world);
        SetVolume("GutsVolume", p.x);
        SetVolume("BiomineVolume", p.y);
        SetVolume("ViscusVolume", p.z);
    }


    // Returns (Guts, Biomine, Viscus) as linear values 0-1
    private Vector3 GetProfileForWorld(PlayerWorldState.World world)
    {
        switch (world)
        {
            case PlayerWorldState.World.Viscus:
                // Only Viscus at full volume
                return new Vector3(0f, 0f, 1f);

            case PlayerWorldState.World.Guts:
                // Guts full, Viscus at 50%
                return new Vector3(1f, 0f, 0.5f);

            case PlayerWorldState.World.Biomine:
                // Biomine full, Guts at 50%
                return new Vector3(0.5f, 1f, 0f);
        }

        return Vector3.zero;
    }

    // Sets a mixer parameter using a linear value (0-1)
    private void SetVolume(string paramName, float linear)
    {
        // Avoid -Infinity dB
        if (linear <= 0.0001f)
        {
            mixer.SetFloat(paramName, -80f); // mute floor
        }
        else
        {
            float db = Mathf.Log10(linear) * 20f;
            mixer.SetFloat(paramName, db);
        }
    }

    // Reads a mixer parameter and converts it from dB to linear 0-1
    private float GetLinear(string paramName)
    {
        if (mixer.GetFloat(paramName, out float db))
        {
            return Mathf.Pow(10f, db / 20f);
        }

        return 1f; // default fallback
    }
}
