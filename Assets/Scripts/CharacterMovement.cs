using UnityEngine;
using UnityEngine.InputSystem;

public class CharacterMovement : MonoBehaviour
{
    [Header("Movement")]
    public float moveSpeed = 5f;
    public float sprintSpeed = 8f;
    public float acceleration = 10f;

    [Header("Mouse Look")]
    public float lookSensitivity = 120f;
    public Transform cameraTransform;

    [Header("Input Actions")]
    public InputActionReference moveAction;   // Vector2
    public InputActionReference lookAction;   // Vector2
    public InputActionReference sprintAction; // Button

    private float pitch = 0f;
    private Vector3 currentVelocity = Vector3.zero;

    private void OnEnable()
    {
        moveAction?.action.Enable();
        lookAction?.action.Enable();
        sprintAction?.action.Enable();
    }

    private void OnDisable()
    {
        moveAction?.action.Disable();
        lookAction?.action.Disable();
        sprintAction?.action.Disable();
    }

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        HandleLook();
        HandleMovement3D();
    }

    void HandleLook()
    {
        Vector2 lookInput = lookAction.action.ReadValue<Vector2>();

        float mouseX = lookInput.x * lookSensitivity * Time.deltaTime;
        float mouseY = lookInput.y * lookSensitivity * Time.deltaTime;

        // yaw (horizontal rotation)
        transform.Rotate(Vector3.up * mouseX);

        // pitch (vertical rotation)
        pitch -= mouseY;
        pitch = Mathf.Clamp(pitch, -85f, 85f);
        cameraTransform.localRotation = Quaternion.Euler(pitch, 0, 0);
    }

    void HandleMovement3D()
    {
        Vector2 moveInput = moveAction.action.ReadValue<Vector2>();
        bool isSprinting = sprintAction.action.IsPressed();

        float speed = isSprinting ? sprintSpeed : moveSpeed;

        // full 3D movement based on camera orientation
        Vector3 forward = cameraTransform.forward;
        Vector3 right = cameraTransform.right;

        forward.Normalize();
        right.Normalize();

        Vector3 desiredVelocity =
            forward * moveInput.y +
            right * moveInput.x;

        desiredVelocity *= speed;

        // Smooth movement
        currentVelocity = Vector3.Lerp(currentVelocity, desiredVelocity, acceleration * Time.deltaTime);

        transform.position += currentVelocity * Time.deltaTime;
    }
}
