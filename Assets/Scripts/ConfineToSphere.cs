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
        var maxRadius = sphereCollider.radius * Mathf.Max(
            sphereCollider.transform.localScale.x,
            sphereCollider.transform.localScale.y,
            sphereCollider.transform.localScale.z);
        
        var offset = targetTransform.position - center;
        var distanceFromCenter = offset.magnitude;

        if (!(distanceFromCenter <= maxRadius)) return;
        
        var confinedRadius = maxRadius - padding;
            
        if (distanceFromCenter > confinedRadius)
        {
            targetTransform.position = center + offset.normalized * confinedRadius;
        }
    }
}