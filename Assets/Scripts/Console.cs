using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Console : MonoBehaviour {

    public Text ui_text;

    // For now, symbols = 3x3 ascii
    // map symbol name -> array of bottom, middle, top strings of 3 chars.
    private Dictionary<string, string[]> map;

    // Array of text symbols; each string indexes into 'map'
    private string[] text_symbols;
    // Use this for initialization
    void Start () {
        this.map = new Dictionary<string, string[]>()
        {
            { "zero", new string[] { "---", "---", "---" } }, // bottom, left-to-right. middle, left-to-right. top, left-to-right.
            { "one",  new string[] { "--\\", "---", "---" } },
            { "two",  new string[] { "-\\/", "---", "---" } },
            { "plus",  new string[] { " | ", "-+-", " | " } },
            { "equals",  new string[] { "---", "   ", "---" } },
            { "space",  new string[] { "   ", "   ", "   " } },
        };
        // left-to-right.
        this.text_symbols = new string[] { "zero", "one", "plus", "two", "equals" };

        ui_text.text = "Hello, World!";
	}
	
	// Update is called once per frame
    // Display routine, translates to right-to-left

    // TODO a teletype effect would be cool - building up each symbol and the overall text in the bottom-to-top, right-to-left order.
	void Update () {
        // TODO const int width_in_symbols = 16;
        // TODO traverse a row at a time
        string bottom_row = "";
        for (int i = 0; i < this.text_symbols.Length; ++i)
        {
            string[] symbol_array = this.map[this.text_symbols[i]];
            // TODO assert(symbol_array.Length == 3)
            bottom_row = symbol_array[0] + " " + bottom_row;
        }
        string middle_row = "";
        for (int i = 0; i < this.text_symbols.Length; ++i)
        {
            string[] symbol_array = this.map[this.text_symbols[i]];
            // TODO assert(symbol_array.Length == 3)
            middle_row = symbol_array[1] + " " + middle_row;
        }
        string top_row = "";
        for (int i = 0; i < this.text_symbols.Length; ++i)
        {
            string[] symbol_array = this.map[this.text_symbols[i]];
            // TODO assert(symbol_array.Length == 3)
            top_row = symbol_array[2] + " " + top_row;
        }
        ui_text.text = top_row + "\n" + middle_row + "\n" + bottom_row;
    }
}
