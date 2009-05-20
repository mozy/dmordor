#line 1 "uri_parser.rl"
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
            if (_port == defaultPort)
                _port = -1;
            if (_port == -1 && !emptyPortValid)
                _portDefined = false;
            if (_host == defaultHost)
                _host.length = 0;
            if (_host.length == 0 && !emptyHostValid && !userinfoDefined && !_portDefined)
                _hostDefined = false;
        }
        
        bool opEquals(ref Authority rhs)
        {
            return _userinfo == rhs._userinfo && _host == rhs._host &&
                _port == rhs._port && _userinfoDefined == rhs._userinfoDefined &&
                _hostDefined == rhs._hostDefined && _portDefined == rhs._portDefined;
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
        
        bool opEquals(ref Path rhs)
        {
            return type == rhs.type && segments == rhs.segments;
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
        if (_scheme.length > 0) {
            string newScheme;
            newScheme.length = _scheme.length;
            _scheme = toLower(_scheme, newScheme);
        }
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
    
    bool opEquals(ref URI rhs)
    {
        return _scheme == rhs._scheme && authority == rhs.authority &&
               path == rhs.path && _query == rhs._query && _fragment == rhs._fragment &&
               _schemeDefined == rhs._schemeDefined && _queryDefined == rhs._queryDefined &&
               _fragmentDefined == rhs._fragmentDefined;
    }
    
    unittest
    {
        URI lhs = "example://a/b/c/%7Bfoo%7D";
        URI rhs = "eXAMPLE://a/./b/../b/%63/%7bfoo%7d";
        
        lhs.normalize();
        rhs.normalize();
        assert(lhs._schemeDefined == rhs._schemeDefined);
        assert(lhs._scheme == rhs._scheme);
        assert(lhs.authority._portDefined == rhs.authority._portDefined);
        assert(lhs.authority._port == rhs.authority._port);
        assert(lhs.authority._hostDefined == rhs.authority._hostDefined);
        assert(lhs.authority._host == rhs.authority._host);
        assert(lhs.authority._userinfoDefined == rhs.authority._userinfoDefined);
        assert(lhs.authority._userinfo == rhs.authority._userinfo);
        assert(lhs.authority == rhs.authority);
        assert(lhs.path.type == rhs.path.type);
        assert(lhs.path.segments == rhs.path.segments);
        assert(lhs.path == rhs.path);
        assert(lhs._queryDefined == rhs._queryDefined);
        assert(lhs._query == rhs._query);
        assert(lhs._fragmentDefined == rhs._fragmentDefined);
        assert(lhs._fragment == rhs._fragment);
        assert(lhs == rhs);
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

#line 790 "uri_parser.rl"



private class URIParser : RagelParser
{
private:
    
#line 690 "uri.d"
static const int uri_parser_proper_start = 231;
static const int uri_parser_proper_first_final = 231;
static const int uri_parser_proper_error = 0;

static const int uri_parser_proper_en_main = 231;

#line 801 "uri_parser.rl"


public:
    this(ref URI uri)
    {
        _uri = &uri;
    }

    void init()
    {
        super.init();
        
#line 710 "uri.d"
	{
	cs = uri_parser_proper_start;
	}
#line 813 "uri_parser.rl"
    }

protected:
    void exec()
    {
        with(*_uri) {
            
#line 722 "uri.d"
	{
	if ( p == pe )
		goto _test_eof;
	switch ( cs )
	{
case 231:
	switch( (*p) ) {
		case 33u: goto tr234;
		case 35u: goto tr235;
		case 37u: goto tr236;
		case 43u: goto tr237;
		case 47u: goto st241;
		case 59u: goto tr234;
		case 61u: goto tr234;
		case 63u: goto tr239;
		case 64u: goto tr234;
		case 95u: goto tr234;
		case 126u: goto tr234;
		default: break;
	}
	if ( (*p) < 45u ) {
		if ( 36u <= (*p) && (*p) <= 44u )
			goto tr234;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr237;
		} else if ( (*p) >= 65u )
			goto tr237;
	} else
		goto tr237;
	goto st0;
st0:
cs = 0;
	goto _out;
tr234:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st232;
st232:
	if ( ++p == pe )
		goto _test_eof232;
case 232:
#line 770 "uri.d"
	switch( (*p) ) {
		case 33u: goto st232;
		case 35u: goto tr240;
		case 37u: goto st3;
		case 47u: goto tr242;
		case 59u: goto st232;
		case 61u: goto st232;
		case 63u: goto tr243;
		case 95u: goto st232;
		case 126u: goto st232;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 57u )
			goto st232;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st232;
	} else
		goto st232;
	goto st0;
tr235:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
	goto st233;
tr240:
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr248:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr254:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 768 "uri_parser.rl"
	{
        query = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr256:
#line 768 "uri_parser.rl"
	{
        query = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr263:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
	goto st233;
tr269:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr280:
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr285:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st233;
tr291:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	goto st233;
tr295:
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	goto st233;
st233:
	if ( ++p == pe )
		goto _test_eof233;
case 233:
#line 891 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr244;
		case 37u: goto tr245;
		case 61u: goto tr244;
		case 95u: goto tr244;
		case 126u: goto tr244;
		default: break;
	}
	if ( (*p) < 63u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr244;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr244;
	} else
		goto tr244;
	goto st0;
tr244:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st234;
st234:
	if ( ++p == pe )
		goto _test_eof234;
case 234:
#line 917 "uri.d"
	switch( (*p) ) {
		case 33u: goto st234;
		case 37u: goto st1;
		case 61u: goto st234;
		case 95u: goto st234;
		case 126u: goto st234;
		default: break;
	}
	if ( (*p) < 63u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st234;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st234;
	} else
		goto st234;
	goto st0;
tr245:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st1;
st1:
	if ( ++p == pe )
		goto _test_eof1;
case 1:
#line 943 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st2;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st2;
	} else
		goto st2;
	goto st0;
st2:
	if ( ++p == pe )
		goto _test_eof2;
case 2:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st234;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st234;
	} else
		goto st234;
	goto st0;
tr236:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st3;
st3:
	if ( ++p == pe )
		goto _test_eof3;
case 3:
#line 978 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st4;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st4;
	} else
		goto st4;
	goto st0;
st4:
	if ( ++p == pe )
		goto _test_eof4;
case 4:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st232;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st232;
	} else
		goto st232;
	goto st0;
tr242:
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st235;
tr250:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st235;
st235:
	if ( ++p == pe )
		goto _test_eof235;
case 235:
#line 1021 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr247;
		case 35u: goto tr248;
		case 37u: goto tr249;
		case 47u: goto tr250;
		case 61u: goto tr247;
		case 63u: goto tr251;
		case 95u: goto tr247;
		case 126u: goto tr247;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr247;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr247;
	} else
		goto tr247;
	goto st0;
tr260:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st236;
tr247:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st236;
tr262:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st236;
st236:
	if ( ++p == pe )
		goto _test_eof236;
case 236:
#line 1066 "uri.d"
	switch( (*p) ) {
		case 33u: goto st236;
		case 35u: goto tr240;
		case 37u: goto st5;
		case 47u: goto tr242;
		case 61u: goto st236;
		case 63u: goto tr243;
		case 95u: goto st236;
		case 126u: goto st236;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st236;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st236;
	} else
		goto st236;
	goto st0;
tr261:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st5;
tr249:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st5;
tr264:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st5;
st5:
	if ( ++p == pe )
		goto _test_eof5;
case 5:
#line 1111 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st6;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st6;
	} else
		goto st6;
	goto st0;
st6:
	if ( ++p == pe )
		goto _test_eof6;
case 6:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st236;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st236;
	} else
		goto st236;
	goto st0;
tr239:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
	goto st237;
tr243:
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st237;
tr251:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st237;
tr266:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
	goto st237;
tr277:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st237;
tr283:
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st237;
tr288:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st237;
tr294:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	goto st237;
tr298:
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	goto st237;
st237:
	if ( ++p == pe )
		goto _test_eof237;
case 237:
#line 1217 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr253;
		case 35u: goto tr254;
		case 37u: goto tr255;
		case 61u: goto tr253;
		case 95u: goto tr253;
		case 126u: goto tr253;
		default: break;
	}
	if ( (*p) < 63u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr253;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr253;
	} else
		goto tr253;
	goto st0;
tr253:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st238;
st238:
	if ( ++p == pe )
		goto _test_eof238;
case 238:
#line 1244 "uri.d"
	switch( (*p) ) {
		case 33u: goto st238;
		case 35u: goto tr256;
		case 37u: goto st7;
		case 61u: goto st238;
		case 95u: goto st238;
		case 126u: goto st238;
		default: break;
	}
	if ( (*p) < 63u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st238;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st238;
	} else
		goto st238;
	goto st0;
tr255:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st7;
st7:
	if ( ++p == pe )
		goto _test_eof7;
case 7:
#line 1271 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st8;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st8;
	} else
		goto st8;
	goto st0;
st8:
	if ( ++p == pe )
		goto _test_eof8;
case 8:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st238;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st238;
	} else
		goto st238;
	goto st0;
tr237:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
	goto st239;
st239:
	if ( ++p == pe )
		goto _test_eof239;
case 239:
#line 1306 "uri.d"
	switch( (*p) ) {
		case 33u: goto st232;
		case 35u: goto tr240;
		case 37u: goto st3;
		case 43u: goto st239;
		case 47u: goto tr242;
		case 58u: goto tr259;
		case 59u: goto st232;
		case 61u: goto st232;
		case 63u: goto tr243;
		case 64u: goto st232;
		case 95u: goto st232;
		case 126u: goto st232;
		default: break;
	}
	if ( (*p) < 45u ) {
		if ( 36u <= (*p) && (*p) <= 44u )
			goto st232;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st239;
		} else if ( (*p) >= 65u )
			goto st239;
	} else
		goto st239;
	goto st0;
tr259:
#line 692 "uri_parser.rl"
	{
        scheme = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st240;
st240:
	if ( ++p == pe )
		goto _test_eof240;
case 240:
#line 1345 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr260;
		case 35u: goto tr235;
		case 37u: goto tr261;
		case 47u: goto st241;
		case 61u: goto tr260;
		case 63u: goto tr239;
		case 95u: goto tr260;
		case 126u: goto tr260;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr260;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr260;
	} else
		goto tr260;
	goto st0;
st241:
	if ( ++p == pe )
		goto _test_eof241;
case 241:
	switch( (*p) ) {
		case 33u: goto tr262;
		case 35u: goto tr263;
		case 37u: goto tr264;
		case 47u: goto st242;
		case 61u: goto tr262;
		case 63u: goto tr266;
		case 95u: goto tr262;
		case 126u: goto tr262;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr262;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr262;
	} else
		goto tr262;
	goto st0;
st242:
	if ( ++p == pe )
		goto _test_eof242;
