module triton.common.examples.config;

import tango.io.Stdout;

import triton.common.config;
import triton.common.stringutils;

void main(string[] args)
{
    ConfigVar!(int) intVar = Config.lookup("myvar", 5, "mysetting");
    
    assert(intVar.val == 5);
    assert(intVar.dynamic == true);
    assert(intVar.automatic == false);
    
    intVar.val = 7;
    assert(intVar.val == 7);

    intVar.val = "10";
    assert(intVar.val == 10);
    
    ConfigVar!(string) stringVar = Config.lookup("stringvar", cast(string)("yo yo"), "my other setting");

    assert(stringVar.val == "yo yo");
    
    stringVar.val = "my my";
    assert(stringVar.val == "my my");
}
