#line 1 "parser.rl"
/* To compile to .d:
   ragel parser.rl -D -o parser.d
*/

module mordor.common.http.parser;

import tango.math.Math;
import tango.text.Util;
import tango.util.Convert;
import tango.util.log.Log;

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

#line 88 "parser.d"
static const byte[] _need_quote_key_offsets = [
	0, 0, 15
];

static const char[] _need_quote_trans_keys = [
	33u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 0
];

static const byte[] _need_quote_single_lengths = [
	0, 3, 3
];

static const byte[] _need_quote_range_lengths = [
	0, 6, 6
];

static const byte[] _need_quote_index_offsets = [
	0, 0, 10
];

static const byte[] _need_quote_trans_targs = [
	2, 2, 2, 2, 2, 2, 2, 2, 
	2, 0, 2, 2, 2, 2, 2, 2, 
	2, 2, 2, 0, 0
];

static const int need_quote_start = 1;
static const int need_quote_first_final = 2;
static const int need_quote_error = 0;

static const int need_quote_en_main = 1;

#line 90 "parser.rl"

public:
    void init() {
        super.init();
        
#line 130 "parser.d"
	{
	cs = need_quote_start;
	}
#line 95 "parser.rl"
    }
    bool complete() {
        return cs >= need_quote_first_final;
    }
    bool error() {
        return cs == need_quote_error;
    }
protected:
    void exec() {
        
#line 145 "parser.d"
	{
	int _klen;
	uint _trans;
	char* _keys;

	if ( p == pe )
		goto _test_eof;
	if ( cs == 0 )
		goto _out;
_resume:
	_keys = &_need_quote_trans_keys[_need_quote_key_offsets[cs]];
	_trans = _need_quote_index_offsets[cs];

	_klen = _need_quote_single_lengths[cs];
	if ( _klen > 0 ) {
		char* _lower = _keys;
		char* _mid;
		char* _upper = _keys + _klen - 1;
		while (1) {
			if ( _upper < _lower )
				break;

			_mid = _lower + ((_upper-_lower) >> 1);
			if ( (*p) < *_mid )
				_upper = _mid - 1;
			else if ( (*p) > *_mid )
				_lower = _mid + 1;
			else {
				_trans += (_mid - _keys);
				goto _match;
			}
		}
		_keys += _klen;
		_trans += _klen;
	}

	_klen = _need_quote_range_lengths[cs];
	if ( _klen > 0 ) {
		char* _lower = _keys;
		char* _mid;
		char* _upper = _keys + (_klen<<1) - 2;
		while (1) {
			if ( _upper < _lower )
				break;

			_mid = _lower + (((_upper-_lower) >> 1) & ~1);
			if ( (*p) < _mid[0] )
				_upper = _mid - 2;
			else if ( (*p) > _mid[1] )
				_lower = _mid + 2;
			else {
				_trans += ((_mid - _keys)>>1);
				goto _match;
			}
		}
		_trans += _klen;
	}

_match:
	cs = _need_quote_trans_targs[_trans];

	if ( cs == 0 )
		goto _out;
	if ( ++p != pe )
		goto _resume;
	_test_eof: {}
	_out: {}
	}
#line 105 "parser.rl"
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
    
#line 256 "parser.d"
static const byte[] _http_request_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 2, 
	4, 0
];

static const ubyte[] _http_request_parser_key_offsets = [
	0, 0, 15, 31, 44, 58, 59, 60, 
	61, 62, 63, 65, 68, 70, 74, 91, 
	92, 108, 115, 122, 141, 142, 143, 149, 
	155, 167, 173, 179, 199
];

