/* To compile to .d:
   ragel uri_parser.rl -D -G2 -o uri.d
*/

module mordor.common.http.uri;

import tango.stdc.string;
import tango.text.Ascii;
import tango.text.Util;
import tango.util.Convert;

import mordor.common.ragel;
import mordor.common.stringutils;

private const string unreserved = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
private const string sub_delims = "!$&'()*+,;=";
private const string scheme = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-.";
private const string userinfo = unreserved ~ sub_delims ~ ":";
private const string host = unreserved ~ sub_delims ~ ":";
private const string pchar = unreserved ~ sub_delims ~ ":@";
private const string path = pchar ~ "/";
private const string segment_nc = unreserved ~ sub_delims ~ "@";
private const string query = pchar ~ "/?";

string escape(string str, string allowedChars)
out(result)
{
    if (str.ptr == result.ptr) {
        assert(result == str);
    } else {
        assert(result.length > str.length);
    }
}
body
{
    const string hexdigits = "0123456789ABCDEF";
    string result = str;
    foreach(i, c; str)
    {
        if (locate(allowedChars, c) == allowedChars.length) {
            if (result.ptr == str.ptr) {
                // "reserve" the full string length
                result = str.dup;
                result.length = i + 3;
                result[$-3] = '%';
                result[$-2] = hexdigits[(c >> 4)];
                result[$-1] = hexdigits[c & 0xf];
            } else {
                result.length = result.length + 3;
                result[$-3] = '%';
                result[$-2] = hexdigits[(c >> 4)];
                result[$-1] = hexdigits[c & 0xf];
            }
        } else {
            if (result.ptr != str.ptr) {
                result ~= c;
            }
        }
    }
    return result;
}

string unescape(string str)
{
    string result = str;
    for(size_t i = 0; i < str.length; ++i)
    {
        char c = str[i];
        if (c == '%') {
            assert(i + 2 < str.length);
            if (result.ptr == str.ptr) {
                result = str.dup;
                result.length = i + 1;
            } else {
                result.length = result.length + 1;
            }
            char decoded;
            c = str[++i];
            if (c >= 'a' && c <= 'f')
                decoded = (c - 'a' + 10) << 4;
            else if (c >= 'A' && c <= 'F')
                decoded = (c - 'A' + 10) << 4;
            else {
                assert(c >= '0' && c <='9');
                decoded = (c - '0') << 4;
            }
            c = str[++i];
            if (c >= 'a' && c <= 'f')
                decoded |= c - 'a' + 10;
            else if (c >= 'A' && c <= 'F')
                decoded |= c - 'A' + 10;
            else {
                assert(c >= '0' && c <='9');
                decoded |= c - '0';
            }
            result[$-1] = decoded;                               
        } else if (result.ptr != str.ptr) {
            result ~= c;
        }
    }
    return result;
}

string escapeScheme(string str)
{
    return escape(str, scheme);
}

string escapeUserinfo(string str)
{
    return escape(str, userinfo);
}

string escapeHost(string str)
{
    return escape(str, host);
}

string escapePath(string str)
{
    return escape(str, path);
}

string escapeQuery(string str)
{
    return escape(str, query);
}

string escapeFragment(string str)
{
    return escape(str, query);
}

struct URI
{
    static URI opCall(string uri)
    {
        URI target;
        target = uri;
        return target;
    }
    
    URI opAssign(string uri)
    {
        scope parser = new URIParser(*this);
        parser.run(uri);
        return *this;
    }
    
    void reset()
    {
        schemeDefined = false;
        authority.hostDefined = false;
        path.type = Path.Type.RELATIVE;
        path.segments.length = 0;
        queryDefined = false;
        fragmentDefined = false;
    }

    string scheme()
    in
    {
        assert(_schemeDefined);
    }
    body
    {
        return _scheme;
    }
    void scheme(string s)
    {
        _schemeDefined = true;
        _scheme = s;
    }
    bool schemeDefined() { return _schemeDefined; }
    void schemeDefined(bool d)
    {
        if (!d)
            _scheme.length = 0;
        _schemeDefined = d;        
    }
    
    struct Authority
    {
        string userinfo()
        in
        {
            assert(_userinfoDefined);
        }
        body
        {
            return _userinfo;
        }
        void userinfo(string ui)
        {
            _userinfoDefined = true;
            _hostDefined = true;
            _userinfo = ui;
        }
        bool userinfoDefined() { return _userinfoDefined; }
        void userinfoDefined(bool d)
        {
            if (!d)
                _userinfo.length = 0;
            _userinfoDefined = d;
        }
 
