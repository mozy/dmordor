#include "pch.h"

#include "uri_parser.h"

#include "uri.h"

%%{

    machine uri_parser;

    alphanum = alpha | digit;
    hex = xdigit;

    reserved = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | ",";
    mark = "-" | "_" | "." | "!" | "~" | "*" | "'" | "(" | ")";
    unreserved = alphanum | mark;
    escaped = "%" hex hex;
    uric = reserved | unreserved | escaped;
    uric_no_slash = uric -- "/";
    delims = "<" | ">" | "#" | "%" | "\"";
    unwise = "{" | "}" | "|" | "\\" | "^" | "[" | "]" | "`";
    pchar = unreserved | escaped | ":" | "@" | "&" | "=" | "+" | "$" | ",";

    scheme = alpha ( alphanum | "+" | "-" | "." )*;

    userinfo = (unreserved | escaped | ";" | ":" | "&" | "=" | "+" | "$" | ",")*;
    domainlabel = alphanum | (alphanum (alphanum | "-")* alphanum);
    toplabel = alpha | (alpha (alphanum | "-")* alphanum);
    hostname = (domainlabel ".")* toplabel (".")?;
    IPv4Address = digit+ "." digit+ "." digit+ "." digit+;
    host = hostname | IPv4Address;
    port = digit*;
    hostport = host (":" port)?;
    server = (userinfo "@" )? hostport;
    reg_name = ( unreserved | escaped | "$" | "," | ";" | ":" | "@" | "&" | "=" | "+" )+;
    authority = server | reg_name;

    param = pchar*;
    segment = pchar* (";" param)*;
    path_segments = segment ("/" segment)*;
    abs_path = "/" path_segments;
    net_path = "//" authority (abs_path)?;
    opaque_part = uric_no_slash uric*;
    path = (abs_path | opaque_part)?;
    query = uric*;
    hier_part = ( net_path | abs_path ) ( "?" query )?;
    absoluteURI = scheme ":" (hier_part | opaque_part);
    rel_segment = ( unreserved | escaped | ";" | "@" | "&" | "=" | "+" | "$" | "," )+;
    rel_path = rel_segment (abs_path)?;  
    relativeURI = (net_path | abs_path | rel_path) ("?" query)?;

    fragment = uric*;
    URI_reference = (absoluteURI | relativeURI) ("#" fragment)?;

}%%


%% machine uri_parser_proper;
%% include uri_parser;
%% main := URI_reference;
%% write data;

void
UriParser::init()
{
    %% write init;
}

void
UriParser::exec()
{
    %% write exec;
}

bool
UriParser::complete() const
{
    return cs >= uri_parser_proper_first_final;
}

bool
UriParser::error() const
{
    return cs == uri_parser_proper_error;
}
