module mordor.common.http.uri;

import tango.text.Util;

import mordor.common.stringutils;

private const string unreserved = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
private const string sub_delims = "!$&'()*+,;=";
private const string pchar = unreserved ~ sub_delims ~ ":@";
private const string path = pchar ~ "/";
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
    const string hexdigits = "0123456789abcdef";
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

string escapePath(string str)
{
    return escape(str, path);
}

string escapeQueryString(string str)
{
    return escape(str, query);
}
