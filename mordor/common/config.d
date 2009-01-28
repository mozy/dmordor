module mordor.common.config;

import tango.core.Atomic;
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
    this(string name, string defaultValue, string description,
        bool dynamic = true, bool automatic = false)
    {
        super(name, description, dynamic, automatic);
        val = defaultValue;
    }
    string toString() { return to!(string)(_val); }

    /* invariant */ T val() { return atomicLoad(_val); }
    void val(/* invariant */ T v) { atomicStore(_val, v); }
    void val(string v) { val = to!(T)(v); }

private:
    T _val;
}

class ConfigVar(T : string) : public ConfigVarBase
{
public:
    this(string name, /* invariant */ string defaultValue,
        string description,
        bool dynamic = true, bool automatic = false)
    {
        super(name, description, dynamic, automatic);
        val = defaultValue;
    }
    string toString() { return val; }

    /* invariant */ string val() { return atomicLoad(_val).val; }
    void val(/* invariant */ string v) { atomicStore(_val, new Container(v)); }

private:
    class Container {
    public:
        this(string v) { val = v; }
        string val;
    }
    Container _val;
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
            ConfigVar!(T)* pvar = cast(ConfigVar!(T)*)(name in _vars);
            if (pvar is null) {
                ConfigVar!(T) var = new ConfigVar!(T)(name,
                    defaultValue, description, dynamic, automatic);
                _vars[name] = var;
                return var;
            }
            return *pvar;
        }
    }

    static synchronized ConfigVar!(T) lookup(T)(string name,
        string defaultValue, string description,
        bool dynamic = true, bool automatic = false)
    {
        synchronized (Config.classinfo) {
            ConfigVar!(T)* pvar = cast(ConfigVar!(T)*)(name in _vars);
            if (var is null) {
                ConfigVar!(T) var = new ConfigVar!(T)(name,
                    defaultValue, description, dynaimc, automatic);
                _vars[name] = var;
                return var;
            }
            return *pvar;
        }
    }
    
private:
    static ConfigVarBase[string] _vars;
}
