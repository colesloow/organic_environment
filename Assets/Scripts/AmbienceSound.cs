using UnityEngine;
using UnityEngine.Audio;

public class AmbienceSound : MonoBehaviour
{
    [Tooltip("Area of the sound to be in")]
    public Collider Area;
    [Tooltip("Character to track")]
    public GameObject Player;
    public AudioSource BackgroundMusic;
    public AudioSource AmbientSound;

    void Update()
    {
        if (Area.bounds.Contains(Player.transform.position))
        {
            if (!BackgroundMusic.isPlaying)
            {
                BackgroundMusic.Play();
            }
            if (!AmbientSound.isPlaying)
            {
                AmbientSound.Play();
            }
        }
        else
        {
            if (BackgroundMusic.isPlaying)
            {
                BackgroundMusic.Pause();
            }
            if (AmbientSound.isPlaying)
            {
                AmbientSound.Pause();
            }
        }
    }
}