        // TODO: break down into IPv4, IPv6, regname
        string host()
        in
        {
            assert(_hostDefined);
        }
        body
        {
            return _host;
        }
        void host(string h)
        {
            _hostDefined = true;
            _host = h;
        }
        bool hostDefined() { return _hostDefined; }
        void hostDefined(bool d)
        {
            if (!d) {
                _host.length = 0;
                userinfoDefined = false;
                portDefined = false;
            }
            _hostDefined = d;
        }
 
        int port()
        in
        {
            assert(_portDefined);
        }
        body
        {
            return _port;
        }
        void port(int p)
        {
            _portDefined = true;
            _hostDefined = true;
            _port = p;
        }
        bool portDefined() { return _portDefined; }
        void portDefined(bool d)
        {
            if (!d)
                _port = -1;
            _portDefined = d;
        }

        string toString()
        in
        {
            assert(hostDefined);
        }
        body
        {
            string result;
            if (userinfoDefined) {
                result = escapeUserinfo(userinfo) ~ "@";
            }
            result ~= escapeHost(host);
            if (portDefined) {
                result ~= ":";
                if (port > 0) {
                    result ~= to!(string)(port);
                }
            }
            return result;
        }
        
        void normalize(string defaultHost = "", bool emptyHostValid = false,
                       int defaultPort = -1, bool emptyPortValid = false)
        {
            _host = toLower(_host);
            if (port == defaultPort)
                port = -1;
            if (port == -1 && !emptyPortValid)
                portDefined = false;
            if (_host == defaultHost)
                _host.length = 0;
            if (_host.length == 0 && !emptyHostValid && !userinfoDefined && !portDefined)
                hostDefined = false;
        }
    private:
        string _userinfo, _host;
        int _port = -1;
        bool _userinfoDefined, _hostDefined, _portDefined;
    }
    Authority authority;
    
    struct Path
    {
        enum Type
        {
            ABSOLUTE,
            RELATIVE
        }
        
        static Path opCall(string path)
        {
            Path result;
            result = path;
            return result;
        }
        
        Path opAssign(string path)
        {
            scope parser = new URIPathParser(*this);
            parser.run(path);
            return *this;        
        }
        
        Type type = Type.RELATIVE;
        bool isEmpty()
        {
            return type == Type.RELATIVE && segments.length == 0;
        }

        string toString(bool schemeless = false)
        {
            string result;
            if (segments.length == 0 && type == Type.ABSOLUTE)
                return "/";
            foreach(i, segment; segments)
            {
                if (i != 0 || type == Type.ABSOLUTE) {
                    result ~= "/";
                }
                if (i == 0 && type == Type.RELATIVE && schemeless) {
                    result ~= escape(segment, segment_nc);
                } else {
                    result ~= escape(segment, pchar);
                }                
            }
            return result;
        }
        
        void removeDotComponents()
        {
            for(int i = 0; i < segments.length; ++i) {
                if (segments[i] == ".") {
                    if (i + 1 == segments.length) {
                        segments[i].length = 0;
                        continue;
                    } else {
                        memmove(&segments[i], &segments[i + 1], (segments.length - i - 1) * string.sizeof);
                    }
                    segments.length = segments.length - 1;
                    --i;
                    continue;
                }
                if (segments[i] == "..") {
                    if (i == 0) {
                        segments = segments[1..$];
                        --i;
                        continue;
                    }
                    if (i + 1 == segments.length) {
                        segments.length = segments.length - 1;
                        segments[$-1].length = 0;
                        --i;
                        continue;
                    }
                    memmove(&segments[i - 1], &segments[i + 1], (segments.length - i - 1) * string.sizeof);
                    segments.length = segments.length - 2;
                    i -= 2;
                    continue;
                }
            }
        }
        
        unittest {
            Path p = Path("/a/b/c/./../../g");
            assert(p.toString() == "/a/b/c/./../../g");
            p.removeDotComponents();
            assert(p.toString() == "/a/g");
        }
        
        void normalize(bool emptyPathValid = false)
        {
            removeDotComponents();
            if (segments.length == 0 && !emptyPathValid)
                type = Type.ABSOLUTE;
        }
       
        // Concatenate rhs to this object, dropping least significant component
        // of this object first
        Path merge(Path rhs)
        in
        {
            assert(rhs.type == Type.RELATIVE);
        }
        body
        {
            if (segments.length > 0)
                segments = segments[0..$-1] ~ rhs.segments;
            else
                segments = rhs.segments;
            return *this;
        }