case 242:
	switch( (*p) ) {
		case 2u: goto tr267;
		case 33u: goto tr268;
		case 35u: goto tr269;
		case 37u: goto tr270;
		case 47u: goto tr271;
		case 48u: goto tr272;
		case 49u: goto tr273;
		case 50u: goto tr274;
		case 58u: goto tr276;
		case 59u: goto tr268;
		case 61u: goto tr268;
		case 63u: goto tr277;
		case 64u: goto tr278;
		case 91u: goto tr279;
		case 95u: goto tr268;
		case 126u: goto tr268;
		default: break;
	}
	if ( (*p) < 51u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto tr268;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr268;
		} else if ( (*p) >= 65u )
			goto tr268;
	} else
		goto tr275;
	goto st0;
tr267:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st9;
st9:
	if ( ++p == pe )
		goto _test_eof9;
case 9:
#line 1433 "uri.d"
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st10;
	goto st0;
st10:
	if ( ++p == pe )
		goto _test_eof10;
case 10:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st11;
	goto st0;
st11:
	if ( ++p == pe )
		goto _test_eof11;
case 11:
	if ( (*p) == 46u )
		goto st12;
	goto st0;
st12:
	if ( ++p == pe )
		goto _test_eof12;
case 12:
	switch( (*p) ) {
		case 2u: goto st13;
		case 48u: goto st15;
		case 49u: goto st29;
		case 50u: goto st31;
		default: break;
	}
	if ( 51u <= (*p) && (*p) <= 57u )
		goto st30;
	goto st0;
st13:
	if ( ++p == pe )
		goto _test_eof13;
case 13:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st14;
	goto st0;
st14:
	if ( ++p == pe )
		goto _test_eof14;
case 14:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st15;
	goto st0;
st15:
	if ( ++p == pe )
		goto _test_eof15;
case 15:
	if ( (*p) == 46u )
		goto st16;
	goto st0;
st16:
	if ( ++p == pe )
		goto _test_eof16;
case 16:
	switch( (*p) ) {
		case 2u: goto st17;
		case 48u: goto st19;
		case 49u: goto st25;
		case 50u: goto st27;
		default: break;
	}
	if ( 51u <= (*p) && (*p) <= 57u )
		goto st26;
	goto st0;
st17:
	if ( ++p == pe )
		goto _test_eof17;
case 17:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st18;
	goto st0;
st18:
	if ( ++p == pe )
		goto _test_eof18;
case 18:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st19;
	goto st0;
st19:
	if ( ++p == pe )
		goto _test_eof19;
case 19:
	if ( (*p) == 46u )
		goto st20;
	goto st0;
st20:
	if ( ++p == pe )
		goto _test_eof20;
case 20:
	switch( (*p) ) {
		case 2u: goto st21;
		case 48u: goto st243;
		case 49u: goto st248;
		case 50u: goto st250;
		default: break;
	}
	if ( 51u <= (*p) && (*p) <= 57u )
		goto st249;
	goto st0;
st21:
	if ( ++p == pe )
		goto _test_eof21;
case 21:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st22;
	goto st0;
st22:
	if ( ++p == pe )
		goto _test_eof22;
case 22:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st243;
	goto st0;
st243:
	if ( ++p == pe )
		goto _test_eof243;
case 243:
	switch( (*p) ) {
		case 35u: goto tr280;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 63u: goto tr283;
		default: break;
	}
	goto st0;
tr290:
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st244;
tr271:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st244;
tr281:
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st244;
tr287:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st244;
tr292:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	goto st244;
tr296:
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	goto st244;
st244:
	if ( ++p == pe )
		goto _test_eof244;
case 244:
#line 1623 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr284;
		case 35u: goto tr285;
		case 37u: goto tr286;
		case 47u: goto tr287;
		case 61u: goto tr284;
		case 63u: goto tr288;
		case 95u: goto tr284;
		case 126u: goto tr284;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr284;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr284;
	} else
		goto tr284;
	goto st0;
tr284:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st245;
st245:
	if ( ++p == pe )
		goto _test_eof245;
case 245:
#line 1656 "uri.d"
	switch( (*p) ) {
		case 33u: goto st245;
		case 35u: goto tr240;
		case 37u: goto st23;
		case 47u: goto tr290;
		case 61u: goto st245;
		case 63u: goto tr243;
		case 95u: goto st245;
		case 126u: goto st245;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st245;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st245;
	} else
		goto st245;
	goto st0;
tr286:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st23;
st23:
	if ( ++p == pe )
		goto _test_eof23;
case 23:
#line 1689 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st24;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st24;
	} else
		goto st24;
	goto st0;
st24:
	if ( ++p == pe )
		goto _test_eof24;
case 24:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st245;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st245;
	} else
		goto st245;
	goto st0;
tr309:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st246;
tr282:
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st246;
st246:
	if ( ++p == pe )
		goto _test_eof246;
case 246:
#line 1732 "uri.d"
	switch( (*p) ) {
		case 35u: goto tr291;
		case 47u: goto tr292;
		case 63u: goto tr294;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr293;
	goto st0;
tr293:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st247;
st247:
	if ( ++p == pe )
		goto _test_eof247;
case 247:
#line 1750 "uri.d"
	switch( (*p) ) {
		case 35u: goto tr295;
		case 47u: goto tr296;
		case 63u: goto tr298;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st247;
	goto st0;
st248:
	if ( ++p == pe )
		goto _test_eof248;
case 248:
	switch( (*p) ) {
		case 35u: goto tr280;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 63u: goto tr283;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st249;
	goto st0;
st249:
	if ( ++p == pe )
		goto _test_eof249;
case 249:
	switch( (*p) ) {
		case 35u: goto tr280;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 63u: goto tr283;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st243;
	goto st0;
st250:
	if ( ++p == pe )
		goto _test_eof250;
case 250:
	switch( (*p) ) {
		case 35u: goto tr280;
		case 47u: goto tr281;
		case 53u: goto st251;
		case 58u: goto tr282;
		case 63u: goto tr283;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st243;
	goto st0;
st251:
	if ( ++p == pe )
		goto _test_eof251;
case 251:
	switch( (*p) ) {
		case 35u: goto tr280;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 63u: goto tr283;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 53u )
		goto st243;
	goto st0;
st25:
	if ( ++p == pe )
		goto _test_eof25;
case 25:
	if ( (*p) == 46u )
		goto st20;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st26;
	goto st0;
st26:
	if ( ++p == pe )
		goto _test_eof26;
case 26:
	if ( (*p) == 46u )
		goto st20;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st19;
	goto st0;
st27:
	if ( ++p == pe )
		goto _test_eof27;
case 27:
	switch( (*p) ) {
		case 46u: goto st20;
		case 53u: goto st28;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st19;
	goto st0;
st28:
	if ( ++p == pe )
		goto _test_eof28;
case 28:
	if ( (*p) == 46u )
		goto st20;
	if ( 48u <= (*p) && (*p) <= 53u )
		goto st19;
	goto st0;
st29:
	if ( ++p == pe )
		goto _test_eof29;
case 29:
	if ( (*p) == 46u )
		goto st16;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st30;
	goto st0;
st30:
	if ( ++p == pe )
		goto _test_eof30;
case 30:
	if ( (*p) == 46u )
		goto st16;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st15;
	goto st0;
st31:
	if ( ++p == pe )
		goto _test_eof31;
case 31:
	switch( (*p) ) {
		case 46u: goto st16;
		case 53u: goto st32;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st15;
	goto st0;
st32:
	if ( ++p == pe )
		goto _test_eof32;
case 32:
	if ( (*p) == 46u )
		goto st16;
	if ( 48u <= (*p) && (*p) <= 53u )
		goto st15;
	goto st0;
tr268:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st252;
st252:
	if ( ++p == pe )
		goto _test_eof252;
case 252:
#line 1903 "uri.d"
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st252;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st252;
	} else
		goto st252;
	goto st0;
tr270:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st33;
st33:
	if ( ++p == pe )
		goto _test_eof33;
case 33:
#line 1934 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st34;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st34;
	} else
		goto st34;
	goto st0;
st34:
	if ( ++p == pe )
		goto _test_eof34;
case 34:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st252;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st252;
	} else
		goto st252;
	goto st0;
tr276:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st253;
tr301:
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st253;
st253:
	if ( ++p == pe )
		goto _test_eof253;
case 253:
#line 1977 "uri.d"
	switch( (*p) ) {
		case 33u: goto st35;
		case 35u: goto tr291;
		case 37u: goto st36;
		case 47u: goto tr292;
		case 61u: goto st35;
		case 63u: goto tr294;
		case 64u: goto tr40;
		case 95u: goto st35;
		case 126u: goto st35;
		default: break;
	}
	if ( (*p) < 58u ) {
		if ( (*p) > 46u ) {
			if ( 48u <= (*p) && (*p) <= 57u )
				goto tr302;
		} else if ( (*p) >= 36u )
			goto st35;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st35;
		} else if ( (*p) >= 65u )
			goto st35;
	} else
		goto st35;
	goto st0;
st35:
	if ( ++p == pe )
		goto _test_eof35;
case 35:
	switch( (*p) ) {
		case 33u: goto st35;
		case 37u: goto st36;
		case 61u: goto st35;
		case 64u: goto tr40;
		case 95u: goto st35;
		case 126u: goto st35;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto st35;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st35;
		} else if ( (*p) >= 65u )
			goto st35;
	} else
		goto st35;
	goto st0;
st36:
	if ( ++p == pe )
		goto _test_eof36;
case 36:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st37;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st37;
	} else
		goto st37;
	goto st0;
st37:
	if ( ++p == pe )
		goto _test_eof37;
case 37:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st35;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st35;
	} else
		goto st35;
	goto st0;
tr40:
#line 708 "uri_parser.rl"
	{
        authority.userinfo = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st254;
tr278:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 708 "uri_parser.rl"
	{
        authority.userinfo = unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st254;
st254:
	if ( ++p == pe )
		goto _test_eof254;
case 254:
#line 2076 "uri.d"
	switch( (*p) ) {
		case 2u: goto tr267;
		case 33u: goto tr303;
		case 35u: goto tr269;
		case 37u: goto tr304;
		case 47u: goto tr271;
		case 48u: goto tr305;
		case 49u: goto tr306;
		case 50u: goto tr307;
		case 58u: goto tr309;
		case 59u: goto tr303;
		case 61u: goto tr303;
		case 63u: goto tr277;
		case 91u: goto tr279;
		case 95u: goto tr303;
		case 126u: goto tr303;
		default: break;
	}
	if ( (*p) < 51u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto tr303;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr303;
		} else if ( (*p) >= 65u )
			goto tr303;
	} else
		goto tr308;
	goto st0;
tr303:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st255;
st255:
	if ( ++p == pe )
		goto _test_eof255;
case 255:
#line 2115 "uri.d"
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st255;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st255;
	} else
		goto st255;
	goto st0;
tr304:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st38;
st38:
	if ( ++p == pe )
		goto _test_eof38;
case 38:
#line 2145 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st39;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st39;
	} else
		goto st39;
	goto st0;
st39:
	if ( ++p == pe )
		goto _test_eof39;
case 39:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st255;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st255;
	} else
		goto st255;
	goto st0;
tr305:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st256;
st256:
	if ( ++p == pe )
		goto _test_eof256;
