/* To compile to .d:
   ragel parser.rl -D -o parser.d
*/

module mordor.common.http.parser;

import tango.math.Math;
import tango.text.Util;
import tango.util.Convert;
import tango.util.log.Log;

import mordor.common.containers.redblacktree;
import mordor.common.ragel;
import mordor.common.stringutils;

enum Method
{
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE
}

private string[] _methodStrings = [
    "GET",
    "HEAD",
    "POST",
    "PUT",
    "DELETE",
    "CONNECT",
    "OPTIONS",
    "TRACE"];

package Method parseHttpMethod(string method)
{
    foreach(i, m; _methodStrings) {
        if (method == m)
            return cast(Method)i;
    }
    throw new Exception("invalid method" ~ method);
}

enum Status
{
    CONTINUE                         = 100,
    SWITCHING_PROTOCOL               = 101,
    
    OK                               = 200,
    CREATED                          = 201,
    ACCEPTED                         = 202,
    NON_AUTHORITATIVE_INFORMATION    = 203,
    NO_CONTENT                       = 204,
    RESET_CONTENT                    = 205,
    PARTIAL_CONTENT                  = 206,

    MULTIPLE_CHOICES                 = 300,
    MOVED_PERMANENTLY                = 301,
    FOUND                            = 302,
    SEE_OTHER                        = 303,
    NOT_MODIFIED                     = 304,
    USE_PROXY                        = 305,
    // UNUSED                        = 306,
    TEMPORARY_REDIRECT               = 307,

    BAD_REQUEST                      = 400,
    UNAUTHORIZED                     = 401,
    PAYMENT_REQUIRED                 = 402,
    FORBIDDEN                        = 403,
    NOT_FOUND                        = 404,
    METHOD_NOT_ALLOWED               = 405,
    NOT_ACCEPTABLE                   = 406,
    PROXY_AUTHENTICATION_REQUIRED    = 407,
    REQUEST_TIMEOUT                  = 408,
    CONFLICT                         = 409,
    GONE                             = 410,
    LENGTH_REQUIRED                  = 411,
    PRECONDITION_FAILED              = 412,
    REQUEST_ENTITY_TOO_LARGE         = 413,
    REQUEST_URI_TOO_LONG             = 414,
    UNSUPPORTED_MEDIA_TYPE           = 415,
    REQUESTED_RANGE_NOT_SATISFIEABLE = 416,
    EXPECTATION_FAILED               = 417,

    INTERNAL_SERVER_ERROR            = 500,
    NOT_IMPLEMENTED                  = 501,
    BAD_GATEWAY                      = 502,
    SERVICE_UNAVAILABLE              = 503,
    GATEWAY_TIMEOUT                  = 504,
    HTTP_VERSION_NOT_SUPPORTED       = 505
}

struct Version
{
    ubyte major = cast(ubyte)~0;
    ubyte minor = cast(ubyte)~0;
    
    string toString()
    in
    {
        assert(*this != Version.init);
    }
    body
    {
        return "HTTP/" ~ to!(string)(major) ~ "." ~ to!(string)(minor);
    }
    
    static Version fromString(string str)
    {
        if (str.length < 8 || str[0..5] != "HTTP/")
            throw new ConversionException("Version number does not start with HTTP/");
        string[] parts = split(str[5..$], ".");
        if (parts.length != 2)
            throw new ConversionException("Not enough pieces for an HTTP version number.");
        return Version(to!(ubyte)(parts[0]), to!(ubyte)(parts[1]));
    }
}

// TODO: really case insensitive
alias RedBlackTree!(string) StringSet;

struct ValueWithParameters
{
    string value;
    string[string] parameters;
}

alias ValueWithParameters[] ParameterizedList;

struct RequestLine
{
    Method method;
    string uri;
    Version ver;
    
    string toString()
    {
        return _methodStrings[cast(size_t)method] ~ " " ~ uri ~ " " ~ ver.toString();
    }
}

