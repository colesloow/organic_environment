using UnityEngine;

public class ConfineToSphere : MonoBehaviour
{
    [SerializeField] public SphereCollider sphereCollider;
    [SerializeField] public Transform      targetTransform;
    [SerializeField] public float          padding = 20f;

    private void Start()
    {
        sphereCollider = GetComponent<SphereCollider>();
    }

    private void Update()
    {
        var center = sphereCollider.transform.TransformPoint(sphereCollider.center);
        var radius = sphereCollider.radius * Mathf.Max(
            sphereCollider.transform.localScale.x,
            sphereCollider.transform.localScale.y,
            sphereCollider.transform.localScale.z) - padding;

        var offset = targetTransform.position - center;

        if (offset.sqrMagnitude > radius * radius)
        {
            // Ramener le joueur à l'intérieur
            targetTransform.position = center + offset.normalized * radius;
        }
    }
}