case 256:
#line 2176 "uri.d"
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st257;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st255;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st255;
	} else
		goto st255;
	goto st0;
st257:
	if ( ++p == pe )
		goto _test_eof257;
case 257:
	switch( (*p) ) {
		case 2u: goto st13;
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 47u: goto tr281;
		case 48u: goto st258;
		case 49u: goto st266;
		case 50u: goto st268;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 51u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st267;
	goto st0;
st258:
	if ( ++p == pe )
		goto _test_eof258;
case 258:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st259;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st255;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st255;
	} else
		goto st255;
	goto st0;
st259:
	if ( ++p == pe )
		goto _test_eof259;
case 259:
	switch( (*p) ) {
		case 2u: goto st17;
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 47u: goto tr281;
		case 48u: goto st260;
		case 49u: goto st262;
		case 50u: goto st264;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 51u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st263;
	goto st0;
st260:
	if ( ++p == pe )
		goto _test_eof260;
case 260:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st261;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st255;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st255;
	} else
		goto st255;
	goto st0;
st261:
	if ( ++p == pe )
		goto _test_eof261;
case 261:
	switch( (*p) ) {
		case 2u: goto st21;
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st255;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st255;
	} else
		goto st255;
	goto st0;
st262:
	if ( ++p == pe )
		goto _test_eof262;
case 262:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st261;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st263;
	goto st0;
st263:
	if ( ++p == pe )
		goto _test_eof263;
case 263:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st261;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st260;
	goto st0;
st264:
	if ( ++p == pe )
		goto _test_eof264;
case 264:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st261;
		case 47u: goto tr281;
		case 53u: goto st265;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st260;
	goto st0;
st265:
	if ( ++p == pe )
		goto _test_eof265;
case 265:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st261;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( (*p) > 45u ) {
			if ( 48u <= (*p) && (*p) <= 53u )
				goto st260;
		} else if ( (*p) >= 36u )
			goto st255;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st255;
	goto st0;
st266:
	if ( ++p == pe )
		goto _test_eof266;
case 266:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st259;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st267;
	goto st0;
st267:
	if ( ++p == pe )
		goto _test_eof267;
case 267:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st259;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st258;
	goto st0;
st268:
	if ( ++p == pe )
		goto _test_eof268;
case 268:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st259;
		case 47u: goto tr281;
		case 53u: goto st269;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st258;
	goto st0;
st269:
	if ( ++p == pe )
		goto _test_eof269;
case 269:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st259;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( (*p) > 45u ) {
			if ( 48u <= (*p) && (*p) <= 53u )
				goto st258;
		} else if ( (*p) >= 36u )
			goto st255;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st255;
	goto st0;
tr306:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st270;
st270:
	if ( ++p == pe )
		goto _test_eof270;
case 270:
#line 2597 "uri.d"
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st257;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st271;
	goto st0;
tr308:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st271;
st271:
	if ( ++p == pe )
		goto _test_eof271;
case 271:
#line 2632 "uri.d"
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st257;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st256;
	goto st0;
tr307:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st272;
st272:
	if ( ++p == pe )
		goto _test_eof272;
case 272:
#line 2667 "uri.d"
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st257;
		case 47u: goto tr281;
		case 53u: goto st273;
		case 58u: goto tr282;
		case 59u: goto st255;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st255;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st256;
	goto st0;
st273:
	if ( ++p == pe )
		goto _test_eof273;
case 273:
	switch( (*p) ) {
		case 33u: goto st255;
		case 35u: goto tr280;
		case 37u: goto st38;
		case 46u: goto st257;
		case 47u: goto tr281;
		case 58u: goto tr282;
		case 61u: goto st255;
		case 63u: goto tr283;
		case 95u: goto st255;
		case 126u: goto st255;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( (*p) > 45u ) {
			if ( 48u <= (*p) && (*p) <= 53u )
				goto st256;
		} else if ( (*p) >= 36u )
			goto st255;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st255;
		} else if ( (*p) >= 65u )
			goto st255;
	} else
		goto st255;
	goto st0;
tr279:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st40;
st40:
	if ( ++p == pe )
		goto _test_eof40;
case 40:
#line 2735 "uri.d"
	switch( (*p) ) {
		case 58u: goto st148;
		case 118u: goto st227;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st41;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st41;
	} else
		goto st41;
	goto st0;
st41:
	if ( ++p == pe )
		goto _test_eof41;
case 41:
	if ( (*p) == 58u )
		goto st45;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st42;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st42;
	} else
		goto st42;
	goto st0;
st42:
	if ( ++p == pe )
		goto _test_eof42;
case 42:
	if ( (*p) == 58u )
		goto st45;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st43;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st43;
	} else
		goto st43;
	goto st0;
st43:
	if ( ++p == pe )
		goto _test_eof43;
case 43:
	if ( (*p) == 58u )
		goto st45;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st44;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st44;
	} else
		goto st44;
	goto st0;
st44:
	if ( ++p == pe )
		goto _test_eof44;
case 44:
	if ( (*p) == 58u )
		goto st45;
	goto st0;
st45:
	if ( ++p == pe )
		goto _test_eof45;
case 45:
	if ( (*p) == 58u )
		goto st143;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st46;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st46;
	} else
		goto st46;
	goto st0;
st46:
	if ( ++p == pe )
		goto _test_eof46;
case 46:
	if ( (*p) == 58u )
		goto st50;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st47;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st47;
	} else
		goto st47;
	goto st0;
st47:
	if ( ++p == pe )
		goto _test_eof47;
case 47:
	if ( (*p) == 58u )
		goto st50;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st48;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st48;
	} else
		goto st48;
	goto st0;
st48:
	if ( ++p == pe )
		goto _test_eof48;
case 48:
	if ( (*p) == 58u )
		goto st50;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st49;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st49;
	} else
		goto st49;
	goto st0;
st49:
	if ( ++p == pe )
		goto _test_eof49;
case 49:
	if ( (*p) == 58u )
		goto st50;
	goto st0;
st50:
	if ( ++p == pe )
		goto _test_eof50;
case 50:
	if ( (*p) == 58u )
		goto st138;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st51;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st51;
	} else
		goto st51;
	goto st0;
st51:
	if ( ++p == pe )
		goto _test_eof51;
case 51:
	if ( (*p) == 58u )
		goto st55;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st52;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st52;
	} else
		goto st52;
	goto st0;
st52:
	if ( ++p == pe )
		goto _test_eof52;
case 52:
	if ( (*p) == 58u )
		goto st55;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st53;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st53;
	} else
		goto st53;
	goto st0;
st53:
	if ( ++p == pe )
		goto _test_eof53;
case 53:
	if ( (*p) == 58u )
		goto st55;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st54;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st54;
	} else
		goto st54;
	goto st0;
st54:
	if ( ++p == pe )
		goto _test_eof54;
case 54:
	if ( (*p) == 58u )
		goto st55;
	goto st0;
st55:
	if ( ++p == pe )
		goto _test_eof55;
case 55:
	if ( (*p) == 58u )
		goto st133;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st56;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st56;
	} else
		goto st56;
	goto st0;
st56:
	if ( ++p == pe )
		goto _test_eof56;
case 56:
	if ( (*p) == 58u )
		goto st60;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st57;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st57;
	} else
		goto st57;
	goto st0;
st57:
	if ( ++p == pe )
		goto _test_eof57;
case 57:
	if ( (*p) == 58u )
		goto st60;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st58;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st58;
	} else
		goto st58;
	goto st0;
st58:
	if ( ++p == pe )
		goto _test_eof58;
case 58:
	if ( (*p) == 58u )
		goto st60;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st59;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st59;
	} else
		goto st59;
	goto st0;
st59:
	if ( ++p == pe )
		goto _test_eof59;
case 59:
	if ( (*p) == 58u )
		goto st60;
	goto st0;
st60:
	if ( ++p == pe )
		goto _test_eof60;
case 60:
	if ( (*p) == 58u )
		goto st128;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st61;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st61;
	} else
		goto st61;
	goto st0;
st61:
	if ( ++p == pe )
		goto _test_eof61;
case 61:
	if ( (*p) == 58u )
		goto st65;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st62;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st62;
	} else
		goto st62;
	goto st0;
st62:
	if ( ++p == pe )
		goto _test_eof62;
case 62:
	if ( (*p) == 58u )
		goto st65;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st63;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st63;
	} else
		goto st63;
	goto st0;
st63:
	if ( ++p == pe )
		goto _test_eof63;
case 63:
	if ( (*p) == 58u )
		goto st65;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st64;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st64;
	} else
		goto st64;
	goto st0;
st64:
	if ( ++p == pe )
		goto _test_eof64;
case 64:
	if ( (*p) == 58u )
		goto st65;
	goto st0;
st65:
	if ( ++p == pe )
		goto _test_eof65;
case 65:
	if ( (*p) == 58u )
		goto st115;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st66;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st66;
	} else
		goto st66;
	goto st0;
st66:
	if ( ++p == pe )
		goto _test_eof66;
case 66:
	if ( (*p) == 58u )
		goto st70;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st67;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st67;
	} else
		goto st67;
	goto st0;
st67:
	if ( ++p == pe )
		goto _test_eof67;
case 67:
	if ( (*p) == 58u )
		goto st70;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st68;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st68;
	} else
		goto st68;
	goto st0;
st68:
	if ( ++p == pe )
		goto _test_eof68;
case 68:
	if ( (*p) == 58u )
		goto st70;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st69;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st69;
	} else
		goto st69;
	goto st0;
st69:
	if ( ++p == pe )
		goto _test_eof69;
case 69:
	if ( (*p) == 58u )
		goto st70;
	goto st0;
st70:
	if ( ++p == pe )
		goto _test_eof70;
case 70:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st98;
		case 49u: goto st106;
		case 50u: goto st109;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st112;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st114;
	} else
		goto st114;
	goto st0;
st71:
	if ( ++p == pe )
		goto _test_eof71;
case 71:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st72;
	goto st0;
st72:
	if ( ++p == pe )
		goto _test_eof72;
case 72:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st73;
	goto st0;
st73:
	if ( ++p == pe )
		goto _test_eof73;
case 73:
	if ( (*p) == 46u )
		goto st74;
	goto st0;
st74:
	if ( ++p == pe )
		goto _test_eof74;
case 74:
	switch( (*p) ) {
		case 2u: goto st75;
		case 48u: goto st77;
		case 49u: goto st94;
		case 50u: goto st96;
		default: break;
	}
	if ( 51u <= (*p) && (*p) <= 57u )
		goto st95;
	goto st0;
st75:
	if ( ++p == pe )
		goto _test_eof75;
case 75:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st76;
	goto st0;
st76:
	if ( ++p == pe )
		goto _test_eof76;
case 76:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st77;
	goto st0;
st77:
	if ( ++p == pe )
		goto _test_eof77;
case 77:
	if ( (*p) == 46u )
		goto st78;
	goto st0;
st78:
	if ( ++p == pe )
		goto _test_eof78;
case 78:
	switch( (*p) ) {
		case 2u: goto st79;
		case 48u: goto st81;
		case 49u: goto st90;
		case 50u: goto st92;
		default: break;
	}
	if ( 51u <= (*p) && (*p) <= 57u )
		goto st91;
	goto st0;