struct StatusLine
{
    Status status;
    string reason;
    Version ver;

    string toString()
    {
        return ver.toString() ~ " " ~ to!(string)(cast(int)status) ~ " " ~ reason;
    }
}

struct GeneralHeaders
{
    StringSet connection;
    ParameterizedList transferEncoding;
    
    string toString()
    {
        string ret;
        if (connection !is null && !connection.empty)
            ret ~= "Connection: " ~ .toString(connection) ~ "\r\n";
        if (transferEncoding.length > 0) {
            ret ~= "Transfer-Encoding: ";
            foreach(i, v; transferEncoding) {
                if (i != 0)
                    ret ~= ", ";
                ret ~= v.value;
                foreach(a, p; v.parameters) {
                    ret ~= ";" ~ a ~ "=" ~ quote(p);
                }
            }
            ret ~= "\r\n";
        }
        return ret;
    }
}

struct RequestHeaders
{
    string host;
    
    string toString()
    {
        string ret;
        if (host.length > 0)
            ret ~= "Host: " ~ host ~ "\r\n";
        return ret;
    }
}

struct ResponseHeaders
{
    string location;

    string toString()
    {
        string ret;
        if (location.length > 0)
            ret ~= "Location: " ~ location ~ "\r\n";
        return ret;
    }
}

struct EntityHeaders
{
    ulong contentLength = ~0;
    string[string] extension;

    string toString()
    {
        string ret;
        if (contentLength != ~0) {
            ret ~= "Content-Length: " ~ to!(string)(contentLength) ~ "\r\n";
        }
        foreach(k,v; extension) {
            ret ~= k ~ ": " ~ v ~ "\r\n";
        }
        return ret;
    }
}

struct Request
{
    RequestLine requestLine;
    GeneralHeaders general;
    RequestHeaders request;
    EntityHeaders entity;
    
    string toString()
    {
        // TODO: This is inefficient... fix it
        return requestLine.toString() ~ "\r\n" ~
               general.toString() ~
               request.toString() ~
               entity.toString() ~ "\r\n";
    }
}

struct Response
{
    StatusLine status;
    GeneralHeaders general;
    ResponseHeaders response;
    EntityHeaders entity;
    
    string toString()
    {
        return status.toString() ~ "\r\n" ~
               general.toString() ~
               response.toString() ~
               entity.toString() ~ "\r\n";
    }
}

string toString(StringSet set)
{
    string ret;
    foreach(item; set)
    {
        if (ret.length > 0)
            ret ~= ", ";
        ret ~= item;
    }
    return ret;
}

unittest
{
    Request request;
    request.requestLine.uri = "/";
    request.requestLine.ver = Version(1,1);
    
    assert(request.toString() == "GET / HTTP/1.1\r\n\r\n", request.toString());
    
//    request.general.connection = new IStringSet();
//    request.general.connection.insert("close");
//    assert(request.toString() == "GET / HTTP/1.1\r\nConnection: close\r\n\r\n", request.toString());
}

unittest
{
    string request = "GET / HTTP/1.0\r\n"
        "Transfer-Encoding: chunked\r\n"
        "\r\n";
    Request headers;
    
/+    auto parser = new RequestParser(headers);
    
    parser.run(request);
    with (headers) {
        assert(requestLine.method = Method.GET);
        assert(requestLine.ver = Version(1, 0));
        assert(general.transferEncoding.length == 1);
        assert(general.transferEncoding[0].value == "chunked");
        assert(general.transferEncoding[0].parameters.length == 0);
    }+/
}