        string[] segments;
    }
    Path path;

    string query()
    in
    {
        assert(queryDefined);
    }
    body
    {
        return _query;
    }
    void query(string q)
    {
        _queryDefined = true;
        _query = q;
    }
    bool queryDefined() { return _queryDefined; }
    void queryDefined(bool d)
    {
        if (!d)
            _query.length = 0;
        _queryDefined = d;
    }

    string fragment()
    in
    {
        assert(fragmentDefined);
    }
    body
    {
        return _fragment;
    }
    void fragment(string f)
    {
        _fragmentDefined = true;
        _fragment = f;
    }
    bool fragmentDefined() { return _fragmentDefined; }
    void fragmentDefined(bool d)
    {
        if (!d)
            _fragment.length = 0;
        _fragmentDefined = d;
    }
    
    bool isDefined()
    {
        return schemeDefined || authority.hostDefined ||
            !path.isEmpty || queryDefined || fragmentDefined;
    }

    string toString()
    {
        string result;
        if (schemeDefined) {
            assert(authority.hostDefined || !path.isEmpty);
            result ~= escapeScheme(scheme) ~ ":";
        }
        
        if (authority.hostDefined) {
            result ~= "//" ~ authority.toString();
        }

        Path copy = path;
        if (authority.hostDefined) {
            copy.type = Path.Type.ABSOLUTE;
        }
        // Has scheme, but no authority, must ensure that an absolute path
        // doesn't begin with an empty segment (or could be mistaken for authority)
        if (schemeDefined && !authority.hostDefined &&
            copy.type == Path.Type.ABSOLUTE &&
            copy.segments.length > 0 && copy.segments[0].length == 0) {
            copy.segments.length = copy.segments.length + 1;
            memmove(&copy.segments[1], &copy.segments[0], (copy.segments.length - 1) * string.sizeof);
            copy.segments[0] = ".";
        }
        result ~= path.toString(!schemeDefined);
        
        if (queryDefined) {
            result ~= "?" ~ escapeQuery(query);
        }

        if (fragmentDefined) {
            result ~= "#" ~ escapeFragment(fragment);
        }
        return result;
    }

    void normalize()
    {
        _scheme = toLower(_scheme);
        switch(_scheme) {
            case "http":
            case "https":
                authority.normalize("", false, _scheme.length == 4 ? 80 : 443, false);
                path.normalize();
                break;
            case "file":
                authority.normalize("localhost", true);
                path.normalize();
                break;
            default:
                authority.normalize();
                path.normalize();
                break;                
        }
    }
    
    static URI transform(URI base, URI relative)
    in
    {
        assert(base.schemeDefined);
    }
    body
    {
        URI target;
        if (relative.schemeDefined) {
            target.scheme = relative.scheme;
            target.authority = relative.authority;
            target.path = relative.path;
            target.path.removeDotComponents();
            target._query = relative._query;
            target._queryDefined = relative._queryDefined;
        } else {
            if (relative.authority.hostDefined) {
                target.authority = relative.authority;
                target.path = relative.path;
                target.path.removeDotComponents();
                target._query = relative._query;
                target._queryDefined = relative._queryDefined;
            } else {
                if (relative.path.isEmpty) {
                    target.path = base.path;
                    if (relative.queryDefined) {
                        target.query = relative.query;
                    } else {
                        target._query = base.query;
                        target._queryDefined = base._queryDefined;
                    }
                } else {
                    if (relative.path.type == Path.Type.ABSOLUTE) {
                        target.path = relative.path;
                    } else {
                        target.path = base.path;
                        target.path.merge(relative.path);
                        if (!base.authority.hostDefined)
                            target.path.type = Path.Type.ABSOLUTE;
                    }
                    target.path.removeDotComponents();
                    target._query = relative._query;
                    target._queryDefined = relative._queryDefined;
                }
                target.authority = base.authority;
            }
            target.scheme = base.scheme;
        }
        target._fragment = relative._fragment;
        target._fragmentDefined = relative._fragmentDefined;
        return target;        
    }
    