st79:
	if ( ++p == pe )
		goto _test_eof79;
case 79:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st80;
	goto st0;
st80:
	if ( ++p == pe )
		goto _test_eof80;
case 80:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st81;
	goto st0;
st81:
	if ( ++p == pe )
		goto _test_eof81;
case 81:
	if ( (*p) == 46u )
		goto st82;
	goto st0;
st82:
	if ( ++p == pe )
		goto _test_eof82;
case 82:
	switch( (*p) ) {
		case 2u: goto st83;
		case 48u: goto st85;
		case 49u: goto st86;
		case 50u: goto st88;
		default: break;
	}
	if ( 51u <= (*p) && (*p) <= 57u )
		goto st87;
	goto st0;
st83:
	if ( ++p == pe )
		goto _test_eof83;
case 83:
	if ( 48u <= (*p) && (*p) <= 52u )
		goto st84;
	goto st0;
st84:
	if ( ++p == pe )
		goto _test_eof84;
case 84:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st85;
	goto st0;
st85:
	if ( ++p == pe )
		goto _test_eof85;
case 85:
	if ( (*p) == 93u )
		goto st243;
	goto st0;
st86:
	if ( ++p == pe )
		goto _test_eof86;
case 86:
	if ( (*p) == 93u )
		goto st243;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st87;
	goto st0;
st87:
	if ( ++p == pe )
		goto _test_eof87;
case 87:
	if ( (*p) == 93u )
		goto st243;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st85;
	goto st0;
st88:
	if ( ++p == pe )
		goto _test_eof88;
case 88:
	switch( (*p) ) {
		case 53u: goto st89;
		case 93u: goto st243;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st85;
	goto st0;
st89:
	if ( ++p == pe )
		goto _test_eof89;
case 89:
	if ( (*p) == 93u )
		goto st243;
	if ( 48u <= (*p) && (*p) <= 53u )
		goto st85;
	goto st0;
st90:
	if ( ++p == pe )
		goto _test_eof90;
case 90:
	if ( (*p) == 46u )
		goto st82;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st91;
	goto st0;
st91:
	if ( ++p == pe )
		goto _test_eof91;
case 91:
	if ( (*p) == 46u )
		goto st82;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st81;
	goto st0;
st92:
	if ( ++p == pe )
		goto _test_eof92;
case 92:
	switch( (*p) ) {
		case 46u: goto st82;
		case 53u: goto st93;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st81;
	goto st0;
st93:
	if ( ++p == pe )
		goto _test_eof93;
case 93:
	if ( (*p) == 46u )
		goto st82;
	if ( 48u <= (*p) && (*p) <= 53u )
		goto st81;
	goto st0;
st94:
	if ( ++p == pe )
		goto _test_eof94;
case 94:
	if ( (*p) == 46u )
		goto st78;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st95;
	goto st0;
st95:
	if ( ++p == pe )
		goto _test_eof95;
case 95:
	if ( (*p) == 46u )
		goto st78;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st77;
	goto st0;
st96:
	if ( ++p == pe )
		goto _test_eof96;
case 96:
	switch( (*p) ) {
		case 46u: goto st78;
		case 53u: goto st97;
		default: break;
	}
	if ( 48u <= (*p) && (*p) <= 57u )
		goto st77;
	goto st0;
st97:
	if ( ++p == pe )
		goto _test_eof97;
case 97:
	if ( (*p) == 46u )
		goto st78;
	if ( 48u <= (*p) && (*p) <= 53u )
		goto st77;
	goto st0;
st98:
	if ( ++p == pe )
		goto _test_eof98;
case 98:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st99;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st99;
	} else
		goto st99;
	goto st0;
st99:
	if ( ++p == pe )
		goto _test_eof99;
case 99:
	if ( (*p) == 58u )
		goto st102;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st100;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st100;
	} else
		goto st100;
	goto st0;
st100:
	if ( ++p == pe )
		goto _test_eof100;
case 100:
	if ( (*p) == 58u )
		goto st102;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st101;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st101;
	} else
		goto st101;
	goto st0;
st101:
	if ( ++p == pe )
		goto _test_eof101;
case 101:
	if ( (*p) == 58u )
		goto st102;
	goto st0;
st102:
	if ( ++p == pe )
		goto _test_eof102;
case 102:
	if ( (*p) == 58u )
		goto st85;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st103;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st103;
	} else
		goto st103;
	goto st0;
st103:
	if ( ++p == pe )
		goto _test_eof103;
case 103:
	if ( (*p) == 93u )
		goto st243;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st104;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st104;
	} else
		goto st104;
	goto st0;
st104:
	if ( ++p == pe )
		goto _test_eof104;
case 104:
	if ( (*p) == 93u )
		goto st243;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st105;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st105;
	} else
		goto st105;
	goto st0;
st105:
	if ( ++p == pe )
		goto _test_eof105;
case 105:
	if ( (*p) == 93u )
		goto st243;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st85;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st85;
	} else
		goto st85;
	goto st0;
st106:
	if ( ++p == pe )
		goto _test_eof106;
case 106:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st107;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st99;
	} else
		goto st99;
	goto st0;
st107:
	if ( ++p == pe )
		goto _test_eof107;
case 107:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st108;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st100;
	} else
		goto st100;
	goto st0;
st108:
	if ( ++p == pe )
		goto _test_eof108;
case 108:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st101;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st101;
	} else
		goto st101;
	goto st0;
st109:
	if ( ++p == pe )
		goto _test_eof109;
case 109:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st111;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st110;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st99;
	} else
		goto st99;
	goto st0;
st110:
	if ( ++p == pe )
		goto _test_eof110;
case 110:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st100;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st100;
	} else
		goto st100;
	goto st0;
st111:
	if ( ++p == pe )
		goto _test_eof111;
case 111:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st108;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st100;
		} else if ( (*p) >= 65u )
			goto st100;
	} else
		goto st100;
	goto st0;
st112:
	if ( ++p == pe )
		goto _test_eof112;
case 112:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st102;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st110;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st99;
	} else
		goto st99;
	goto st0;
st113:
	if ( ++p == pe )
		goto _test_eof113;
case 113:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st103;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st103;
	} else
		goto st103;
	goto st0;
st114:
	if ( ++p == pe )
		goto _test_eof114;
case 114:
	if ( (*p) == 58u )
		goto st102;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st99;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st99;
	} else
		goto st99;
	goto st0;
st115:
	if ( ++p == pe )
		goto _test_eof115;
case 115:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st116;
		case 49u: goto st120;
		case 50u: goto st123;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st126;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st127;
	} else
		goto st127;
	goto st0;
st116:
	if ( ++p == pe )
		goto _test_eof116;
case 116:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st117;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st117;
	} else
		goto st117;
	goto st0;
st117:
	if ( ++p == pe )
		goto _test_eof117;
case 117:
	if ( (*p) == 58u )
		goto st113;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st118;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st118;
	} else
		goto st118;
	goto st0;
st118:
	if ( ++p == pe )
		goto _test_eof118;
case 118:
	if ( (*p) == 58u )
		goto st113;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st119;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st119;
	} else
		goto st119;
	goto st0;
st119:
	if ( ++p == pe )
		goto _test_eof119;
case 119:
	if ( (*p) == 58u )
		goto st113;
	goto st0;
st120:
	if ( ++p == pe )
		goto _test_eof120;
case 120:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st121;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st117;
	} else
		goto st117;
	goto st0;
st121:
	if ( ++p == pe )
		goto _test_eof121;
case 121:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st122;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st118;
	} else
		goto st118;
	goto st0;
st122:
	if ( ++p == pe )
		goto _test_eof122;
case 122:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st119;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st119;
	} else
		goto st119;
	goto st0;
st123:
	if ( ++p == pe )
		goto _test_eof123;
case 123:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st125;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st124;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st117;
	} else
		goto st117;
	goto st0;
st124:
	if ( ++p == pe )
		goto _test_eof124;
case 124:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st118;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st118;
	} else
		goto st118;
	goto st0;
st125:
	if ( ++p == pe )
		goto _test_eof125;
case 125:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st122;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st118;
		} else if ( (*p) >= 65u )
			goto st118;
	} else
		goto st118;
	goto st0;
st126:
	if ( ++p == pe )
		goto _test_eof126;
case 126:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st124;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st117;
	} else
		goto st117;
	goto st0;
st127:
	if ( ++p == pe )
		goto _test_eof127;
case 127:
	if ( (*p) == 58u )
		goto st113;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st117;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st117;
	} else
		goto st117;
	goto st0;
st128:
	if ( ++p == pe )
		goto _test_eof128;
case 128:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st129;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st129;
	} else
		goto st129;
	goto st0;
st129:
	if ( ++p == pe )
		goto _test_eof129;
case 129:
	if ( (*p) == 58u )
		goto st115;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st130;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st130;
	} else
		goto st130;
	goto st0;
st130:
	if ( ++p == pe )
		goto _test_eof130;
case 130:
	if ( (*p) == 58u )
		goto st115;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st131;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st131;
	} else
		goto st131;
	goto st0;
st131:
	if ( ++p == pe )
		goto _test_eof131;
case 131:
	if ( (*p) == 58u )
		goto st115;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st132;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st132;
	} else
		goto st132;
	goto st0;
st132:
	if ( ++p == pe )
		goto _test_eof132;
case 132:
	if ( (*p) == 58u )
		goto st115;
	goto st0;
st133:
	if ( ++p == pe )
		goto _test_eof133;
case 133:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st134;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st134;
	} else
		goto st134;
	goto st0;
st134:
	if ( ++p == pe )
		goto _test_eof134;
case 134:
	if ( (*p) == 58u )
		goto st128;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st135;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st135;
	} else
		goto st135;
	goto st0;
st135:
	if ( ++p == pe )
		goto _test_eof135;
case 135:
	if ( (*p) == 58u )
		goto st128;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st136;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st136;
	} else
		goto st136;
	goto st0;
st136:
	if ( ++p == pe )
		goto _test_eof136;
case 136:
	if ( (*p) == 58u )
		goto st128;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st137;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st137;
	} else
		goto st137;
	goto st0;
st137:
	if ( ++p == pe )
		goto _test_eof137;
case 137:
	if ( (*p) == 58u )
		goto st128;
	goto st0;
st138:
	if ( ++p == pe )
		goto _test_eof138;
case 138:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st139;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st139;
	} else
		goto st139;
	goto st0;
st139:
	if ( ++p == pe )
		goto _test_eof139;
case 139:
	if ( (*p) == 58u )
		goto st133;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st140;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st140;
	} else
		goto st140;
	goto st0;
st140:
	if ( ++p == pe )
		goto _test_eof140;
case 140:
	if ( (*p) == 58u )
		goto st133;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st141;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st141;
	} else
		goto st141;
	goto st0;
st141:
	if ( ++p == pe )
		goto _test_eof141;
case 141:
	if ( (*p) == 58u )
		goto st133;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st142;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st142;
	} else
		goto st142;
	goto st0;
st142:
	if ( ++p == pe )
		goto _test_eof142;
