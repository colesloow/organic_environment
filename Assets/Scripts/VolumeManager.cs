using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Audio;

public class VolumeManager : MonoBehaviour
{
    public AudioMixer mixer;
    public PlayerWorldState playerWorldState;

    private void Start()
    {
        playerWorldState.WorldChanged += OnWorldChanged;
    }

    private void OnDisable()
    {
        playerWorldState.WorldChanged -= OnWorldChanged;
    }

    private void OnWorldChanged(PlayerWorldState.World world)
    {
        switch(world)
        {
            case PlayerWorldState.World.Guts: EnterGuts(); break;
            case PlayerWorldState.World.Biomine: EnterBiomine(); break;
            case PlayerWorldState.World.Viscus: EnterViscus(); break;
        }
    }

    void SetVolume(string name, float volume)
    {
        mixer.SetFloat(name, 20f * Mathf.Log10(volume));
    }

    void EnterGuts()
    {
        SetVolume("GutsVolume", 1);
        SetVolume("BiomineVolume", 0);
        SetVolume("ViscusVolume", 0);
    }

    void EnterBiomine()
    {
        SetVolume("GutsVolume", 0);
        SetVolume("BiomineVolume", 1);
        SetVolume("ViscusVolume", 0);
    }

    void EnterViscus()
    {
        SetVolume("GutsVolume", 0);
        SetVolume("BiomineVolume", 0);
        SetVolume("ViscusVolume", 1);
    }
}
