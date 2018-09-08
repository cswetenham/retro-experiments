using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightController : MonoBehaviour {
    public Vector3 origin;
    public float wobble_height;
    public float wobble_period_s;
    public float orbit_radius;
    public float orbit_period_s;

	// Use this for initialization
	void Start () {
		
	}
	
	// Update is called once per frame
	void Update () {
        GetComponent<Rigidbody>().position = origin + new Vector3
        (
            orbit_radius * Mathf.Cos(2.0f * Mathf.PI * Time.time / orbit_period_s),
            wobble_height * Mathf.Cos(2.0f * Mathf.PI * Time.time / wobble_period_s),
            orbit_radius * Mathf.Sin(2.0f * Mathf.PI * Time.time / orbit_period_s)
        );
    }
}
