using UnityEngine;

public class TeleportToPoints : MonoBehaviour
{
    [SerializeField] private Transform point1;
    [SerializeField] private Transform point2;
    [SerializeField] private Transform point3;

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            MoveTo(point1);
        }

        if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            MoveTo(point2);
        }

        if (Input.GetKeyDown(KeyCode.Alpha3))
        {
            MoveTo(point3);
        }
    }

    void MoveTo(Transform target)
    {
        if (target != null)
        {
            transform.position = target.position;
        }
    }
}