    unittest
    {
        URI base = "http://a/b/c/d;p?q";
        assert(base.toString() == "http://a/b/c/d;p?q");
        assert(transform(base, URI("g:h")).toString() == "g:h");
        assert(transform(base, URI("g")).toString() == "http://a/b/c/g");
        assert(transform(base, URI("./g")).toString() == "http://a/b/c/g");
        assert(transform(base, URI("g/")).toString() == "http://a/b/c/g/");
        assert(transform(base, URI("/g")).toString() == "http://a/g");
        assert(transform(base, URI("//g")).toString() == "http://g");
        assert(transform(base, URI("?y")).toString() == "http://a/b/c/d;p?y");
        assert(transform(base, URI("g?y")).toString() == "http://a/b/c/g?y");
        assert(transform(base, URI("#s")).toString() == "http://a/b/c/d;p?q#s");
        assert(transform(base, URI("g#s")).toString() == "http://a/b/c/g#s");
        assert(transform(base, URI("g?y#s")).toString() == "http://a/b/c/g?y#s");
        assert(transform(base, URI(";x")).toString() == "http://a/b/c/;x");
        assert(transform(base, URI("g;x")).toString() == "http://a/b/c/g;x");
        assert(transform(base, URI("g;x?y#s")).toString() == "http://a/b/c/g;x?y#s");
        assert(transform(base, URI("")).toString() == "http://a/b/c/d;p?q");
        assert(transform(base, URI(".")).toString() == "http://a/b/c/");
        assert(transform(base, URI("./")).toString() == "http://a/b/c/");
        assert(transform(base, URI("..")).toString() == "http://a/b/");
        assert(transform(base, URI("../")).toString() == "http://a/b/");
        assert(transform(base, URI("../g")).toString() == "http://a/b/g");
        assert(transform(base, URI("../..")).toString() == "http://a/");
        assert(transform(base, URI("../../")).toString() == "http://a/");
        assert(transform(base, URI("../../g")).toString() == "http://a/g");
        
        assert(transform(base, URI("../../../g")).toString() == "http://a/g");
        assert(transform(base, URI("../../../../g")).toString() == "http://a/g");
        
        assert(transform(base, URI("/./g")).toString() == "http://a/g");
        assert(transform(base, URI("/../g")).toString() == "http://a/g");
        assert(transform(base, URI("g.")).toString() == "http://a/b/c/g.");
        assert(transform(base, URI(".g")).toString() == "http://a/b/c/.g");
        assert(transform(base, URI("g..")).toString() == "http://a/b/c/g..");
        assert(transform(base, URI("..g")).toString() == "http://a/b/c/..g");
        
        assert(transform(base, URI("./../g")).toString() == "http://a/b/g");
        assert(transform(base, URI("./g/.")).toString() == "http://a/b/c/g/");
        assert(transform(base, URI("g/./h")).toString() == "http://a/b/c/g/h");
        assert(transform(base, URI("g/../h")).toString() == "http://a/b/c/h");
        assert(transform(base, URI("g;x=1/./y")).toString() == "http://a/b/c/g;x=1/y");
        assert(transform(base, URI("g;x=1/../y")).toString() == "http://a/b/c/y");
        
        assert(transform(base, URI("g?y/./x")).toString() == "http://a/b/c/g?y/./x");
        assert(transform(base, URI("g?y/../x")).toString() == "http://a/b/c/g?y/../x");
        assert(transform(base, URI("g#s/./x")).toString() == "http://a/b/c/g#s/./x");
        assert(transform(base, URI("g#s/../x")).toString() == "http://a/b/c/g#s/../x");
        
        assert(transform(base, URI("http:g")).toString() == "http:g");
    }

private:
    string _scheme, _query, _fragment;
    bool _schemeDefined, _queryDefined, _fragmentDefined;
};

