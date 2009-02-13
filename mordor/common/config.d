module mordor.common.config;

import tango.util.Convert;

import mordor.common.stringutils;

class ConfigVarBase
{
public:
    string name() { return _name; }
    string description() { return _description; }
    bool dynamic() { return _dynamic; }
    bool automatic() { return _automatic; }
    abstract string toString();
    abstract void val(string v);

protected:
    this(string name, string description, bool dynamic,
        bool automatic)
    {
        _name = name;
        _description = description;
        _dynamic = dynamic;
        _automatic = automatic;
    }
        
private:
    string _name;
    string _description;
    bool _dynamic;
    bool _automatic;
}

class ConfigVar(T) : public ConfigVarBase
{
public:
    this(string name, /* invariant */ T defaultValue,
        string description,
        bool dynamic = true, bool automatic = false)
    {
        super(name, description, dynamic, automatic);
        val = defaultValue;
    }
    static if (!is(T : string)) {
        this(string name, string defaultValue, string description,
            bool dynamic = true, bool automatic = false)
        {
            super(name, description, dynamic, automatic);
            val = defaultValue;
        }
    }
    string toString() { return to!(string)(val); }
    
    static if(is(T : string)) {
        /* invariant */ T val() { volatile return _val.val; }
        void val(string v) { volatile _val = new Box(v); }
    } else static if (T.sizeof > size_t.sizeof) {
        /* invariant */ T val() { volatile return _val.val; }
        void val(/* invariant */ T v) { volatile _val = new Box(v); }
        void val(string v) { val = to!(T)(v); }
    } else {
        /* invariant */ T val() { volatile return _val; }
        void val(/* invariant */ T v) { volatile _val = v; }
        void val(string v) { val = to!(T)(v); }
    }

private:
    static if (T.sizeof > size_t.sizeof) {
        class Box {
        public:
            this(T v) { val = v; }
            T val;
        }
        Box _val;
    } else {
        T _val;
    }
}


class Config
{
public:
    static ConfigVar!(T)* lookup(T)(string name)
    {
        synchronized (Config.classinfo) {
            return cast(ConfigVar!(T)*)(name in _vars);
        }
    }
    
    static ConfigVar!(T) lookup(T)(string name,
        /* invariant */ T defaultValue, string description,
        bool dynamic = true, bool automatic = false)
    {
        synchronized (Config.classinfo) {
            assert ((name in _vars) is null);
            ConfigVar!(T) var = new ConfigVar!(T)(name,
                defaultValue, description, dynamic, automatic);
            _vars[name] = var;
            return var;
        }
    }

    static ConfigVar!(T) lookup(T)(string name,
        string defaultValue, string description,
        bool dynamic = true, bool automatic = false)
    {
        synchronized (Config.classinfo) {
            assert ((name in _vars) is null);
            ConfigVar!(T) var = new ConfigVar!(T)(name,
                defaultValue, description, dynamic, automatic);
            _vars[name] = var;
            return var;
        }
    }
    
private:
    static ConfigVarBase[string] _vars;
}

import tango.io.Stdout;
unittest
{
    Stdout.formatln("in config unit test");
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