case 142:
	if ( (*p) == 58u )
		goto st133;
	goto st0;
st143:
	if ( ++p == pe )
		goto _test_eof143;
case 143:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st144;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st144;
	} else
		goto st144;
	goto st0;
st144:
	if ( ++p == pe )
		goto _test_eof144;
case 144:
	if ( (*p) == 58u )
		goto st138;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st145;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st145;
	} else
		goto st145;
	goto st0;
st145:
	if ( ++p == pe )
		goto _test_eof145;
case 145:
	if ( (*p) == 58u )
		goto st138;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st146;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st146;
	} else
		goto st146;
	goto st0;
st146:
	if ( ++p == pe )
		goto _test_eof146;
case 146:
	if ( (*p) == 58u )
		goto st138;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st147;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st147;
	} else
		goto st147;
	goto st0;
st147:
	if ( ++p == pe )
		goto _test_eof147;
case 147:
	if ( (*p) == 58u )
		goto st138;
	goto st0;
st148:
	if ( ++p == pe )
		goto _test_eof148;
case 148:
	if ( (*p) == 58u )
		goto st149;
	goto st0;
st149:
	if ( ++p == pe )
		goto _test_eof149;
case 149:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st150;
		case 49u: goto st219;
		case 50u: goto st222;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st225;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st226;
	} else
		goto st226;
	goto st0;
st150:
	if ( ++p == pe )
		goto _test_eof150;
case 150:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st151;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st151;
	} else
		goto st151;
	goto st0;
st151:
	if ( ++p == pe )
		goto _test_eof151;
case 151:
	switch( (*p) ) {
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st152;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st152;
	} else
		goto st152;
	goto st0;
st152:
	if ( ++p == pe )
		goto _test_eof152;
case 152:
	switch( (*p) ) {
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st153;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st153;
	} else
		goto st153;
	goto st0;
st153:
	if ( ++p == pe )
		goto _test_eof153;
case 153:
	switch( (*p) ) {
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	goto st0;
st154:
	if ( ++p == pe )
		goto _test_eof154;
case 154:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st155;
		case 49u: goto st211;
		case 50u: goto st214;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st217;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st218;
	} else
		goto st218;
	goto st0;
st155:
	if ( ++p == pe )
		goto _test_eof155;
case 155:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st156;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st156;
	} else
		goto st156;
	goto st0;
st156:
	if ( ++p == pe )
		goto _test_eof156;
case 156:
	switch( (*p) ) {
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st157;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st157;
	} else
		goto st157;
	goto st0;
st157:
	if ( ++p == pe )
		goto _test_eof157;
case 157:
	switch( (*p) ) {
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st158;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st158;
	} else
		goto st158;
	goto st0;
st158:
	if ( ++p == pe )
		goto _test_eof158;
case 158:
	switch( (*p) ) {
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	goto st0;
st159:
	if ( ++p == pe )
		goto _test_eof159;
case 159:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st160;
		case 49u: goto st203;
		case 50u: goto st206;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st209;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st210;
	} else
		goto st210;
	goto st0;
st160:
	if ( ++p == pe )
		goto _test_eof160;
case 160:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st161;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st161;
	} else
		goto st161;
	goto st0;
st161:
	if ( ++p == pe )
		goto _test_eof161;
case 161:
	switch( (*p) ) {
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st162;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st162;
	} else
		goto st162;
	goto st0;
st162:
	if ( ++p == pe )
		goto _test_eof162;
case 162:
	switch( (*p) ) {
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st163;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st163;
	} else
		goto st163;
	goto st0;
st163:
	if ( ++p == pe )
		goto _test_eof163;
case 163:
	switch( (*p) ) {
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	goto st0;
st164:
	if ( ++p == pe )
		goto _test_eof164;
case 164:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st165;
		case 49u: goto st195;
		case 50u: goto st198;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st201;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st202;
	} else
		goto st202;
	goto st0;
st165:
	if ( ++p == pe )
		goto _test_eof165;
case 165:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st166;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st166;
	} else
		goto st166;
	goto st0;
st166:
	if ( ++p == pe )
		goto _test_eof166;
case 166:
	switch( (*p) ) {
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st167;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st167;
	} else
		goto st167;
	goto st0;
st167:
	if ( ++p == pe )
		goto _test_eof167;
case 167:
	switch( (*p) ) {
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st168;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st168;
	} else
		goto st168;
	goto st0;
st168:
	if ( ++p == pe )
		goto _test_eof168;
case 168:
	switch( (*p) ) {
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	goto st0;
st169:
	if ( ++p == pe )
		goto _test_eof169;
case 169:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st170;
		case 49u: goto st187;
		case 50u: goto st190;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st193;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st194;
	} else
		goto st194;
	goto st0;
st170:
	if ( ++p == pe )
		goto _test_eof170;
case 170:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st171;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st171;
	} else
		goto st171;
	goto st0;
st171:
	if ( ++p == pe )
		goto _test_eof171;
case 171:
	switch( (*p) ) {
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st172;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st172;
	} else
		goto st172;
	goto st0;
st172:
	if ( ++p == pe )
		goto _test_eof172;
case 172:
	switch( (*p) ) {
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st173;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st173;
	} else
		goto st173;
	goto st0;
st173:
	if ( ++p == pe )
		goto _test_eof173;
case 173:
	switch( (*p) ) {
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	goto st0;
st174:
	if ( ++p == pe )
		goto _test_eof174;
case 174:
	switch( (*p) ) {
		case 2u: goto st71;
		case 48u: goto st175;
		case 49u: goto st179;
		case 50u: goto st182;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 51u <= (*p) && (*p) <= 57u )
			goto st185;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st186;
	} else
		goto st186;
	goto st0;
st175:
	if ( ++p == pe )
		goto _test_eof175;
case 175:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st176;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st176;
	} else
		goto st176;
	goto st0;
st176:
	if ( ++p == pe )
		goto _test_eof176;
case 176:
	switch( (*p) ) {
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st177;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st177;
	} else
		goto st177;
	goto st0;
st177:
	if ( ++p == pe )
		goto _test_eof177;
case 177:
	switch( (*p) ) {
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st178;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st178;
	} else
		goto st178;
	goto st0;
st178:
	if ( ++p == pe )
		goto _test_eof178;
case 178:
	switch( (*p) ) {
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	goto st0;
st179:
	if ( ++p == pe )
		goto _test_eof179;
case 179:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st180;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st176;
	} else
		goto st176;
	goto st0;
st180:
	if ( ++p == pe )
		goto _test_eof180;
case 180:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st181;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st177;
	} else
		goto st177;
	goto st0;
st181:
	if ( ++p == pe )
		goto _test_eof181;
case 181:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st178;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st178;
	} else
		goto st178;
	goto st0;
st182:
	if ( ++p == pe )
		goto _test_eof182;
case 182:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st184;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st183;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st176;
	} else
		goto st176;
	goto st0;
st183:
	if ( ++p == pe )
		goto _test_eof183;
case 183:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st177;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st177;
	} else
		goto st177;
	goto st0;
st184:
	if ( ++p == pe )
		goto _test_eof184;
case 184:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st181;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st177;
		} else if ( (*p) >= 65u )
			goto st177;
	} else
		goto st177;
	goto st0;
st185:
	if ( ++p == pe )
		goto _test_eof185;
case 185:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st183;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st176;
	} else
		goto st176;
	goto st0;
st186:
	if ( ++p == pe )
		goto _test_eof186;
case 186:
	switch( (*p) ) {
		case 58u: goto st113;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st176;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st176;
	} else
		goto st176;
	goto st0;
st187:
	if ( ++p == pe )
		goto _test_eof187;
case 187:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st188;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st171;
	} else
		goto st171;
	goto st0;
st188:
	if ( ++p == pe )
		goto _test_eof188;
case 188:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st189;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st172;
	} else
		goto st172;
	goto st0;
st189:
	if ( ++p == pe )
		goto _test_eof189;
case 189:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st173;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st173;
	} else
		goto st173;
	goto st0;
st190:
	if ( ++p == pe )
		goto _test_eof190;
case 190:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st192;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st191;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st171;
	} else
		goto st171;
	goto st0;
st191:
	if ( ++p == pe )
		goto _test_eof191;
case 191:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st172;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st172;
	} else
		goto st172;
	goto st0;
st192:
	if ( ++p == pe )
		goto _test_eof192;
case 192:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st189;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st172;
		} else if ( (*p) >= 65u )
			goto st172;
	} else
		goto st172;
	goto st0;
st193:
	if ( ++p == pe )
		goto _test_eof193;
case 193:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st191;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st171;
	} else
		goto st171;
	goto st0;
st194:
	if ( ++p == pe )
		goto _test_eof194;
case 194:
	switch( (*p) ) {
		case 58u: goto st174;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st171;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st171;
	} else
		goto st171;
	goto st0;
st195:
	if ( ++p == pe )
		goto _test_eof195;
case 195:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st196;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st166;
	} else
		goto st166;
	goto st0;
st196:
	if ( ++p == pe )
		goto _test_eof196;
case 196:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st197;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st167;
	} else
		goto st167;
	goto st0;
st197:
	if ( ++p == pe )
		goto _test_eof197;
case 197:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st168;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st168;
	} else
		goto st168;
	goto st0;
st198:
	if ( ++p == pe )
		goto _test_eof198;
case 198:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st200;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st199;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st166;
	} else
		goto st166;
	goto st0;
st199:
	if ( ++p == pe )
		goto _test_eof199;
case 199:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st167;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st167;
	} else
		goto st167;
	goto st0;
st200:
	if ( ++p == pe )
		goto _test_eof200;
case 200:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st197;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st167;
		} else if ( (*p) >= 65u )
			goto st167;
	} else
		goto st167;
	goto st0;
st201:
	if ( ++p == pe )
		goto _test_eof201;
case 201:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st199;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st166;
	} else
		goto st166;
	goto st0;
st202:
	if ( ++p == pe )
		goto _test_eof202;
case 202:
	switch( (*p) ) {
		case 58u: goto st169;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st166;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st166;
	} else
		goto st166;
	goto st0;
st203:
	if ( ++p == pe )
		goto _test_eof203;
case 203:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st204;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st161;
	} else
		goto st161;
	goto st0;
st204:
	if ( ++p == pe )
		goto _test_eof204;
case 204:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st205;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st162;
	} else
		goto st162;
	goto st0;
st205:
	if ( ++p == pe )
		goto _test_eof205;
case 205:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st163;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st163;
	} else
		goto st163;
	goto st0;
st206:
	if ( ++p == pe )
		goto _test_eof206;
case 206:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st208;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st207;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st161;
	} else
		goto st161;
	goto st0;
st207:
	if ( ++p == pe )
		goto _test_eof207;
case 207:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st162;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st162;
	} else
		goto st162;
	goto st0;
st208:
	if ( ++p == pe )
		goto _test_eof208;
case 208:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st205;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st162;
		} else if ( (*p) >= 65u )
			goto st162;
	} else
		goto st162;
	goto st0;
st209:
	if ( ++p == pe )
		goto _test_eof209;