void
unfold(ref char[] ps)
{
    char* p = ps.ptr, pw = ps.ptr;
    char* pe = ps.ptr + ps.length;

    while (p < pe) {
        // Skip leading whitespace
        if (pw == ps.ptr) {
            if (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') {
                ++p;
                continue;
            }
        }
        // Remove interior line breaks
        if (*p == '\r' || *p == '\n') {
            ++p;
            continue;
        }
        // Only copy if necessary
        if (pw != p) {
            *pw = *p;
        }
        ++p; ++pw;
    }
    // Remove trailing whitespace (\r and \n already removed)
    do {
        --pw;
    } while ((*pw == ' ' || *pw == '\t') && pw >= ps.ptr);
    ++pw;
    // reset len
    ps = ps[0..pw - ps.ptr];
}

void
unquote(ref char[] ps)
{
    if (ps.length == 0 || ps[0] != '"') {
        return;
    }

    char* p = ps.ptr, pw = ps.ptr;
    char* pe = ps.ptr + ps.length;

    assert(*p == '"');
    assert(*(pe - 1) == '"');
    bool escaping = false;
    ++p; --pe;
    while (p < pe) {
        if (escaping) {
            escaping = false;
        } else if (*p == '\\') {
            escaping = true;
            ++p;
            continue;
        }
        *pw++ = *p++;
    }
    // reset len
    ps = ps[0..pw - ps.ptr];
}

unittest {
    string tom = "tom".dup;
    unquote(tom);
    assert(tom == "tom");
    tom = "\"tom\"".dup;
    unquote(tom);
    assert(tom == "tom");
    tom = "\"tom\\a\"".dup;
    unquote(tom);
    assert(tom == "toma");
    tom = "\"tom\\\\\"".dup;
    unquote(tom);
    assert(tom == "tom\\");
    tom = "123".dup;
    unquote(tom);
    assert(tom == "123");
    tom = "\"tom \\\"tom\\\" tom\"".dup;
    unquote(tom);
    assert(tom == "tom \"tom\" tom");
}

package class NeedQuote : RagelParser
{
private:
%%{
    machine need_quote;
    include http_parser "basics.rl";
    main := token;
    write data;
}%%
public:
    void init() {
        super.init();
        %% write init;
    }
    bool complete() {
        return cs >= need_quote_first_final;
    }
    bool error() {
        return cs == need_quote_error;
    }
protected:
    void exec() {
        %% write exec;
    }
};

char[]
quote(string str)
{
    if (str.length == 0)
        return "\"\"";

    // Easy parser that just verifies it's a token
    scope parser = new NeedQuote();
    parser.run(str);
    if (parser.complete && !parser.error)
        return str;

    char[] ret;
    ret = "\"";
    // "reserve"
    ret.length = str.length + 2;
    ret.length = 1;

    size_t lastEscape = 0;
    size_t nextEscape = min(locate(str, '\\'), locate(str, '"'));
    while(nextEscape != str.length) {
        ret ~= str[lastEscape..nextEscape - lastEscape];
        ret ~= '\\';
        ret ~= str[nextEscape];
        lastEscape = nextEscape + 1;
        nextEscape = min(locate(str, '\\', lastEscape), locate(str, '"', lastEscape));
    }
    ret ~= str[lastEscape..$];
    ret ~= '"';
    return ret;
}

unittest
{
    assert(quote("tom") == "tom");
    assert(quote("") == "\"\"");
    assert(quote("\"") == "\"\\\"\"");
    assert(quote("co\\dy") == "\"co\\\\dy\"");    
}

