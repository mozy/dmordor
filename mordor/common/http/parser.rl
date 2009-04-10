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
import mordor.common.http.http;
import mordor.common.stringutils;

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
    if (ps[0] != '"') {
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
            ++p;
            continue;
        }
        if (*p == '\\') {
            escaping = true;
            ++p;
            continue;
        }
        assert(*p != '"');
        *pw = *p;
    }
    // reset len
    ps = ps[0..pw - ps.ptr];
}

private class NeedQuote : RagelParser
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
        return str;

    // Easy parser that just verifies it's a token
    scope parser = new NeedQuote();
    parser.run(str);
    if (!parser.complete || parser.error)
        return str;

    char[] ret;
    // TODO: reserve
    ret ~= '"';

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
        Request = Request_Line ((general_header | request_header | message_header) CRLF)* CRLF %*done;
    
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
        with(_request.requestLine) {
            with(*_request) {
                %% write exec;
            }
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
    void opIndexAssign(char[] fieldName, char[] fieldValue)
    {
        // TODO: set the header
    }
    
    Request* _request;
    bool _headerHandled;
    string _fieldName;
    IStringSet _list;
    string* _string;
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
        Response = Status_Line ((general_header | response_header | message_header) CRLF)* CRLF %*done;
    
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
        with(_response.status) {
            with(*_response) {
                %% write exec;
            }
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
    void opIndexAssign(char[] fieldName, char[] fieldValue)
    {
        // TODO: set the header
    }
    
    Response* _response;
    bool _headerHandled;
    string _fieldName;
    IStringSet _list;
    string* _string;
    static Logger _log;
}
