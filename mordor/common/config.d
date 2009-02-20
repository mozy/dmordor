module mordor.common.config;

import tango.text.Ascii;
import tango.text.Util;
import tango.util.Convert;
import tango.sys.Environment;

import mordor.common.stringutils;

class ConfigVarBase
{
public:
    string name() { return _name; }
    string description() { return _description; }
    bool dynamic() { return _dynamic; }
    bool automatic() { return _automatic; }
    
    void monitor(void delegate() dg) { _dgs ~= dg; }
    void monitor(void function() fn) { _fns ~= fn; }
    
    abstract string toString();
    abstract void fromString(string v);

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
    
protected:
    void delegate()[] _dgs;
    void function()[] _fns;
}

class ConfigVar(T) : public ConfigVarBase
{
public:
    this(string name, /* invariant */ T defaultValue,
        string description,
        bool dynamic = true, bool automatic = false)
    {
        super(name, description, dynamic, automatic);
        static if (T.sizeof > size_t.sizeof) {
            _val = new Box(defaultValue);
        } else {
            _val = defaultValue;
        }
    }
    
    string toString() { return to!(string)(val); }
    void fromString(string v) { val = to!(T)(v); }

    static if (T.sizeof > size_t.sizeof) {
        /* invariant */ T val() { volatile return _val.val; }
        void val(/* invariant */ T v)
        {
            // TODO: atomicCompareExchange or something
            T oldVal = val;
            volatile _val = new Box(v);
            if (oldVal != val) {
                notify(oldVal);
            }
        }
    } else {
        /* invariant */ T val() { volatile return _val; }
        void val(/* invariant */ T v)
        {
            // TODO: atomicCompareExchange or something
            T oldVal = val;
            volatile _val = v;
            if (oldVal != val) {
                notify(oldVal);
            }
        }
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
    
    void notify(T oldVal)
    {
        foreach(dg; _dgs) {
            dg();
            if (oldVal != val) 
                return;
        }
        foreach(fn; _fns) {
            fn();
            if (oldVal != val)
                return;
        }
    }
}


class Config
{
public:
    static ConfigVar!(T) lookup(T)(string name,
        /* invariant */ T defaultValue, string description,
        bool dynamic = true, bool automatic = false)
    in
    {
        foreach(c; name) {
            assert((c >= 'a' && c <= 'z') || c == '.');
        }
    }
    body
    {
        synchronized (Config.classinfo) {
            assert ((name in _vars) is null);
            ConfigVar!(T) var = new ConfigVar!(T)(name,
                defaultValue, description, dynamic, automatic);
            _vars[name] = var;
            return var;
        }
    }
    
    static void loadFromEnvironment()
    {
        synchronized(Config.classinfo) {
            foreach(key, val; Environment.get) {
                toLower(key);
                replace(key, '_', '.');
                ConfigVarBase* var = key in _vars;
                if (var !is null) {
                    try {
                        var.fromString(val);
                    } catch (ConversionException)
                    {}
                }
            }
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
    
    ConfigVar!(string) stringVar = Config.lookup("stringvar", cast(string)("yo yo"), "my other setting");

    assert(stringVar.val == "yo yo");
    
    stringVar.val = "my my";
    assert(stringVar.val == "my my");
}