case 209:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st207;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st161;
	} else
		goto st161;
	goto st0;
st210:
	if ( ++p == pe )
		goto _test_eof210;
case 210:
	switch( (*p) ) {
		case 58u: goto st164;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st161;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st161;
	} else
		goto st161;
	goto st0;
st211:
	if ( ++p == pe )
		goto _test_eof211;
case 211:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st212;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st156;
	} else
		goto st156;
	goto st0;
st212:
	if ( ++p == pe )
		goto _test_eof212;
case 212:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st213;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st157;
	} else
		goto st157;
	goto st0;
st213:
	if ( ++p == pe )
		goto _test_eof213;
case 213:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st158;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st158;
	} else
		goto st158;
	goto st0;
st214:
	if ( ++p == pe )
		goto _test_eof214;
case 214:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st216;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st215;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st156;
	} else
		goto st156;
	goto st0;
st215:
	if ( ++p == pe )
		goto _test_eof215;
case 215:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st157;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st157;
	} else
		goto st157;
	goto st0;
st216:
	if ( ++p == pe )
		goto _test_eof216;
case 216:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st213;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st157;
		} else if ( (*p) >= 65u )
			goto st157;
	} else
		goto st157;
	goto st0;
st217:
	if ( ++p == pe )
		goto _test_eof217;
case 217:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st215;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st156;
	} else
		goto st156;
	goto st0;
st218:
	if ( ++p == pe )
		goto _test_eof218;
case 218:
	switch( (*p) ) {
		case 58u: goto st159;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st156;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st156;
	} else
		goto st156;
	goto st0;
st219:
	if ( ++p == pe )
		goto _test_eof219;
case 219:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st220;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st151;
	} else
		goto st151;
	goto st0;
st220:
	if ( ++p == pe )
		goto _test_eof220;
case 220:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st221;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st152;
	} else
		goto st152;
	goto st0;
st221:
	if ( ++p == pe )
		goto _test_eof221;
case 221:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st153;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st153;
	} else
		goto st153;
	goto st0;
st222:
	if ( ++p == pe )
		goto _test_eof222;
case 222:
	switch( (*p) ) {
		case 46u: goto st74;
		case 53u: goto st224;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st223;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st151;
	} else
		goto st151;
	goto st0;
st223:
	if ( ++p == pe )
		goto _test_eof223;
case 223:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st152;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st152;
	} else
		goto st152;
	goto st0;
st224:
	if ( ++p == pe )
		goto _test_eof224;
case 224:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( 48u <= (*p) && (*p) <= 53u )
			goto st221;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 70u ) {
			if ( 97u <= (*p) && (*p) <= 102u )
				goto st152;
		} else if ( (*p) >= 65u )
			goto st152;
	} else
		goto st152;
	goto st0;
st225:
	if ( ++p == pe )
		goto _test_eof225;
case 225:
	switch( (*p) ) {
		case 46u: goto st74;
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st223;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st151;
	} else
		goto st151;
	goto st0;
st226:
	if ( ++p == pe )
		goto _test_eof226;
case 226:
	switch( (*p) ) {
		case 58u: goto st154;
		case 93u: goto st243;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st151;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st151;
	} else
		goto st151;
	goto st0;
st227:
	if ( ++p == pe )
		goto _test_eof227;
case 227:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st228;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st228;
	} else
		goto st228;
	goto st0;
st228:
	if ( ++p == pe )
		goto _test_eof228;
case 228:
	if ( (*p) == 46u )
		goto st229;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st228;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st228;
	} else
		goto st228;
	goto st0;
st229:
	if ( ++p == pe )
		goto _test_eof229;
case 229:
	switch( (*p) ) {
		case 33u: goto st230;
		case 36u: goto st230;
		case 61u: goto st230;
		case 95u: goto st230;
		case 126u: goto st230;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 38u <= (*p) && (*p) <= 46u )
			goto st230;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st230;
		} else if ( (*p) >= 65u )
			goto st230;
	} else
		goto st230;
	goto st0;
st230:
	if ( ++p == pe )
		goto _test_eof230;
case 230:
	switch( (*p) ) {
		case 33u: goto st230;
		case 36u: goto st230;
		case 61u: goto st230;
		case 93u: goto st243;
		case 95u: goto st230;
		case 126u: goto st230;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 38u <= (*p) && (*p) <= 46u )
			goto st230;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st230;
		} else if ( (*p) >= 65u )
			goto st230;
	} else
		goto st230;
	goto st0;
tr302:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st274;
st274:
	if ( ++p == pe )
		goto _test_eof274;
case 274:
#line 5687 "uri.d"
	switch( (*p) ) {
		case 33u: goto st35;
		case 35u: goto tr295;
		case 37u: goto st36;
		case 47u: goto tr296;
		case 61u: goto st35;
		case 63u: goto tr298;
		case 64u: goto tr40;
		case 95u: goto st35;
		case 126u: goto st35;
		default: break;
	}
	if ( (*p) < 58u ) {
		if ( (*p) > 46u ) {
			if ( 48u <= (*p) && (*p) <= 57u )
				goto st274;
		} else if ( (*p) >= 36u )
			goto st35;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st35;
		} else if ( (*p) >= 65u )
			goto st35;
	} else
		goto st35;
	goto st0;
tr272:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st275;
st275:
	if ( ++p == pe )
		goto _test_eof275;
case 275:
#line 5723 "uri.d"
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st276;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st252;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st252;
	} else
		goto st252;
	goto st0;
st276:
	if ( ++p == pe )
		goto _test_eof276;
case 276:
	switch( (*p) ) {
		case 2u: goto st13;
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 47u: goto tr281;
		case 48u: goto st277;
		case 49u: goto st285;
		case 50u: goto st287;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 51u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st286;
	goto st0;
st277:
	if ( ++p == pe )
		goto _test_eof277;
case 277:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st278;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st252;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st252;
	} else
		goto st252;
	goto st0;
st278:
	if ( ++p == pe )
		goto _test_eof278;
case 278:
	switch( (*p) ) {
		case 2u: goto st17;
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 47u: goto tr281;
		case 48u: goto st279;
		case 49u: goto st281;
		case 50u: goto st283;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 51u ) {
		if ( 36u <= (*p) && (*p) <= 46u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st282;
	goto st0;
st279:
	if ( ++p == pe )
		goto _test_eof279;
case 279:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st280;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st252;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st252;
	} else
		goto st252;
	goto st0;
st280:
	if ( ++p == pe )
		goto _test_eof280;
case 280:
	switch( (*p) ) {
		case 2u: goto st21;
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 65u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st252;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st252;
	} else
		goto st252;
	goto st0;
st281:
	if ( ++p == pe )
		goto _test_eof281;
case 281:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st280;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st282;
	goto st0;
st282:
	if ( ++p == pe )
		goto _test_eof282;
case 282:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st280;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st279;
	goto st0;
st283:
	if ( ++p == pe )
		goto _test_eof283;
case 283:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st280;
		case 47u: goto tr281;
		case 53u: goto st284;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st279;
	goto st0;
st284:
	if ( ++p == pe )
		goto _test_eof284;
case 284:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st280;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( (*p) > 45u ) {
			if ( 48u <= (*p) && (*p) <= 53u )
				goto st279;
		} else if ( (*p) >= 36u )
			goto st252;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st252;
	goto st0;
st285:
	if ( ++p == pe )
		goto _test_eof285;
case 285:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st278;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st286;
	goto st0;
st286:
	if ( ++p == pe )
		goto _test_eof286;
case 286:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st278;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st277;
	goto st0;
st287:
	if ( ++p == pe )
		goto _test_eof287;
case 287:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st278;
		case 47u: goto tr281;
		case 53u: goto st288;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st277;
	goto st0;
st288:
	if ( ++p == pe )
		goto _test_eof288;
case 288:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st278;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( (*p) > 45u ) {
			if ( 48u <= (*p) && (*p) <= 53u )
				goto st277;
		} else if ( (*p) >= 36u )
			goto st252;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st252;
	goto st0;
tr273:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st289;
st289:
	if ( ++p == pe )
		goto _test_eof289;
case 289:
#line 6158 "uri.d"
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st276;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st290;
	goto st0;
tr275:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st290;
st290:
	if ( ++p == pe )
		goto _test_eof290;
case 290:
#line 6194 "uri.d"
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st276;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st275;
	goto st0;
tr274:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st291;
st291:
	if ( ++p == pe )
		goto _test_eof291;
case 291:
#line 6230 "uri.d"
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st276;
		case 47u: goto tr281;
		case 53u: goto st292;
		case 58u: goto tr301;
		case 59u: goto st252;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 36u <= (*p) && (*p) <= 45u )
			goto st252;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st275;
	goto st0;
st292:
	if ( ++p == pe )
		goto _test_eof292;
