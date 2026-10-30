using UnityEngine;

namespace Willosuna.Parallax
{
    public class DayNightBlend : MonoBehaviour
    {
        [Tooltip("Parents of the dawn, day, sunset and night layer sets, in that order. Each parent holds its layers as children, back to front.")]
        public Transform[] timeSets = new Transform[4];
        [Range(0f, 4f)] public float time = 1f;
        public bool cycle;
        public float cycleSeconds = 40f;
        public int baseSortingOrder = -100;

        SpriteRenderer[][] layers;

        void Start()
        {
            layers = new SpriteRenderer[timeSets.Length][];
            for (int i = 0; i < timeSets.Length; i++)
            {
                layers[i] = new SpriteRenderer[timeSets[i].childCount];
                for (int k = 0; k < timeSets[i].childCount; k++)
                    layers[i][k] = timeSets[i].GetChild(k).GetComponent<SpriteRenderer>();
            }
            Apply();
        }

        void Update()
        {
            if (cycle) time = Mathf.Repeat(time + Time.deltaTime * 4f / cycleSeconds, 4f);
            Apply();
        }

        public void SetTime(float value)
        {
            time = Mathf.Repeat(value, 4f);
            Apply();
        }

        void Apply()
        {
            if (layers == null) return;
            int a = Mathf.FloorToInt(time) % 4;
            int b = (a + 1) % 4;
            float f = time - Mathf.Floor(time);
            for (int i = 0; i < layers.Length; i++)
            {
                bool on = i == a || (i == b && f > 0f);
                timeSets[i].gameObject.SetActive(on);
                for (int k = 0; k < layers[i].Length; k++)
                {
                    var sr = layers[i][k];
                    if (sr == null) continue;
                    sr.sortingOrder = baseSortingOrder + k * 2 + (i == b ? 1 : 0);
                    var c = sr.color;
                    c.a = i == b ? f : 1f;
                    sr.color = c;
                    foreach (var child in sr.GetComponentsInChildren<SpriteRenderer>())
                    {
                        child.sortingOrder = sr.sortingOrder;
                        child.color = c;
                    }
                }
            }
        }
    }
}
