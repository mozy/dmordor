module mordor.kalypso.vfs.triton;

import tango.core.Variant;
import tango.net.InternetAddress;
import tango.text.Util;
import tango.util.Convert;
import tango.util.log.Log;

import mordor.common.asyncsocket;
import mordor.common.config;
import mordor.common.exception;
import mordor.common.http.client;
import mordor.common.http.pool;
import mordor.common.iomanager;
import mordor.common.streams.socket;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;
import mordor.triton.client.list;

private Logger _log;
private TritonVFS _vfs;
private ConfigVar!(string) _host;
private ConnectionPool _pool;
private IOManager _ioManager;

static this()
{
    _log = Log.lookup("mordor.common.kalypso.vfs.triton");
    _vfs = new TritonVFS;
    _host = Config.lookup!(string)("mordor.common.kalypso.vfs.triton.tritonhost",
            "10.135.1.17:80",
            "Triton hostname[:port]");
    _ioManager = new IOManager(1, false);
    _pool = new ConnectionPool(delegate ClientConnection() {
            AsyncSocket s = new AsyncSocket(_ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
            s.connect(new InternetAddress(_host.val));
            SocketStream stream = new SocketStream(s);

            return new ClientConnection(stream);
        });
}

private struct PropertyDetails
{
    bool creatable;
    bool settable;
}

class TritonVFS : IVFS
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }
private:
    this()
    {}
    
public:
    static TritonVFS get() {
        return _vfs;
    }
    
    IObject parent() { return null; }
   
    int children(int delegate(ref IObject) dg)
    {
        int ret;
        foreach (u; _users) {
            IObject obj = u;
            if ( (ret = dg(obj)) != 0) return ret;
        }
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant("triton");
            case "type":
                return Variant("vfs");
            default:
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }
    
    void opIndexAssign(Variant value, string property)
    {}
    
    void opSliceAssign(Variant[string] properties)
    {}
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }
    
    IObject find(string path) {
        // TODO: implement
        return null;
    }
    
    IObject registerContainer(string user, long container)
    {
        foreach(u; _users) {
            if (u._user == user) {
                return u.registerContainer(container);
            }
        }
        _users ~= new TritonUser(user);
        return _users[$-1].registerContainer(container);
    }

private:
    static PropertyDetails[string] _properties;
    
    TritonUser[] _users;
}

class TritonUser : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }
    
    this(string user)
    {
        _user = user;
    }    
    
    IObject registerContainer(long container)
    {
        _containers ~= new TritonContainer(this, container);
        return _containers[$-1];
    }

    IObject parent() { return _vfs; }
    
    int children(int delegate(ref IObject) dg)
    {
        int ret;
        foreach (c; _containers) {
            IObject obj = c;
            if ( (ret = dg(obj)) != 0) return ret;
        }
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_user);
            case "type":
                return Variant("user");
            default:
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }

    void opIndexAssign(Variant value, string property)
    {}

    void opSliceAssign(Variant[string] properties)
    {}

    void _delete()
    { assert(false); }

    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }

    IObject find(string path)
    {
        // TODO: implement
        return null;        
    }

private:
    static PropertyDetails[string] _properties;

    string _user;
    TritonContainer[] _containers;
}

class TritonContainer : TritonDirectory
{    
    this(TritonUser user, long container)
    {
        super(this, "");
        _user = user;
        _container = container;
    }

    IObject parent() { return _user; }

    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(to!(string)(_container));
            case "type":
                return Variant("container");
            default:
                return super[property];
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }

    void opIndexAssign(Variant value, string property)
    {}

    void opSliceAssign(Variant[string] properties)
    {}

    void _delete()
    { assert(false); }

    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }

    IObject find(string path)
    {
        // TODO: actually do a HEAD request to determine the type, or look in a cache
        return new TritonDirectory(this, path);
    }

private:
    TritonUser _user;
    long _container;
}

class TritonDirectory : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }
    
    this(TritonContainer container, string path)
    {
        _container = container;
        _path = path;
        if (path.length > 0) {
            char slashChar = _path[0] == '/' ? '/' : '\\';
            size_t slash = locatePrior(_path, slashChar);
            if (slash == _path.length)
                _name = _path;
            else
                _name = _path[slash + 1..$];
            _path ~= slashChar;
        }
    }

    IObject parent()
    {
        _log.trace("Getting parent of '{}'", _path);
        char slashChar = _path[0] == '/' ? '/' : '\\';
        return new TritonDirectory(_container, _path[0..locatePrior(_path, slashChar, _path.length - 1)]);        
    }
    
    int children(int delegate(ref IObject) dg)
    {
        list(_pool.get(0), _container._user._user, _container._container, _path, false, "", -1, false, true,
            delegate void(string file, bool isdir) {
                int ret;
                IObject obj;
                if (isdir) {
                    obj = new TritonDirectory(_container, file);
                } else {
                    obj = new TritonFile(_container, file);
                }
                if (obj !is null) {
                    if ( (ret = dg(obj)) != 0) {
                        // TODO: throw exception?
                        throw new Exception("iteration aborted");
                    }                    
                }
            });
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "type":
                return Variant("directory");
            default:
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }

    void opIndexAssign(Variant value, string property)
    {}

    void opSliceAssign(Variant[string] properties)
    {}

    void _delete()
    { assert(false); }

    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }
    
    IObject find(string path)
    {
        _log.trace("Find on '{}' for '{}'", _path, path);
        if (path.length == 0)
            return this;
        // TODO: actually do a HEAD request to determine the type, or look in a cache
        return new TritonDirectory(_container, _path ~ path);
    }

private:
    static PropertyDetails[string] _properties;

    TritonContainer _container;
    string _path;
    string _name;
}

class TritonFile : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }
    
    this(TritonContainer container, string path)
    {
        _container = container;
        _path = path;
        if (path.length > 0) {
            char slashChar = _path[0] == '/' ? '/' : '\\';
            size_t slash = locatePrior(_path, slashChar);
            if (slash == _path.length)
                _name = _path;
            else
                _name = _path[slash + 1..$];
        }
    }

    IObject parent()
    {
        char slashChar = _path[0] == '/' ? '/' : '\\';
        return new TritonDirectory(_container, _path[0..locatePrior(_path, slashChar)]);        
    }
    
    int children(int delegate(ref IObject) dg)
    {
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "type":
                return Variant("file");
            default:
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }

    void opIndexAssign(Variant value, string property)
    {}

    void opSliceAssign(Variant[string] properties)
    {}

    void _delete()
    { assert(false); }

    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }
    
    IObject find(string path)
    {
        return null;
    }

private:
    static PropertyDetails[string] _properties;

    TritonContainer _container;
    string _path;
    string _name;
}