static const char[] _http_request_parser_trans_keys = [
	33u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 32u, 
	33u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	37u, 47u, 61u, 64u, 95u, 126u, 36u, 59u, 
	65u, 90u, 97u, 122u, 32u, 33u, 37u, 61u, 
	95u, 126u, 36u, 46u, 48u, 59u, 64u, 90u, 
	97u, 122u, 72u, 84u, 84u, 80u, 47u, 48u, 
	57u, 46u, 48u, 57u, 48u, 57u, 10u, 13u, 
	48u, 57u, 10u, 13u, 33u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 10u, 33u, 58u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 10u, 13u, 127u, 0u, 
	8u, 11u, 31u, 10u, 13u, 127u, 0u, 8u, 
	11u, 31u, 9u, 10u, 13u, 32u, 33u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 10u, 10u, 48u, 
	57u, 65u, 70u, 97u, 102u, 48u, 57u, 65u, 
	70u, 97u, 102u, 32u, 33u, 37u, 61u, 95u, 
	126u, 36u, 59u, 63u, 90u, 97u, 122u, 48u, 
	57u, 65u, 70u, 97u, 102u, 48u, 57u, 65u, 
	70u, 97u, 102u, 32u, 33u, 37u, 43u, 58u, 
	59u, 61u, 64u, 95u, 126u, 36u, 44u, 45u, 
	46u, 48u, 57u, 65u, 90u, 97u, 122u, 0
];

static const byte[] _http_request_parser_single_lengths = [
	0, 3, 4, 7, 6, 1, 1, 1, 
	1, 1, 0, 1, 0, 2, 5, 1, 
	4, 3, 3, 7, 1, 1, 0, 0, 
	6, 0, 0, 10, 0
];

static const byte[] _http_request_parser_range_lengths = [
	0, 6, 6, 3, 4, 0, 0, 0, 
	0, 0, 1, 1, 1, 1, 6, 0, 
	6, 2, 2, 6, 0, 0, 3, 3, 
	3, 3, 3, 5, 0
];

static const ubyte[] _http_request_parser_index_offsets = [
	0, 0, 10, 21, 32, 43, 45, 47, 
	49, 51, 53, 55, 58, 60, 64, 76, 
	78, 89, 95, 101, 115, 117, 119, 123, 
	127, 137, 141, 145, 161
];

static const byte[] _http_request_parser_indicies = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 1, 2, 3, 3, 3, 3, 3, 
	3, 3, 3, 3, 1, 4, 5, 6, 
	4, 4, 4, 4, 4, 7, 7, 1, 
	8, 9, 10, 9, 9, 9, 9, 9, 
	9, 9, 1, 11, 1, 12, 1, 13, 
	1, 14, 1, 15, 1, 16, 1, 17, 
	16, 1, 18, 1, 19, 20, 18, 1, 
	21, 22, 23, 23, 23, 23, 23, 23, 
	23, 23, 23, 1, 21, 1, 24, 25, 
	24, 24, 24, 24, 24, 24, 24, 24, 
	1, 27, 28, 1, 1, 1, 26, 30, 
	31, 1, 1, 1, 29, 29, 32, 33, 
	29, 34, 34, 34, 34, 34, 34, 34, 
	34, 34, 1, 30, 1, 35, 1, 36, 
	36, 36, 1, 9, 9, 9, 1, 8, 
	37, 38, 37, 37, 37, 37, 37, 37, 
	1, 39, 39, 39, 1, 37, 37, 37, 
	1, 8, 9, 10, 40, 37, 9, 9, 
	9, 9, 9, 9, 40, 40, 40, 40, 
	1, 1, 0
];

static const byte[] _http_request_parser_trans_targs = [
	2, 0, 3, 2, 4, 22, 24, 27, 
	5, 4, 22, 6, 7, 8, 9, 10, 
	11, 12, 13, 14, 21, 28, 15, 16, 
	16, 17, 18, 19, 20, 18, 19, 20, 
	28, 15, 16, 14, 23, 24, 25, 26, 
	27
];

static const byte[] _http_request_parser_trans_actions = [
	1, 0, 11, 0, 1, 1, 1, 1, 
	13, 0, 0, 1, 0, 0, 0, 0, 
	0, 0, 0, 5, 5, 0, 0, 1, 
	0, 7, 1, 1, 1, 0, 0, 0, 
	9, 9, 15, 0, 0, 0, 0, 0, 
	0
];