%%{

    machine uri_parser;

    gen_delims = ":" | "/" | "?" | "#" | "[" | "]" | "@";
    sub_delims = "!" | "$" | "&" | "'" | "(" | ")" | "*" | "+" | "," | ";" | "=";
    reserved = gen_delims | sub_delims;
    unreserved = alpha | digit | "-" | "." | "_" | "~";
    pct_encoded = "%" xdigit xdigit;
    
    action marku { mark = fpc; }
    action save_scheme
    {
        scheme = unescape(mark[0..fpc - mark]);
        mark = null;
    }

    scheme = (alpha | digit | "+" | "-" | ".")+ >marku %save_scheme;

    action save_port
    {
        if (fpc == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..fpc-mark]);
        mark = null;
    }
    action save_userinfo
    {
        authority.userinfo = unescape(mark[0..fpc - mark]);
        mark = null;
    }
    action save_host
    {
        authority.host = unescape(mark[0..fpc - mark]);
        mark = null;
    }
    
    userinfo = (unreserved | pct_encoded | sub_delims | ":")*;
    dec_octet = digit | [1-9] digit | "1" digit{2} | 2 [0-4] digit | "25" [0-5];
    IPv4address = dec_octet "." dec_octet "." dec_octet "." dec_octet;
    h16 = xdigit{1,4};
    ls32 = (h16 ":" h16) | IPv4address;
    IPv6address = (                         (h16 ":"){6} ls32) |
                  (                    "::" (h16 ":"){5} ls32) |
                  ((             h16)? "::" (h16 ":"){4} ls32) |
                  (((h16 ":"){1} h16)? "::" (h16 ":"){3} ls32) |
                  (((h16 ":"){2} h16)? "::" (h16 ":"){2} ls32) |
                  (((h16 ":"){3} h16)? "::" (h16 ":"){1} ls32) |
                  (((h16 ":"){4} h16)? "::"              ls32) |
                  (((h16 ":"){5} h16)? "::"              h16 ) |
                  (((h16 ":"){6} h16)? "::"                  );                  
    IPvFuture = "v" xdigit+ "." (unreserved | sub_delims | ":")+;
    IP_literal = "[" (IPv6address | IPvFuture) "]";
    reg_name = (unreserved | pct_encoded | sub_delims)*;
    host = IP_literal | IPv4address | reg_name;
    port = digit*;

    authority = ( (userinfo %save_userinfo "@")? host >marku %save_host (":" port >marku %save_port)? ) >marku;

    action save_segment
    {
        path.segments ~= unescape(mark[0..fpc - mark]);
        mark = null;
    }

    pchar = unreserved | pct_encoded | sub_delims | ":" | "@";
    segment = pchar* >marku %save_segment;
    segment_nz = pchar+ >marku %save_segment;
    segment_nz_nc = (pchar - ":")+ >marku %save_segment;
    
    action set_absolute
    {
        path.type = URI.Path.Type.ABSOLUTE;
    }
    action set_relative
    {
        path.type = URI.Path.Type.RELATIVE;
    }

    path_abempty = ("/" segment >set_absolute)*;
    path_absolute = "/" (segment_nz ("/" segment)*)? > set_absolute;
    path_noscheme = segment_nz_nc >set_relative ("/" segment)*;
    path_rootless = segment_nz >set_relative ("/" segment)*;
    path_empty = "" %set_relative;
    path = (path_abempty | path_absolute | path_noscheme | path_rootless | path_empty);

    action save_query
    {
        query = unescape(mark[0..fpc - mark]);
        mark = null;
    }
    action save_fragment
    {
        fragment = unescape(mark[0..fpc - mark]);
        mark = null;
    }

    query = (pchar | "/" | "?")* >marku %save_query;
    fragment = (pchar | "/" | "?")* >marku %save_fragment;
    
    hier_part = "//" authority path_abempty | path_absolute | path_rootless | path_empty;

    relative_part = "//" authority path_abempty | path_absolute | path_noscheme | path_empty;
    relative_ref = relative_part ( "?" query )? ( "#" fragment )?;
    
    absolute_URI = scheme ":" hier_part ( "?" query )? ;
    
    URI = scheme ":" hier_part ( "?" query )? ( "#" fragment )?;
    URI_reference = URI | relative_ref;
}%%


private class URIParser : RagelParser
{
private:
    %%{
        machine uri_parser_proper;
        include uri_parser;    
        main := URI_reference;
        write data;
    }%%

public:
    this(ref URI uri)
    {
        _uri = &uri;
    }

    void init()
    {
        super.init();
        %% write init;
    }

protected:
    void exec()
    {
        with(*_uri) {
            %% write exec;
        }
    }

public:
    bool complete()
    {
        return cs >= uri_parser_proper_first_final;
    }

    bool error()
    {
        return cs == uri_parser_proper_error;
    }

private: 
    URI* _uri;
}

private class URIPathParser : RagelParser
{
private:
    %%{
        machine uri_path_parser;
        include uri_parser;    
        main := path;
        write data;
    }%%

public:
    this(ref URI.Path _path)
    {
        path = &_path;
    }

    void init()
    {
        super.init();
        %% write init;
    }

protected:
    void exec()
    {
        %% write exec;
    }

public:
    bool complete()
    {
        return cs >= uri_path_parser_first_final;
    }

    bool error()
    {
        return cs == uri_path_parser_error;
    }

private: 
    URI.Path* path;
}