class RequestParser : RagelParser
{
    static this()
    {
        _log = Log.lookup("mordor.common.http.parser.request");
    }
private:
    %%{
        machine http_request_parser;
        include http_parser "basics.rl";
        include uri_parser "uri_parser.rl";
    
        action parse_Method {
            requestLine.method =
                parseHttpMethod(mark[0..fpc - mark]);
            mark = null;
        }
    
        action parse_Request_URI {
            requestLine.uri = mark[0..fpc - mark];
            mark = null;
        }
        
        action set_host {
            _headerHandled = true;
            _string = &request.host;
        }

        # TODO: Parse and save the port
        Host = 'Host:' @set_host LWS* hostport >mark %save_string LWS*;
        
        request_header = Host;
    
        Method = token >mark %parse_Method;
        Request_URI = ( "*" | absoluteURI | hier_part | authority) >mark %parse_Request_URI;
        Request_Line = Method SP Request_URI SP HTTP_Version CRLF;
        Request = Request_Line ((general_header | request_header | entity_header) CRLF)* CRLF @done;
    
        main := Request;
        write data;
    }%%

public:
    void init()
    {
        super.init();
        %% write init;
    }

protected:
    void exec()
    {
        with(_request.requestLine) with(_request.entity) with(*_request) {
            %% write exec;
        }
    }

public:
    bool complete()
    {
        return cs >= http_request_parser_first_final;
    }

    bool error()
    {
        return cs == http_request_parser_error;
    }

private:    
    Request* _request;
    bool _headerHandled;
    string _temp1;
    string _temp2;
    StringSet _list;
    ParameterizedList* _parameterizedList;
    string* _string;
    ulong* _ulong;
    static Logger _log;
}

class ResponseParser : RagelParser
{
    static this()
    {
        _log = Log.lookup("mordor.common.http.parser.response");
    }
private:
    %%{
        machine http_response_parser;
        include http_parser "basics.rl";
        include uri_parser "uri_parser.rl";
        
        action parse_Status_Code {
            status.status = cast(Status)to!(int)(mark[0..fpc - mark]);
            mark = null;
        }
    
        action parse_Reason_Phrase {
            status.reason = mark[0..fpc - mark];
            mark = null;
        }
        
        action set_location {
            _headerHandled = true;
            _string = &response.location;
        }
        
        Location = 'Location:' @set_location LWS* absoluteURI >mark %save_string LWS*;
        
        response_header = Location;

        Status_Code = DIGIT{3} > mark %parse_Status_Code;
        Reason_Phrase = (TEXT -- (CR | LF))* >mark %parse_Reason_Phrase;
        Status_Line = HTTP_Version SP Status_Code SP Reason_Phrase CRLF;
        Response = Status_Line ((general_header | response_header | entity_header) CRLF)* CRLF @done;
    
        main := Response;

        write data;
    }%%

public:
    void init()
    {
        super.init();
        %% write init;
    }

protected:
    void exec()
    {
        with(_response.status) with(_response.entity) with (*_response) {
            %% write exec;
        }
    }

public:
    this(ref Response response)
    {
        _response = &response;
    }
        
    bool complete()
    {
        return cs >= http_response_parser_first_final;
    }

    bool error()
    {
        return cs == http_response_parser_error;
    }

private:    
    Response* _response;
    bool _headerHandled;
    string _temp1;
    string _temp2;
    StringSet _list;
    ParameterizedList* _parameterizedList;
    string* _string;
    ulong* _ulong;
    static Logger _log;
}

class TrailerParser : RagelParser
{
    static this()
    {
        _log = Log.lookup("mordor.common.http.parser.trailer");
    }
private:
    %%{
        machine http_trailer_parser;
        include http_parser "basics.rl";

        trailer = (entity_header CRLF)*;
    
        main := trailer CRLF @done;

        write data;
    }%%

public:
    void init()
    {
        super.init();
        %% write init;
    }

protected:
    void exec()
    {
        with(*_entity) {
            %% write exec;
        }
    }

public:
    this(ref EntityHeaders entity)
    {
        _entity = &entity;
    }
        
    bool complete()
    {
        return cs >= http_trailer_parser_first_final;
    }

    bool error()
    {
        return cs == http_trailer_parser_error;
    }

private:    
    EntityHeaders* _entity;
    bool _headerHandled;
    string _temp1;
    string _temp2;
    StringSet _list;
    ParameterizedList* _parameterizedList;
    string* _string;
    ulong* _ulong;
    static Logger _log;
}