case 292:
	switch( (*p) ) {
		case 33u: goto st252;
		case 35u: goto tr280;
		case 37u: goto st33;
		case 46u: goto st276;
		case 47u: goto tr281;
		case 58u: goto tr301;
		case 61u: goto st252;
		case 63u: goto tr283;
		case 64u: goto tr40;
		case 95u: goto st252;
		case 126u: goto st252;
		default: break;
	}
	if ( (*p) < 54u ) {
		if ( (*p) > 45u ) {
			if ( 48u <= (*p) && (*p) <= 53u )
				goto st275;
		} else if ( (*p) >= 36u )
			goto st252;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto st252;
		} else if ( (*p) >= 65u )
			goto st252;
	} else
		goto st252;
	goto st0;
		default: break;
	}
	_test_eof232: cs = 232; goto _test_eof; 
	_test_eof233: cs = 233; goto _test_eof; 
	_test_eof234: cs = 234; goto _test_eof; 
	_test_eof1: cs = 1; goto _test_eof; 
	_test_eof2: cs = 2; goto _test_eof; 
	_test_eof3: cs = 3; goto _test_eof; 
	_test_eof4: cs = 4; goto _test_eof; 
	_test_eof235: cs = 235; goto _test_eof; 
	_test_eof236: cs = 236; goto _test_eof; 
	_test_eof5: cs = 5; goto _test_eof; 
	_test_eof6: cs = 6; goto _test_eof; 
	_test_eof237: cs = 237; goto _test_eof; 
	_test_eof238: cs = 238; goto _test_eof; 
	_test_eof7: cs = 7; goto _test_eof; 
	_test_eof8: cs = 8; goto _test_eof; 
	_test_eof239: cs = 239; goto _test_eof; 
	_test_eof240: cs = 240; goto _test_eof; 
	_test_eof241: cs = 241; goto _test_eof; 
	_test_eof242: cs = 242; goto _test_eof; 
	_test_eof9: cs = 9; goto _test_eof; 
	_test_eof10: cs = 10; goto _test_eof; 
	_test_eof11: cs = 11; goto _test_eof; 
	_test_eof12: cs = 12; goto _test_eof; 
	_test_eof13: cs = 13; goto _test_eof; 
	_test_eof14: cs = 14; goto _test_eof; 
	_test_eof15: cs = 15; goto _test_eof; 
	_test_eof16: cs = 16; goto _test_eof; 
	_test_eof17: cs = 17; goto _test_eof; 
	_test_eof18: cs = 18; goto _test_eof; 
	_test_eof19: cs = 19; goto _test_eof; 
	_test_eof20: cs = 20; goto _test_eof; 
	_test_eof21: cs = 21; goto _test_eof; 
	_test_eof22: cs = 22; goto _test_eof; 
	_test_eof243: cs = 243; goto _test_eof; 
	_test_eof244: cs = 244; goto _test_eof; 
	_test_eof245: cs = 245; goto _test_eof; 
	_test_eof23: cs = 23; goto _test_eof; 
	_test_eof24: cs = 24; goto _test_eof; 
	_test_eof246: cs = 246; goto _test_eof; 
	_test_eof247: cs = 247; goto _test_eof; 
	_test_eof248: cs = 248; goto _test_eof; 
	_test_eof249: cs = 249; goto _test_eof; 
	_test_eof250: cs = 250; goto _test_eof; 
	_test_eof251: cs = 251; goto _test_eof; 
	_test_eof25: cs = 25; goto _test_eof; 
	_test_eof26: cs = 26; goto _test_eof; 
	_test_eof27: cs = 27; goto _test_eof; 
	_test_eof28: cs = 28; goto _test_eof; 
	_test_eof29: cs = 29; goto _test_eof; 
	_test_eof30: cs = 30; goto _test_eof; 
	_test_eof31: cs = 31; goto _test_eof; 
	_test_eof32: cs = 32; goto _test_eof; 
	_test_eof252: cs = 252; goto _test_eof; 
	_test_eof33: cs = 33; goto _test_eof; 
	_test_eof34: cs = 34; goto _test_eof; 
	_test_eof253: cs = 253; goto _test_eof; 
	_test_eof35: cs = 35; goto _test_eof; 
	_test_eof36: cs = 36; goto _test_eof; 
	_test_eof37: cs = 37; goto _test_eof; 
	_test_eof254: cs = 254; goto _test_eof; 
	_test_eof255: cs = 255; goto _test_eof; 
	_test_eof38: cs = 38; goto _test_eof; 
	_test_eof39: cs = 39; goto _test_eof; 
	_test_eof256: cs = 256; goto _test_eof; 
	_test_eof257: cs = 257; goto _test_eof; 
	_test_eof258: cs = 258; goto _test_eof; 
	_test_eof259: cs = 259; goto _test_eof; 
	_test_eof260: cs = 260; goto _test_eof; 
	_test_eof261: cs = 261; goto _test_eof; 
	_test_eof262: cs = 262; goto _test_eof; 
	_test_eof263: cs = 263; goto _test_eof; 
	_test_eof264: cs = 264; goto _test_eof; 
	_test_eof265: cs = 265; goto _test_eof; 
	_test_eof266: cs = 266; goto _test_eof; 
	_test_eof267: cs = 267; goto _test_eof; 
	_test_eof268: cs = 268; goto _test_eof; 
	_test_eof269: cs = 269; goto _test_eof; 
	_test_eof270: cs = 270; goto _test_eof; 
	_test_eof271: cs = 271; goto _test_eof; 
	_test_eof272: cs = 272; goto _test_eof; 
	_test_eof273: cs = 273; goto _test_eof; 
	_test_eof40: cs = 40; goto _test_eof; 
	_test_eof41: cs = 41; goto _test_eof; 
	_test_eof42: cs = 42; goto _test_eof; 
	_test_eof43: cs = 43; goto _test_eof; 
	_test_eof44: cs = 44; goto _test_eof; 
	_test_eof45: cs = 45; goto _test_eof; 
	_test_eof46: cs = 46; goto _test_eof; 
	_test_eof47: cs = 47; goto _test_eof; 
	_test_eof48: cs = 48; goto _test_eof; 
	_test_eof49: cs = 49; goto _test_eof; 
	_test_eof50: cs = 50; goto _test_eof; 
	_test_eof51: cs = 51; goto _test_eof; 
	_test_eof52: cs = 52; goto _test_eof; 
	_test_eof53: cs = 53; goto _test_eof; 
	_test_eof54: cs = 54; goto _test_eof; 
	_test_eof55: cs = 55; goto _test_eof; 
	_test_eof56: cs = 56; goto _test_eof; 
	_test_eof57: cs = 57; goto _test_eof; 
	_test_eof58: cs = 58; goto _test_eof; 
	_test_eof59: cs = 59; goto _test_eof; 
	_test_eof60: cs = 60; goto _test_eof; 
	_test_eof61: cs = 61; goto _test_eof; 
	_test_eof62: cs = 62; goto _test_eof; 
	_test_eof63: cs = 63; goto _test_eof; 
	_test_eof64: cs = 64; goto _test_eof; 
	_test_eof65: cs = 65; goto _test_eof; 
	_test_eof66: cs = 66; goto _test_eof; 
	_test_eof67: cs = 67; goto _test_eof; 
	_test_eof68: cs = 68; goto _test_eof; 
	_test_eof69: cs = 69; goto _test_eof; 
	_test_eof70: cs = 70; goto _test_eof; 
	_test_eof71: cs = 71; goto _test_eof; 
	_test_eof72: cs = 72; goto _test_eof; 
	_test_eof73: cs = 73; goto _test_eof; 
	_test_eof74: cs = 74; goto _test_eof; 
	_test_eof75: cs = 75; goto _test_eof; 
	_test_eof76: cs = 76; goto _test_eof; 
	_test_eof77: cs = 77; goto _test_eof; 
	_test_eof78: cs = 78; goto _test_eof; 
	_test_eof79: cs = 79; goto _test_eof; 
	_test_eof80: cs = 80; goto _test_eof; 
	_test_eof81: cs = 81; goto _test_eof; 
	_test_eof82: cs = 82; goto _test_eof; 
	_test_eof83: cs = 83; goto _test_eof; 
	_test_eof84: cs = 84; goto _test_eof; 
	_test_eof85: cs = 85; goto _test_eof; 
	_test_eof86: cs = 86; goto _test_eof; 
	_test_eof87: cs = 87; goto _test_eof; 
	_test_eof88: cs = 88; goto _test_eof; 
	_test_eof89: cs = 89; goto _test_eof; 
	_test_eof90: cs = 90; goto _test_eof; 
	_test_eof91: cs = 91; goto _test_eof; 
	_test_eof92: cs = 92; goto _test_eof; 
	_test_eof93: cs = 93; goto _test_eof; 
	_test_eof94: cs = 94; goto _test_eof; 
	_test_eof95: cs = 95; goto _test_eof; 
	_test_eof96: cs = 96; goto _test_eof; 
	_test_eof97: cs = 97; goto _test_eof; 
	_test_eof98: cs = 98; goto _test_eof; 
	_test_eof99: cs = 99; goto _test_eof; 
	_test_eof100: cs = 100; goto _test_eof; 
	_test_eof101: cs = 101; goto _test_eof; 
	_test_eof102: cs = 102; goto _test_eof; 
	_test_eof103: cs = 103; goto _test_eof; 
	_test_eof104: cs = 104; goto _test_eof; 
	_test_eof105: cs = 105; goto _test_eof; 
	_test_eof106: cs = 106; goto _test_eof; 
	_test_eof107: cs = 107; goto _test_eof; 
	_test_eof108: cs = 108; goto _test_eof; 
	_test_eof109: cs = 109; goto _test_eof; 
	_test_eof110: cs = 110; goto _test_eof; 
	_test_eof111: cs = 111; goto _test_eof; 
	_test_eof112: cs = 112; goto _test_eof; 
	_test_eof113: cs = 113; goto _test_eof; 
	_test_eof114: cs = 114; goto _test_eof; 
	_test_eof115: cs = 115; goto _test_eof; 
	_test_eof116: cs = 116; goto _test_eof; 
	_test_eof117: cs = 117; goto _test_eof; 
	_test_eof118: cs = 118; goto _test_eof; 
	_test_eof119: cs = 119; goto _test_eof; 
	_test_eof120: cs = 120; goto _test_eof; 
	_test_eof121: cs = 121; goto _test_eof; 
	_test_eof122: cs = 122; goto _test_eof; 
	_test_eof123: cs = 123; goto _test_eof; 
	_test_eof124: cs = 124; goto _test_eof; 
	_test_eof125: cs = 125; goto _test_eof; 
	_test_eof126: cs = 126; goto _test_eof; 
	_test_eof127: cs = 127; goto _test_eof; 
	_test_eof128: cs = 128; goto _test_eof; 
	_test_eof129: cs = 129; goto _test_eof; 
	_test_eof130: cs = 130; goto _test_eof; 
	_test_eof131: cs = 131; goto _test_eof; 
	_test_eof132: cs = 132; goto _test_eof; 
	_test_eof133: cs = 133; goto _test_eof; 
	_test_eof134: cs = 134; goto _test_eof; 
	_test_eof135: cs = 135; goto _test_eof; 
	_test_eof136: cs = 136; goto _test_eof; 
	_test_eof137: cs = 137; goto _test_eof; 
	_test_eof138: cs = 138; goto _test_eof; 
	_test_eof139: cs = 139; goto _test_eof; 
	_test_eof140: cs = 140; goto _test_eof; 
	_test_eof141: cs = 141; goto _test_eof; 
	_test_eof142: cs = 142; goto _test_eof; 
	_test_eof143: cs = 143; goto _test_eof; 
	_test_eof144: cs = 144; goto _test_eof; 
	_test_eof145: cs = 145; goto _test_eof; 
	_test_eof146: cs = 146; goto _test_eof; 
	_test_eof147: cs = 147; goto _test_eof; 
	_test_eof148: cs = 148; goto _test_eof; 
	_test_eof149: cs = 149; goto _test_eof; 
	_test_eof150: cs = 150; goto _test_eof; 
	_test_eof151: cs = 151; goto _test_eof; 
	_test_eof152: cs = 152; goto _test_eof; 
	_test_eof153: cs = 153; goto _test_eof; 
	_test_eof154: cs = 154; goto _test_eof; 
	_test_eof155: cs = 155; goto _test_eof; 
	_test_eof156: cs = 156; goto _test_eof; 
	_test_eof157: cs = 157; goto _test_eof; 
	_test_eof158: cs = 158; goto _test_eof; 
	_test_eof159: cs = 159; goto _test_eof; 
	_test_eof160: cs = 160; goto _test_eof; 
	_test_eof161: cs = 161; goto _test_eof; 
	_test_eof162: cs = 162; goto _test_eof; 
	_test_eof163: cs = 163; goto _test_eof; 
	_test_eof164: cs = 164; goto _test_eof; 
	_test_eof165: cs = 165; goto _test_eof; 
	_test_eof166: cs = 166; goto _test_eof; 
	_test_eof167: cs = 167; goto _test_eof; 
	_test_eof168: cs = 168; goto _test_eof; 
	_test_eof169: cs = 169; goto _test_eof; 
	_test_eof170: cs = 170; goto _test_eof; 
	_test_eof171: cs = 171; goto _test_eof; 
	_test_eof172: cs = 172; goto _test_eof; 
	_test_eof173: cs = 173; goto _test_eof; 
	_test_eof174: cs = 174; goto _test_eof; 
	_test_eof175: cs = 175; goto _test_eof; 
	_test_eof176: cs = 176; goto _test_eof; 
	_test_eof177: cs = 177; goto _test_eof; 
	_test_eof178: cs = 178; goto _test_eof; 
	_test_eof179: cs = 179; goto _test_eof; 
	_test_eof180: cs = 180; goto _test_eof; 
	_test_eof181: cs = 181; goto _test_eof; 
	_test_eof182: cs = 182; goto _test_eof; 
	_test_eof183: cs = 183; goto _test_eof; 
	_test_eof184: cs = 184; goto _test_eof; 
	_test_eof185: cs = 185; goto _test_eof; 
	_test_eof186: cs = 186; goto _test_eof; 
	_test_eof187: cs = 187; goto _test_eof; 
	_test_eof188: cs = 188; goto _test_eof; 
	_test_eof189: cs = 189; goto _test_eof; 
	_test_eof190: cs = 190; goto _test_eof; 
	_test_eof191: cs = 191; goto _test_eof; 
	_test_eof192: cs = 192; goto _test_eof; 
	_test_eof193: cs = 193; goto _test_eof; 
	_test_eof194: cs = 194; goto _test_eof; 
	_test_eof195: cs = 195; goto _test_eof; 
	_test_eof196: cs = 196; goto _test_eof; 
	_test_eof197: cs = 197; goto _test_eof; 
	_test_eof198: cs = 198; goto _test_eof; 
	_test_eof199: cs = 199; goto _test_eof; 
	_test_eof200: cs = 200; goto _test_eof; 
	_test_eof201: cs = 201; goto _test_eof; 
	_test_eof202: cs = 202; goto _test_eof; 
	_test_eof203: cs = 203; goto _test_eof; 
	_test_eof204: cs = 204; goto _test_eof; 
	_test_eof205: cs = 205; goto _test_eof; 
	_test_eof206: cs = 206; goto _test_eof; 
	_test_eof207: cs = 207; goto _test_eof; 
	_test_eof208: cs = 208; goto _test_eof; 
	_test_eof209: cs = 209; goto _test_eof; 
	_test_eof210: cs = 210; goto _test_eof; 
	_test_eof211: cs = 211; goto _test_eof; 
	_test_eof212: cs = 212; goto _test_eof; 
	_test_eof213: cs = 213; goto _test_eof; 
	_test_eof214: cs = 214; goto _test_eof; 
	_test_eof215: cs = 215; goto _test_eof; 
	_test_eof216: cs = 216; goto _test_eof; 
	_test_eof217: cs = 217; goto _test_eof; 
	_test_eof218: cs = 218; goto _test_eof; 
	_test_eof219: cs = 219; goto _test_eof; 
	_test_eof220: cs = 220; goto _test_eof; 
	_test_eof221: cs = 221; goto _test_eof; 
	_test_eof222: cs = 222; goto _test_eof; 
	_test_eof223: cs = 223; goto _test_eof; 
	_test_eof224: cs = 224; goto _test_eof; 
	_test_eof225: cs = 225; goto _test_eof; 
	_test_eof226: cs = 226; goto _test_eof; 
	_test_eof227: cs = 227; goto _test_eof; 
	_test_eof228: cs = 228; goto _test_eof; 
	_test_eof229: cs = 229; goto _test_eof; 
	_test_eof230: cs = 230; goto _test_eof; 
	_test_eof274: cs = 274; goto _test_eof; 
	_test_eof275: cs = 275; goto _test_eof; 
	_test_eof276: cs = 276; goto _test_eof; 
	_test_eof277: cs = 277; goto _test_eof; 
	_test_eof278: cs = 278; goto _test_eof; 
	_test_eof279: cs = 279; goto _test_eof; 
	_test_eof280: cs = 280; goto _test_eof; 
	_test_eof281: cs = 281; goto _test_eof; 
	_test_eof282: cs = 282; goto _test_eof; 
	_test_eof283: cs = 283; goto _test_eof; 
	_test_eof284: cs = 284; goto _test_eof; 
	_test_eof285: cs = 285; goto _test_eof; 
	_test_eof286: cs = 286; goto _test_eof; 
	_test_eof287: cs = 287; goto _test_eof; 
	_test_eof288: cs = 288; goto _test_eof; 
	_test_eof289: cs = 289; goto _test_eof; 
	_test_eof290: cs = 290; goto _test_eof; 
	_test_eof291: cs = 291; goto _test_eof; 
	_test_eof292: cs = 292; goto _test_eof; 

	_test_eof: {}
	if ( p == eof )
	{
	switch ( cs ) {
	case 247: 
	case 274: 
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	break;
	case 243: 
	case 248: 
	case 249: 
	case 250: 
	case 251: 
	case 252: 
	case 255: 
	case 256: 
	case 257: 
	case 258: 
	case 259: 
	case 260: 
	case 261: 
	case 262: 
	case 263: 
	case 264: 
	case 265: 
	case 266: 
	case 267: 
	case 268: 
	case 269: 
	case 270: 
	case 271: 
	case 272: 
	case 273: 
	case 275: 
	case 276: 
	case 277: 
	case 278: 
	case 279: 
	case 280: 
	case 281: 
	case 282: 
	case 283: 
	case 284: 
	case 285: 
	case 286: 
	case 287: 
	case 288: 
	case 289: 
	case 290: 
	case 291: 
	case 292: 
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 232: 
	case 236: 
	case 239: 
	case 245: 
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 241: 
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
	break;
	case 231: 
	case 240: 
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
	break;
	case 238: 
#line 768 "uri_parser.rl"
	{
        query = unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 234: 
#line 773 "uri_parser.rl"
	{
        fragment = unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 246: 
	case 253: 
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 700 "uri_parser.rl"
	{
        if (p == mark)
            authority.port = -1;
        else
            authority.port = to!(int)(mark[0..p-mark]);
        mark = null;
    }
	break;
	case 242: 
	case 254: 
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 713 "uri_parser.rl"
	{
        authority.host = unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 235: 
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 237: 
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 768 "uri_parser.rl"
	{
        query = unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 233: 
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 773 "uri_parser.rl"
	{
        fragment = unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 244: 
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
#line 6750 "uri.d"
		default: break;
	}
	}

	_out: {}
	}
#line 820 "uri_parser.rl"
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
    
#line 6780 "uri.d"
static const int uri_path_parser_start = 5;
static const int uri_path_parser_first_final = 5;
static const int uri_path_parser_error = 0;

static const int uri_path_parser_en_main = 5;

#line 846 "uri_parser.rl"


public:
    this(ref URI.Path _path)
    {
        path = &_path;
    }

    void init()
    {
        super.init();
        
#line 6800 "uri.d"
	{
	cs = uri_path_parser_start;
	}
#line 858 "uri_parser.rl"
    }

protected:
    void exec()
    {
        
#line 6811 "uri.d"
	{
	if ( p == pe )
		goto _test_eof;
	switch ( cs )
	{
case 5:
	switch( (*p) ) {
		case 33u: goto tr5;
		case 37u: goto tr6;
		case 47u: goto st8;
		case 61u: goto tr5;
		case 95u: goto tr5;
		case 126u: goto tr5;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr5;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr5;
	} else
		goto tr5;
	goto st0;
st0:
cs = 0;
	goto _out;
tr5:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st6;
tr10:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st6;
st6:
	if ( ++p == pe )
		goto _test_eof6;
case 6:
#line 6855 "uri.d"
	switch( (*p) ) {
		case 33u: goto st6;
		case 37u: goto st1;
		case 47u: goto tr9;
		case 61u: goto st6;
		case 95u: goto st6;
		case 126u: goto st6;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st6;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st6;
	} else
		goto st6;
	goto st0;
tr6:
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st1;
tr11:
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st1;
st1:
	if ( ++p == pe )
		goto _test_eof1;
case 1:
#line 6890 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st2;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st2;
	} else
		goto st2;
	goto st0;
st2:
	if ( ++p == pe )
		goto _test_eof2;
case 2:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st6;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st6;
	} else
		goto st6;
	goto st0;
tr9:
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st7;
tr12:
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st7;
st7:
	if ( ++p == pe )
		goto _test_eof7;
case 7:
#line 6933 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr10;
		case 37u: goto tr11;
		case 47u: goto tr12;
		case 61u: goto tr10;
		case 95u: goto tr10;
		case 126u: goto tr10;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr10;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr10;
	} else
		goto tr10;
	goto st0;
tr17:
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st8;
tr15:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	goto st8;
st8:
	if ( ++p == pe )
		goto _test_eof8;
case 8:
#line 6976 "uri.d"
	switch( (*p) ) {
		case 33u: goto tr13;
		case 37u: goto tr14;
		case 47u: goto tr15;
		case 61u: goto tr13;
		case 95u: goto tr13;
		case 126u: goto tr13;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto tr13;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr13;
	} else
		goto tr13;
	goto st0;
tr13:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st9;
st9:
	if ( ++p == pe )
		goto _test_eof9;
case 9:
#line 7007 "uri.d"
	switch( (*p) ) {
		case 33u: goto st9;
		case 37u: goto st3;
		case 47u: goto tr17;
		case 61u: goto st9;
		case 95u: goto st9;
		case 126u: goto st9;
		default: break;
	}
	if ( (*p) < 64u ) {
		if ( 36u <= (*p) && (*p) <= 59u )
			goto st9;
	} else if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto st9;
	} else
		goto st9;
	goto st0;
tr14:
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
	goto st3;
st3:
	if ( ++p == pe )
		goto _test_eof3;
case 3:
#line 7038 "uri.d"
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st4;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st4;
	} else
		goto st4;
	goto st0;
st4:
	if ( ++p == pe )
		goto _test_eof4;
case 4:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto st9;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto st9;
	} else
		goto st9;
	goto st0;
		default: break;
	}
	_test_eof6: cs = 6; goto _test_eof; 
	_test_eof1: cs = 1; goto _test_eof; 
	_test_eof2: cs = 2; goto _test_eof; 
	_test_eof7: cs = 7; goto _test_eof; 
	_test_eof8: cs = 8; goto _test_eof; 
	_test_eof9: cs = 9; goto _test_eof; 
	_test_eof3: cs = 3; goto _test_eof; 
	_test_eof4: cs = 4; goto _test_eof; 

	_test_eof: {}
	if ( p == eof )
	{
	switch ( cs ) {
	case 6: 
	case 9: 
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 5: 
#line 756 "uri_parser.rl"
	{
        path.type = URI.Path.Type.RELATIVE;
    }
	break;
	case 7: 
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 8: 
#line 752 "uri_parser.rl"
	{
        path.type = URI.Path.Type.ABSOLUTE;
    }
#line 690 "uri_parser.rl"
	{ mark = p; }
#line 741 "uri_parser.rl"
	{
        path.segments ~= unescape(mark[0..p - mark]);
        mark = null;
    }
	break;
#line 7112 "uri.d"
		default: break;
	}
	}

	_out: {}
	}
#line 864 "uri_parser.rl"
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
