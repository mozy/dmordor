%%{

    machine http_parser;

    action mark { mark = fpc; }
    action done { fbreak; }

    # basic character types
    OCTET = any;
    CHAR = ascii;
    UPALPHA = "A".."Z";
    LOALPHA = "a".."z";
    ALPHA = alpha;
    DIGIT = digit;
    CTL = cntrl | 127;
    CR = "\r";
    LF = "\n";
    SP = " ";
    HT = "\t";

    # almost-basic character types
    # note that we allow a single LF for a CR LF
    CRLF = CR LF | LF;
    LWS = CRLF? ( SP | HT )+;
    TEXT = LWS | (OCTET -- CTL);
    HEX = xdigit;

    # some basic tokens
    separators = "(" | ")" | "<" | ">" | "@" | "," | ";" | ":" | "\\" | "\"" | "/" | "[" | "]" | "?" | "=" | "{" | "}" | SP | HT;
    token = (CHAR -- (separators | CTL))+;
    quoted_pair = "\\" CHAR;
    ctext = TEXT -- ("(" | ")");
    base_comment = "(" ( ctext | quoted_pair )* ")";
    comment = "(" ( ctext | quoted_pair | base_comment )* ")";
    qdtext = TEXT -- "\"";
    quoted_string = "\"" ( qdtext | quoted_pair )* "\"";

    action parse_HTTP_Version {
        _log.trace("Parsing HTTP version '{}'", mark[0..fpc - mark]);
        ver = Version.fromString(mark[0..fpc - mark]);
        mark = null;
    }

    HTTP_Version = ("HTTP/" DIGIT+ "." DIGIT+) >mark %parse_HTTP_Version;

    delta_seconds = DIGIT+;

    product_version = token;
    product = token ("/" product_version)?;

    qvalue = ("0" ("." DIGIT{0,3})) | ("1" ("." "0"{0,3}));

    subtag = ALPHA{1,8};
    primary_tag = ALPHA{1,8};
    language_tag = primary_tag ("-" subtag);

    weak = "W/";
    opaque_tag = quoted_string;
    entity_tag = (weak)? opaque_tag;  

    bytes_unit = "bytes";
    other_range_unit = token;
    range_unit = bytes_unit | other_range_unit;

    action save_field_name {
        _temp1 = mark[0..fpc - mark];
        mark = null;
    }
    action save_field_value {
        if (_headerHandled) {
            _headerHandled = false;
        } else {
            char[] fieldValue = mark[0..fpc - mark];
            unfold(fieldValue);
            string* value = _temp1 in extension;
            if (value is null) {
                extension[_temp1] = fieldValue;
            } else {
                *value ~= ", " ~ fieldValue;
            }
            //    fgoto *http_request_parser_error;
            mark = null;
        }
    }

    field_chars = OCTET -- (CTL | CR LF SP HT);
    field_name = token >mark %save_field_name;
    field_value = TEXT* >mark %save_field_value;
    message_header = field_name ":" field_value;
    
    action save_string {
        *_string = mark[0..fpc - mark];
        mark = null;
    }
    action save_ulong {
        *_ulong = to!(ulong)(mark[0..fpc - mark]);
        mark = null;
    }
    
    action save_element {
        _list.insert(mark[0..fpc-mark]);
        mark = null;
    }
    action save_element_eof {
        _list.insert(mark[0..pe-mark]);
        mark = null;
    }
    element = token >mark %save_element %/save_element_eof;
    list = LWS* element ( LWS* ',' LWS* element)* LWS*;
    
    action save_parameterized_list_element {
        _parameterizedList.length = _parameterizedList.length + 1;
        (*_parameterizedList)[$-1].value = mark[0..fpc - mark];
        mark = null;
    }
    
    action save_parameterized_list_attribute {
        _temp1 = mark[0..fpc - mark];
        mark = null;
    }
    
    action save_parameterized_list_value {
        (*_parameterizedList)[$-1].parameters[_temp1] = mark[0..fpc - mark];
        mark = null;
    }
    
    attribute = token;
    value = token | quoted_string;
    parameter = attribute >mark %save_parameterized_list_attribute '=' value >mark %save_parameterized_list_value;
    parameterizedListElement = token >mark %save_parameterized_list_element (';' parameter)*;
    parameterizedList = LWS* parameterizedListElement ( LWS* ',' LWS* parameterizedListElement)* LWS*;
    
    action set_connection {
        if (general.connection is null) {
            general.connection = new StringSet();
        }
        _headerHandled = true;
        _list = general.connection;
    }
    
    action set_transfer_encoding {
        _headerHandled = true;
        _parameterizedList = &general.transferEncoding;
    }

    Connection = 'Connection:' @set_connection list;
    Transfer_Encoding = 'Transfer-Encoding:' @set_transfer_encoding parameterizedList;
    
    general_header = Connection | Transfer_Encoding;
    
    action set_content_length {
        _headerHandled = true;
        _ulong = &contentLength;
    }
    
    Content_Length = 'Content-Length:' @set_content_length LWS* DIGIT+ >mark %save_ulong LWS*;
    
    extension_header = message_header;

    entity_header = Content_Length | extension_header;

}%%
