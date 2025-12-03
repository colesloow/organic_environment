using System;
using UnityEngine;

public class PlayerWorldState : MonoBehaviour
{
    public enum World
    {
        Viscus,
        Guts,
        Biomine
    }

    [Header("Start world")]
    [SerializeField] private World startWorld = World.Viscus;

    [Header("Spawn points")]
    [SerializeField] private Transform viscusSpawn;
    [SerializeField] private Transform gutsSpawn;
    [SerializeField] private Transform biomineSpawn;

    // Event fired whenever the world changes
    public event Action<World> WorldChanged;

    private World currentWorld;
    public World CurrentWorld => currentWorld;

    private void Awake()
    {
        // Initial world
        currentWorld = startWorld;

        // Teleport to start spawn
        Transform spawn = GetSpawnForWorld(startWorld);
        if (spawn != null)
        {
            transform.position = spawn.position;
        }

        Debug.Log($"[PlayerWorldState] Start in world: {currentWorld}, position: {transform.position}");
    }

    public void SetWorld(World newWorld)
    {
        if (newWorld == currentWorld)
            return;

        currentWorld = newWorld;
        Debug.Log($"[PlayerWorldState] Current world: {currentWorld}");

        WorldChanged?.Invoke(currentWorld);
    }

    private Transform GetSpawnForWorld(World world)
    {
        switch (world)
        {
            case World.Viscus: return viscusSpawn;
            case World.Guts: return gutsSpawn;
            case World.Biomine: return biomineSpawn;
            default: return null;
        }
    }
}
