using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Audio;

public class VolumeManager : MonoBehaviour
{
    public AudioMixer mixer;

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