static const byte[] _http_request_parser_from_state_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 3
];

static const int http_request_parser_start = 1;
static const int http_request_parser_first_final = 28;
static const int http_request_parser_error = 0;

static const int http_request_parser_en_main = 1;

#line 168 "parser.rl"


public:
    void init()
    {
        super.init();
        
#line 382 "parser.d"
	{
	cs = http_request_parser_start;
	}
#line 175 "parser.rl"
    }

protected:
    void exec()
    {
        with(_request.requestLine) {
            with(*_request) {
                
#line 395 "parser.d"
	{
	int _klen;
	uint _trans;
	byte* _acts;
	uint _nacts;
	char* _keys;

	if ( p == pe )
		goto _test_eof;
	if ( cs == 0 )
		goto _out;
_resume:
	_acts = &_http_request_parser_actions[_http_request_parser_from_state_actions[cs]];
	_nacts = cast(uint) *_acts++;
	while ( _nacts-- > 0 ) {
		switch ( *_acts++ ) {
	case 1:
#line 6 "parser.rl"
	{ {p++; if (true) goto _out; } }
	break;
#line 416 "parser.d"
		default: break;
		}
	}

	_keys = &_http_request_parser_trans_keys[_http_request_parser_key_offsets[cs]];
	_trans = _http_request_parser_index_offsets[cs];

	_klen = _http_request_parser_single_lengths[cs];
	if ( _klen > 0 ) {
		char* _lower = _keys;
		char* _mid;
		char* _upper = _keys + _klen - 1;
		while (1) {
			if ( _upper < _lower )
				break;

			_mid = _lower + ((_upper-_lower) >> 1);
			if ( (*p) < *_mid )
				_upper = _mid - 1;
			else if ( (*p) > *_mid )
				_lower = _mid + 1;
			else {
				_trans += (_mid - _keys);
				goto _match;
			}
		}
		_keys += _klen;
		_trans += _klen;
	}

	_klen = _http_request_parser_range_lengths[cs];
	if ( _klen > 0 ) {
		char* _lower = _keys;
		char* _mid;
		char* _upper = _keys + (_klen<<1) - 2;
		while (1) {
			if ( _upper < _lower )
				break;

			_mid = _lower + (((_upper-_lower) >> 1) & ~1);
			if ( (*p) < _mid[0] )
				_upper = _mid - 2;
			else if ( (*p) > _mid[1] )
				_lower = _mid + 2;
			else {
				_trans += ((_mid - _keys)>>1);
				goto _match;
			}
		}
		_trans += _klen;
	}

_match:
	_trans = _http_request_parser_indicies[_trans];
	cs = _http_request_parser_trans_targs[_trans];

	if ( _http_request_parser_trans_actions[_trans] == 0 )
		goto _again;

	_acts = &_http_request_parser_actions[_http_request_parser_trans_actions[_trans]];
	_nacts = cast(uint) *_acts++;
	while ( _nacts-- > 0 )
	{
		switch ( *_acts++ )
		{
	case 0:
#line 5 "parser.rl"
	{ mark = p; }
	break;
	case 2:
#line 38 "parser.rl"
	{
        _log.trace("Parsing HTTP version '{}'", mark[0..p - mark]);
        ver = Version.fromString(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 3:
#line 65 "parser.rl"
	{
        _fieldName = mark[0..p - mark];
        mark = null;
    }
	break;
	case 4:
#line 69 "parser.rl"
	{
        char[] fieldValue = mark[0..p - mark];
        unfold(fieldValue);
        this[_fieldName] = fieldValue;
        //    fgoto *http_request_parser_error;
        mark = null;
    }
	break;
	case 5:
#line 150 "parser.rl"
	{
            requestLine.method =
                parseHttpMethod(mark[0..p - mark]);
            mark = null;
        }
	break;
	case 6:
#line 156 "parser.rl"
	{
            requestLine.uri = mark[0..p - mark];
            mark = null;
        }
	break;
#line 526 "parser.d"
		default: break;
		}
	}

_again:
	if ( cs == 0 )
		goto _out;
	if ( ++p != pe )
		goto _resume;
	_test_eof: {}
	_out: {}
	}
#line 183 "parser.rl"
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
    string _fieldName;
    static Logger _log;
}

class ResponseParser : RagelParser
{
    static this()
    {
        _log = Log.lookup("mordor.common.http.parser.response");
    }
private:
    
#line 574 "parser.d"
static const byte[] _http_response_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 2, 
	0, 6, 2, 4, 0
];

static const byte[] _http_response_parser_key_offsets = [
	0, 0, 1, 2, 3, 4, 5, 7, 
	10, 12, 15, 17, 19, 21, 22, 29, 
	36, 53, 54, 70, 77, 84, 103, 104, 
	105
];

static const char[] _http_response_parser_trans_keys = [
	72u, 84u, 84u, 80u, 47u, 48u, 57u, 46u, 
	48u, 57u, 48u, 57u, 32u, 48u, 57u, 48u, 
	57u, 48u, 57u, 48u, 57u, 32u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 10u, 13u, 127u, 
	0u, 8u, 11u, 31u, 10u, 13u, 33u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 10u, 33u, 58u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 10u, 13u, 127u, 
	0u, 8u, 11u, 31u, 9u, 10u, 13u, 32u, 
	33u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 10u, 
	10u, 0
];

static const byte[] _http_response_parser_single_lengths = [
	0, 1, 1, 1, 1, 1, 0, 1, 
	0, 1, 0, 0, 0, 1, 3, 3, 
	5, 1, 4, 3, 3, 7, 1, 1, 
	0
];

static const byte[] _http_response_parser_range_lengths = [
	0, 0, 0, 0, 0, 0, 1, 1, 
	1, 1, 1, 1, 1, 0, 2, 2, 
	6, 0, 6, 2, 2, 6, 0, 0, 
	0
];

static const byte[] _http_response_parser_index_offsets = [
	0, 0, 2, 4, 6, 8, 10, 12, 
	15, 17, 20, 22, 24, 26, 28, 34, 
	40, 52, 54, 65, 71, 77, 91, 93, 
	95
];

static const byte[] _http_response_parser_indicies = [
	0, 1, 2, 1, 3, 1, 4, 1, 
	5, 1, 6, 1, 7, 6, 1, 8, 
	1, 9, 8, 1, 10, 1, 11, 1, 
	12, 1, 13, 1, 15, 16, 1, 1, 
	1, 14, 18, 19, 1, 1, 1, 17, 
	20, 21, 22, 22, 22, 22, 22, 22, 
	22, 22, 22, 1, 20, 1, 23, 24, 
	23, 23, 23, 23, 23, 23, 23, 23, 
	1, 26, 27, 1, 1, 1, 25, 29, 
	30, 1, 1, 1, 28, 28, 31, 32, 
	28, 33, 33, 33, 33, 33, 33, 33, 
	33, 33, 1, 29, 1, 34, 1, 1, 
	0
];

static const byte[] _http_response_parser_trans_targs = [
	2, 0, 3, 4, 5, 6, 7, 8, 
	9, 10, 11, 12, 13, 14, 15, 16, 
	23, 15, 16, 23, 24, 17, 18, 18, 
	19, 20, 21, 22, 20, 21, 22, 24, 
	17, 18, 16
];

static const byte[] _http_response_parser_trans_actions = [
	1, 0, 0, 0, 0, 0, 0, 0, 
	0, 5, 1, 0, 0, 11, 1, 15, 
	15, 0, 13, 13, 0, 0, 1, 0, 
	7, 1, 1, 1, 0, 0, 0, 9, 
	9, 18, 0
];

static const byte[] _http_response_parser_from_state_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	3
];

static const int http_response_parser_start = 1;
static const int http_response_parser_first_final = 24;
static const int http_response_parser_error = 0;

static const int http_response_parser_en_main = 1;

#line 237 "parser.rl"


public:
    void init()
    {
        super.init();
        
#line 679 "parser.d"
	{
	cs = http_response_parser_start;
	}
#line 244 "parser.rl"
    }

protected:
    void exec()
    {
        with(_response.status) {
            with(*_response) {
                
#line 692 "parser.d"
	{
	int _klen;
	uint _trans;
	byte* _acts;
	uint _nacts;
	char* _keys;

	if ( p == pe )
		goto _test_eof;
	if ( cs == 0 )
		goto _out;
_resume:
	_acts = &_http_response_parser_actions[_http_response_parser_from_state_actions[cs]];
	_nacts = cast(uint) *_acts++;
	while ( _nacts-- > 0 ) {
		switch ( *_acts++ ) {
	case 1:
#line 6 "parser.rl"
	{ {p++; if (true) goto _out; } }
	break;
#line 713 "parser.d"
		default: break;
		}
	}

	_keys = &_http_response_parser_trans_keys[_http_response_parser_key_offsets[cs]];
	_trans = _http_response_parser_index_offsets[cs];

	_klen = _http_response_parser_single_lengths[cs];
	if ( _klen > 0 ) {
		char* _lower = _keys;
		char* _mid;
		char* _upper = _keys + _klen - 1;
		while (1) {
			if ( _upper < _lower )
				break;

			_mid = _lower + ((_upper-_lower) >> 1);
			if ( (*p) < *_mid )
				_upper = _mid - 1;
			else if ( (*p) > *_mid )
				_lower = _mid + 1;
			else {
				_trans += (_mid - _keys);
				goto _match;
			}
		}
		_keys += _klen;
		_trans += _klen;
	}

	_klen = _http_response_parser_range_lengths[cs];
	if ( _klen > 0 ) {
		char* _lower = _keys;
		char* _mid;
		char* _upper = _keys + (_klen<<1) - 2;
		while (1) {
			if ( _upper < _lower )
				break;

			_mid = _lower + (((_upper-_lower) >> 1) & ~1);
			if ( (*p) < _mid[0] )
				_upper = _mid - 2;
			else if ( (*p) > _mid[1] )
				_lower = _mid + 2;
			else {
				_trans += ((_mid - _keys)>>1);
				goto _match;
			}
		}
		_trans += _klen;
	}

_match:
	_trans = _http_response_parser_indicies[_trans];
	cs = _http_response_parser_trans_targs[_trans];

	if ( _http_response_parser_trans_actions[_trans] == 0 )
		goto _again;

	_acts = &_http_response_parser_actions[_http_response_parser_trans_actions[_trans]];
	_nacts = cast(uint) *_acts++;
	while ( _nacts-- > 0 )
	{
		switch ( *_acts++ )
		{
	case 0:
#line 5 "parser.rl"
	{ mark = p; }
	break;
	case 2:
#line 38 "parser.rl"
	{
        _log.trace("Parsing HTTP version '{}'", mark[0..p - mark]);
        ver = Version.fromString(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 3:
#line 65 "parser.rl"
	{
        _fieldName = mark[0..p - mark];
        mark = null;
    }
	break;
	case 4:
#line 69 "parser.rl"
	{
        char[] fieldValue = mark[0..p - mark];
        unfold(fieldValue);
        this[_fieldName] = fieldValue;
        //    fgoto *http_request_parser_error;
        mark = null;
    }
	break;
	case 5:
#line 220 "parser.rl"
	{
            status.status = cast(Status)to!(int)(mark[0..p - mark]);
            mark = null;
        }
	break;
	case 6:
#line 225 "parser.rl"
	{
            status.reason = mark[0..p - mark];
            mark = null;
        }
	break;
#line 822 "parser.d"
		default: break;
		}
	}

_again:
	if ( cs == 0 )
		goto _out;
	if ( ++p != pe )
		goto _resume;
	_test_eof: {}
	_out: {}
	}
#line 252 "parser.rl"
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
    string _fieldName;
    static Logger _log;
}
