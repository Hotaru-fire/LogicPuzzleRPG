using UnityEngine;

namespace Willosuna.Parallax
{
    [RequireComponent(typeof(SpriteRenderer))]
    public class ParallaxLayer : MonoBehaviour
    {
        public Transform cameraTransform;
        [Range(0f, 1f)] public float scrollScale = 0.5f;
        public float autoscrollPixelsPerSecond = 0f;
        public float pixelsPerUnit = 16f;

        float width;
        float startX;
        float drift;

        void Start()
        {
            if (cameraTransform == null && Camera.main != null) cameraTransform = Camera.main.transform;
            var sr = GetComponent<SpriteRenderer>();
            width = sr.bounds.size.x;
            startX = transform.position.x;
            for (int side = -1; side <= 1; side += 2)
            {
                var copy = new GameObject(name + (side < 0 ? "_left" : "_right"));
                copy.transform.SetParent(transform, false);
                copy.transform.localPosition = new Vector3(side * width / transform.lossyScale.x, 0f, 0f);
                var csr = copy.AddComponent<SpriteRenderer>();
                csr.sprite = sr.sprite;
                csr.sortingLayerID = sr.sortingLayerID;
                csr.sortingOrder = sr.sortingOrder;
                csr.color = sr.color;
            }
        }

        void LateUpdate()
        {
            if (cameraTransform == null) return;
            drift += autoscrollPixelsPerSecond / pixelsPerUnit * Time.deltaTime;
            float camX = cameraTransform.position.x;
            float x = startX + camX * scrollScale + drift;
            float offset = camX - x;
            x += Mathf.Floor(offset / width + 0.5f) * width;
            transform.position = new Vector3(x, transform.position.y, transform.position.z);
        }
    }
}
