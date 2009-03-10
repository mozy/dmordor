module mordor.common.stringutils;

alias char[] string;

ubyte[] hexstringToData(string str)
in
{
    assert(str.length % 2 == 0);
    assert(isHexString(str));
}
out (result)
{
    assert(result.length == str.length / 2);
}
body
{
    ubyte[] result;
    result.length = str.length / 2;
    
    static ubyte hexToBin(char c) {
        if (c >= 'a' && c <= 'f')
            return 0xa + c - 'a';
        if (c >= 'A' && c <= 'F')
            return 0xa + c - 'A';
        return c - '0';        
    }

    for (size_t i = 0, j = 0; i < result.length; ++i) {
        result[i] = (hexToBin(str[j++]) << 4);
        result[i] |= hexToBin(str[j++]);
    }
    
    return result;
}

char[] dataToHexstring(void[] data)
out (result)
{
    assert(result.length == data.length * 2);
    assert(isHexString(result));
}
body
{
    char[] result;
    result.length = data.length * 2;
    
    static char[] hex = "0123456789abcdef";
    size_t i = 0;
    foreach(b; cast(ubyte[])data) {
        result[i++] = hex[b >> 4];
        result[i++] = hex[b & 0xf];
    }
    return result;
}

bool isHexString(string str)
{
    foreach(c; str) {
        if ( !((c >= 'a' && c <= 'f') ||
               (c >= 'A' && c <= 'F') ||
               (c >= '0' && c <= '9'))) {
            return false;
        }
    }
    return true;
}
