module mordor.common.http.http;

import tango.text.Util;
import tango.util.Convert;

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
    IStringSet connection;
    
    string toString()
    {
        string ret;
        if (connection !is null)
            ret ~= "Connection: " ~ .toString(connection) ~ "\r\n";
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
            ret ~= "Host: " ~ ret ~ "\r\n";
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
    string toString()
    {
        return "";
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

string toString(IStringSet set)
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
    
    request.general.connection = new IStringSet();
    request.general.connection.insert("close");
    assert(request.toString() == "GET / HTTP/1.1\r\nConnection: close\r\n\r\n", request.toString());
}
