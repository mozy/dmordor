#line 1 "parser.rl"
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

#line 89 "parser.d"
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

#line 91 "parser.rl"

public:
    void init() {
        super.init();
        
#line 131 "parser.d"
	{
	cs = need_quote_start;
	}
#line 96 "parser.rl"
    }
    bool complete() {
        return cs >= need_quote_first_final;
    }
    bool error() {
        return cs == need_quote_error;
    }
protected:
    void exec() {
        
#line 146 "parser.d"
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
#line 106 "parser.rl"
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
    
#line 257 "parser.d"
static const byte[] _http_request_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 1, 
	7, 1, 9, 1, 10, 2, 0, 4, 
	2, 5, 4, 2, 6, 4, 2, 8, 
	3, 2, 11, 3
];

static const short[] _http_request_parser_key_offsets = [
	0, 0, 15, 31, 44, 58, 59, 60, 
	61, 62, 63, 65, 68, 70, 74, 93, 
	94, 110, 117, 124, 145, 162, 179, 196, 
	213, 230, 247, 264, 281, 298, 314, 336, 
	358, 379, 396, 413, 430, 446, 459, 472, 
	493, 494, 509, 510, 524, 539, 552, 568, 
	582, 596, 605, 618, 633, 646, 661, 674, 
	690, 691, 712, 720, 741, 742, 743, 749, 
	755, 767, 773, 779, 799
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
	48u, 57u, 10u, 13u, 33u, 67u, 72u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 10u, 33u, 58u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 10u, 13u, 127u, 
	0u, 8u, 11u, 31u, 9u, 10u, 13u, 32u, 
	33u, 67u, 72u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 111u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 110u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 110u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 101u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 99u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	116u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 105u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 111u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 110u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 9u, 10u, 13u, 32u, 33u, 124u, 
	126u, 127u, 0u, 31u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	9u, 10u, 13u, 32u, 33u, 124u, 126u, 127u, 
	0u, 31u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 9u, 10u, 
	13u, 32u, 33u, 67u, 72u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 111u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 115u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 116u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 9u, 10u, 
	13u, 32u, 127u, 0u, 31u, 48u, 57u, 65u, 
	90u, 97u, 122u, 9u, 10u, 13u, 32u, 127u, 
	0u, 31u, 48u, 57u, 65u, 90u, 97u, 122u, 
	9u, 10u, 13u, 32u, 33u, 67u, 72u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 10u, 10u, 13u, 
	45u, 46u, 127u, 0u, 8u, 11u, 31u, 48u, 
	57u, 65u, 90u, 97u, 122u, 10u, 10u, 13u, 
	45u, 127u, 0u, 8u, 11u, 31u, 48u, 57u, 
	65u, 90u, 97u, 122u, 10u, 13u, 45u, 46u, 
	127u, 0u, 8u, 11u, 31u, 48u, 57u, 65u, 
	90u, 97u, 122u, 10u, 13u, 127u, 0u, 8u, 
	11u, 31u, 48u, 57u, 65u, 90u, 97u, 122u, 
	9u, 10u, 13u, 32u, 45u, 46u, 58u, 127u, 
	0u, 31u, 48u, 57u, 65u, 90u, 97u, 122u, 
	10u, 13u, 45u, 127u, 0u, 8u, 11u, 31u, 
	48u, 57u, 65u, 90u, 97u, 122u, 9u, 10u, 
	13u, 32u, 58u, 127u, 0u, 31u, 48u, 57u, 
	65u, 90u, 97u, 122u, 9u, 10u, 13u, 32u, 
	127u, 0u, 31u, 48u, 57u, 10u, 13u, 127u, 
	0u, 8u, 11u, 31u, 48u, 57u, 65u, 90u, 
	97u, 122u, 10u, 13u, 45u, 46u, 127u, 0u, 
	8u, 11u, 31u, 48u, 57u, 65u, 90u, 97u, 
	122u, 10u, 13u, 127u, 0u, 8u, 11u, 31u, 
	48u, 57u, 65u, 90u, 97u, 122u, 10u, 13u, 
	45u, 46u, 127u, 0u, 8u, 11u, 31u, 48u, 
	57u, 65u, 90u, 97u, 122u, 10u, 13u, 127u, 
	0u, 8u, 11u, 31u, 48u, 57u, 65u, 90u, 
	97u, 122u, 9u, 10u, 13u, 32u, 45u, 46u, 
	58u, 127u, 0u, 31u, 48u, 57u, 65u, 90u, 
	97u, 122u, 10u, 9u, 10u, 13u, 32u, 33u, 
	44u, 124u, 126u, 127u, 0u, 31u, 35u, 39u, 
	42u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	9u, 10u, 13u, 32u, 44u, 127u, 0u, 31u, 
	9u, 10u, 13u, 32u, 33u, 67u, 72u, 124u, 
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
	1, 1, 0, 1, 0, 2, 7, 1, 
	4, 3, 3, 9, 5, 5, 5, 5, 
	5, 5, 5, 5, 5, 4, 8, 8, 
	9, 5, 5, 5, 4, 5, 5, 9, 
	1, 5, 1, 4, 5, 3, 8, 4, 
	6, 5, 3, 5, 3, 5, 3, 8, 
	1, 9, 6, 9, 1, 1, 0, 0, 
	6, 0, 0, 10, 0
];

static const byte[] _http_request_parser_range_lengths = [
	0, 6, 6, 3, 4, 0, 0, 0, 
	0, 0, 1, 1, 1, 1, 6, 0, 
	6, 2, 2, 6, 6, 6, 6, 6, 
	6, 6, 6, 6, 6, 6, 7, 7, 
	6, 6, 6, 6, 6, 4, 4, 6, 
	0, 5, 0, 5, 5, 5, 4, 5, 
	4, 2, 5, 5, 5, 5, 5, 4, 
	0, 6, 1, 6, 0, 0, 3, 3, 
	3, 3, 3, 5, 0
];

static const short[] _http_request_parser_index_offsets = [
	0, 0, 10, 21, 32, 43, 45, 47, 
	49, 51, 53, 55, 58, 60, 64, 78, 
	80, 91, 97, 103, 119, 131, 143, 155, 
	167, 179, 191, 203, 215, 227, 238, 254, 
	270, 286, 298, 310, 322, 333, 343, 353, 
	369, 371, 382, 384, 394, 405, 414, 427, 
	437, 448, 456, 465, 476, 485, 496, 505, 
	518, 520, 536, 544, 560, 562, 564, 568, 
	572, 582, 586, 590, 606
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
	21, 22, 23, 24, 25, 23, 23, 23, 
	23, 23, 23, 23, 23, 1, 21, 1, 
	26, 27, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 29, 30, 1, 1, 1, 
	28, 32, 33, 1, 1, 1, 31, 31, 
	21, 22, 31, 23, 24, 25, 23, 23, 
	23, 23, 23, 23, 23, 23, 1, 26, 
	27, 34, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 35, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 36, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 37, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 38, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 39, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 40, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 41, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 42, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 43, 26, 26, 26, 
	26, 26, 26, 26, 26, 1, 44, 45, 
	46, 44, 47, 47, 47, 1, 1, 47, 
	47, 47, 47, 47, 47, 28, 48, 49, 
	50, 48, 47, 47, 47, 1, 1, 47, 
	47, 47, 47, 47, 47, 31, 48, 21, 
	22, 48, 23, 24, 25, 23, 23, 23, 
	23, 23, 23, 23, 23, 1, 26, 27, 
	51, 26, 26, 26, 26, 26, 26, 26, 
	26, 1, 26, 27, 52, 26, 26, 26, 
	26, 26, 26, 26, 26, 1, 26, 27, 
	53, 26, 26, 26, 26, 26, 26, 26, 
	26, 1, 26, 54, 26, 26, 26, 26, 
	26, 26, 26, 26, 1, 55, 56, 57, 
	55, 1, 1, 58, 59, 59, 28, 60, 
	61, 62, 60, 1, 1, 58, 59, 59, 
	31, 60, 21, 22, 60, 23, 24, 25, 
	23, 23, 23, 23, 23, 23, 23, 23, 
	1, 63, 1, 32, 33, 64, 65, 1, 
	1, 1, 66, 67, 67, 31, 68, 1, 
	32, 33, 64, 1, 1, 1, 67, 67, 
	67, 31, 32, 33, 64, 69, 1, 1, 
	1, 67, 67, 67, 31, 32, 33, 1, 
	1, 1, 67, 70, 70, 31, 71, 72, 
	73, 71, 74, 75, 76, 1, 1, 70, 
	70, 70, 31, 32, 33, 74, 1, 1, 
	1, 70, 70, 70, 31, 71, 72, 73, 
	71, 76, 1, 1, 67, 70, 70, 31, 
	71, 72, 73, 71, 1, 1, 76, 31, 
	32, 33, 1, 1, 1, 77, 70, 70, 
	31, 32, 33, 64, 78, 1, 1, 1, 
	77, 67, 67, 31, 32, 33, 1, 1, 
	1, 79, 70, 70, 31, 32, 33, 64, 
	80, 1, 1, 1, 79, 67, 67, 31, 
	32, 33, 1, 1, 1, 81, 70, 70, 
	31, 71, 72, 73, 71, 64, 69, 76, 
	1, 1, 81, 67, 67, 31, 82, 1, 
	83, 84, 85, 83, 86, 87, 86, 86, 
	1, 1, 86, 86, 86, 86, 86, 31, 
	88, 89, 90, 88, 48, 1, 1, 31, 
	88, 21, 22, 88, 23, 24, 25, 23, 
	23, 23, 23, 23, 23, 23, 23, 1, 
	91, 1, 92, 1, 93, 93, 93, 1, 
	9, 9, 9, 1, 8, 94, 95, 94, 
	94, 94, 94, 94, 94, 1, 96, 96, 
	96, 1, 94, 94, 94, 1, 8, 9, 
	10, 97, 94, 9, 9, 9, 9, 9, 
	9, 97, 97, 97, 97, 1, 1, 0
];

static const byte[] _http_request_parser_trans_targs = [
	2, 0, 3, 2, 4, 62, 64, 67, 
	5, 4, 62, 6, 7, 8, 9, 10, 
	11, 12, 13, 14, 61, 68, 15, 16, 
	20, 33, 16, 17, 18, 19, 42, 18, 
	19, 42, 21, 22, 23, 24, 25, 26, 
	27, 28, 29, 30, 31, 32, 56, 57, 
	31, 32, 56, 34, 35, 36, 37, 38, 
	39, 40, 41, 46, 38, 39, 40, 39, 
	43, 50, 41, 44, 19, 45, 46, 18, 
	19, 42, 47, 48, 49, 51, 52, 53, 
	54, 55, 32, 58, 59, 60, 57, 31, 
	58, 59, 60, 59, 14, 63, 64, 65, 
	66, 67
];

static const byte[] _http_request_parser_trans_actions = [
	1, 0, 17, 0, 1, 1, 1, 1, 
	19, 0, 0, 1, 0, 0, 0, 0, 
	0, 0, 0, 5, 5, 0, 0, 1, 
	1, 1, 0, 7, 1, 21, 21, 0, 
	9, 9, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 30, 1, 21, 21, 1, 
	0, 9, 9, 0, 0, 0, 33, 1, 
	21, 21, 1, 1, 0, 9, 9, 0, 
	0, 0, 0, 0, 0, 0, 0, 11, 
	24, 24, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 13, 27, 27, 0, 13, 
	0, 9, 9, 0, 0, 0, 0, 0, 
	0, 0
];

static const byte[] _http_request_parser_from_state_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 3
];

static const byte[] _http_request_parser_eof_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 15, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0
];

static const int http_request_parser_start = 1;
static const int http_request_parser_first_final = 68;
static const int http_request_parser_error = 0;

static const int http_request_parser_en_main = 1;

#line 179 "parser.rl"


public:
    void init()
    {
        super.init();
        
#line 566 "parser.d"
	{
	cs = http_request_parser_start;
	}
#line 186 "parser.rl"
    }

protected:
    void exec()
    {
        with(_request.requestLine) {
            with(*_request) {
                
#line 579 "parser.d"
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
#line 600 "parser.d"
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
        if (_headerHandled) {
            _headerHandled = false;
        } else {
            char[] fieldValue = mark[0..p - mark];
            unfold(fieldValue);
            this[_fieldName] = fieldValue;
            //    fgoto *http_request_parser_error;
            mark = null;
        }
    }
	break;
	case 5:
#line 86 "parser.rl"
	{
        *_string = mark[0..p - mark];
        mark = null;
    }
	break;
	case 6:
#line 91 "parser.rl"
	{
        _list.insert(mark[0..p-mark]);
        mark = null;
    }
	break;
	case 8:
#line 102 "parser.rl"
	{
        if (general.connection is null) {
            general.connection = new RedBlackTree!(string)();
        }
        _headerHandled = true;
        _list = general.connection;
    }
	break;
	case 9:
#line 151 "parser.rl"
	{
            requestLine.method =
                parseHttpMethod(mark[0..p - mark]);
            mark = null;
        }
	break;
	case 10:
#line 157 "parser.rl"
	{
            requestLine.uri = mark[0..p - mark];
            mark = null;
        }
	break;
	case 11:
#line 162 "parser.rl"
	{
            _headerHandled = true;
            _string = &request.host;
        }
	break;
#line 745 "parser.d"
		default: break;
		}
	}

_again:
	if ( cs == 0 )
		goto _out;
	if ( ++p != pe )
		goto _resume;
	_test_eof: {}
	if ( p == eof )
	{
	byte* __acts = &_http_request_parser_actions[_http_request_parser_eof_actions[cs]];
	uint __nacts = cast(uint) *__acts++;
	while ( __nacts-- > 0 ) {
		switch ( *__acts++ ) {
	case 7:
#line 95 "parser.rl"
	{
        _list.insert(mark[0..pe-mark]);
        mark = null;
    }
	break;
#line 769 "parser.d"
		default: break;
		}
	}
	}

	_out: {}
	}
#line 194 "parser.rl"
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
    
#line 815 "parser.d"
static const byte[] _http_response_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 1, 
	7, 1, 9, 1, 10, 2, 0, 4, 
	2, 0, 10, 2, 5, 4, 2, 6, 
	4, 2, 8, 3, 2, 11, 3
];

static const short[] _http_response_parser_key_offsets = [
	0, 0, 1, 2, 3, 4, 5, 7, 
	10, 12, 15, 17, 19, 21, 22, 29, 
	36, 55, 56, 72, 79, 86, 107, 124, 
	141, 158, 175, 192, 209, 226, 243, 260, 
	276, 298, 320, 341, 358, 375, 392, 409, 
	426, 443, 460, 476, 487, 498, 519, 520, 
	537, 538, 556, 574, 587, 600, 601, 622, 
	630, 651, 652, 653
];

static const char[] _http_response_parser_trans_keys = [
	72u, 84u, 84u, 80u, 47u, 48u, 57u, 46u, 
	48u, 57u, 48u, 57u, 32u, 48u, 57u, 48u, 
	57u, 48u, 57u, 48u, 57u, 32u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 10u, 13u, 127u, 
	0u, 8u, 11u, 31u, 10u, 13u, 33u, 67u, 
	76u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 10u, 
	33u, 58u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	10u, 13u, 127u, 0u, 8u, 11u, 31u, 10u, 
	13u, 127u, 0u, 8u, 11u, 31u, 9u, 10u, 
	13u, 32u, 33u, 67u, 76u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 111u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 110u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 110u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	101u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 99u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 116u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 105u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 111u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 110u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 9u, 10u, 13u, 32u, 
	33u, 124u, 126u, 127u, 0u, 31u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 9u, 10u, 13u, 32u, 33u, 124u, 
	126u, 127u, 0u, 31u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	9u, 10u, 13u, 32u, 33u, 67u, 76u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 111u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	99u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 97u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 116u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 105u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 111u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 110u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 9u, 10u, 13u, 32u, 
	127u, 0u, 31u, 65u, 90u, 97u, 122u, 9u, 
	10u, 13u, 32u, 127u, 0u, 31u, 65u, 90u, 
	97u, 122u, 9u, 10u, 13u, 32u, 33u, 67u, 
	76u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 10u, 
	10u, 13u, 43u, 58u, 127u, 0u, 8u, 11u, 
	31u, 45u, 46u, 48u, 57u, 65u, 90u, 97u, 
	122u, 10u, 10u, 13u, 33u, 37u, 61u, 95u, 
	126u, 127u, 0u, 8u, 11u, 31u, 36u, 59u, 
	63u, 90u, 97u, 122u, 9u, 10u, 13u, 32u, 
	33u, 37u, 61u, 95u, 126u, 127u, 0u, 31u, 
	36u, 59u, 63u, 90u, 97u, 122u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 48u, 57u, 65u, 
	70u, 97u, 102u, 10u, 13u, 127u, 0u, 8u, 
	11u, 31u, 48u, 57u, 65u, 70u, 97u, 102u, 
	10u, 9u, 10u, 13u, 32u, 33u, 44u, 124u, 
	126u, 127u, 0u, 31u, 35u, 39u, 42u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 9u, 10u, 
	13u, 32u, 44u, 127u, 0u, 31u, 9u, 10u, 
	13u, 32u, 33u, 67u, 76u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 10u, 10u, 0
];

static const byte[] _http_response_parser_single_lengths = [
	0, 1, 1, 1, 1, 1, 0, 1, 
	0, 1, 0, 0, 0, 1, 3, 3, 
	7, 1, 4, 3, 3, 9, 5, 5, 
	5, 5, 5, 5, 5, 5, 5, 4, 
	8, 8, 9, 5, 5, 5, 5, 5, 
	5, 5, 4, 5, 5, 9, 1, 5, 
	1, 8, 10, 3, 3, 1, 9, 6, 
	9, 1, 1, 0
];

static const byte[] _http_response_parser_range_lengths = [
	0, 0, 0, 0, 0, 0, 1, 1, 
	1, 1, 1, 1, 1, 0, 2, 2, 
	6, 0, 6, 2, 2, 6, 6, 6, 
	6, 6, 6, 6, 6, 6, 6, 6, 
	7, 7, 6, 6, 6, 6, 6, 6, 
	6, 6, 6, 3, 3, 6, 0, 6, 
	0, 5, 4, 5, 5, 0, 6, 1, 
	6, 0, 0, 0
];

static const short[] _http_response_parser_index_offsets = [
	0, 0, 2, 4, 6, 8, 10, 12, 
	15, 17, 20, 22, 24, 26, 28, 34, 
	40, 54, 56, 67, 73, 79, 95, 107, 
	119, 131, 143, 155, 167, 179, 191, 203, 
	214, 230, 246, 262, 274, 286, 298, 310, 
	322, 334, 346, 357, 366, 375, 391, 393, 
	405, 407, 421, 436, 445, 454, 456, 472, 
	480, 496, 498, 500
];

static const byte[] _http_response_parser_indicies = [
	0, 1, 2, 1, 3, 1, 4, 1, 
	5, 1, 6, 1, 7, 6, 1, 8, 
	1, 9, 8, 1, 10, 1, 11, 1, 
	12, 1, 13, 1, 15, 16, 1, 1, 
	1, 14, 18, 19, 1, 1, 1, 17, 
	20, 21, 22, 23, 24, 22, 22, 22, 
	22, 22, 22, 22, 22, 1, 20, 1, 
	25, 26, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 28, 29, 1, 1, 1, 
	27, 31, 32, 1, 1, 1, 30, 30, 
	20, 21, 30, 22, 23, 24, 22, 22, 
	22, 22, 22, 22, 22, 22, 1, 25, 
	26, 33, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 34, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 35, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 36, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 37, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 38, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 39, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 40, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 41, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 42, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 43, 44, 
	45, 43, 46, 46, 46, 1, 1, 46, 
	46, 46, 46, 46, 46, 27, 47, 48, 
	49, 47, 46, 46, 46, 1, 1, 46, 
	46, 46, 46, 46, 46, 30, 47, 20, 
	21, 47, 22, 23, 24, 22, 22, 22, 
	22, 22, 22, 22, 22, 1, 25, 26, 
	50, 25, 25, 25, 25, 25, 25, 25, 
	25, 1, 25, 26, 51, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 25, 26, 
	52, 25, 25, 25, 25, 25, 25, 25, 
	25, 1, 25, 26, 53, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 25, 26, 
	54, 25, 25, 25, 25, 25, 25, 25, 
	25, 1, 25, 26, 55, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 25, 26, 
	56, 25, 25, 25, 25, 25, 25, 25, 
	25, 1, 25, 57, 25, 25, 25, 25, 
	25, 25, 25, 25, 1, 58, 59, 60, 
	58, 1, 1, 61, 61, 27, 62, 63, 
	64, 62, 1, 1, 61, 61, 30, 62, 
	20, 21, 62, 22, 23, 24, 22, 22, 
	22, 22, 22, 22, 22, 22, 1, 65, 
	1, 31, 32, 66, 67, 1, 1, 1, 
	66, 66, 66, 66, 30, 68, 1, 31, 
	32, 69, 70, 69, 69, 69, 1, 1, 
	1, 69, 69, 69, 30, 71, 72, 73, 
	71, 69, 70, 69, 69, 69, 1, 1, 
	69, 69, 69, 30, 31, 32, 1, 1, 
	1, 74, 74, 74, 30, 31, 32, 1, 
	1, 1, 69, 69, 69, 30, 75, 1, 
	76, 77, 78, 76, 79, 80, 79, 79, 
	1, 1, 79, 79, 79, 79, 79, 30, 
	81, 82, 83, 81, 47, 1, 1, 30, 
	81, 20, 21, 81, 22, 23, 24, 22, 
	22, 22, 22, 22, 22, 22, 22, 1, 
	84, 1, 85, 1, 1, 0
];

static const byte[] _http_response_parser_trans_targs = [
	2, 0, 3, 4, 5, 6, 7, 8, 
	9, 10, 11, 12, 13, 14, 15, 16, 
	58, 15, 16, 58, 59, 17, 18, 22, 
	35, 18, 19, 20, 21, 48, 20, 21, 
	48, 23, 24, 25, 26, 27, 28, 29, 
	30, 31, 32, 33, 34, 53, 54, 33, 
	34, 53, 36, 37, 38, 39, 40, 41, 
	42, 43, 44, 45, 46, 47, 44, 45, 
	46, 45, 47, 49, 21, 50, 51, 20, 
	21, 48, 52, 34, 55, 56, 57, 54, 
	33, 55, 56, 57, 56, 16
];

static const byte[] _http_response_parser_trans_actions = [
	1, 0, 0, 0, 0, 0, 0, 0, 
	0, 5, 1, 0, 0, 17, 1, 24, 
	24, 0, 19, 19, 0, 0, 1, 1, 
	1, 0, 7, 1, 21, 21, 0, 9, 
	9, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 33, 1, 21, 21, 1, 0, 
	9, 9, 0, 0, 0, 0, 0, 0, 
	0, 36, 1, 21, 21, 1, 0, 9, 
	9, 0, 0, 0, 0, 0, 0, 11, 
	27, 27, 0, 0, 13, 30, 30, 0, 
	13, 0, 9, 9, 0, 0
];

static const byte[] _http_response_parser_from_state_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 3
];

static const byte[] _http_response_parser_eof_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 15, 0, 
	0, 0, 0, 0
];

static const int http_response_parser_start = 1;
static const int http_response_parser_first_final = 59;
static const int http_response_parser_error = 0;

static const int http_response_parser_en_main = 1;

#line 261 "parser.rl"


public:
    void init()
    {
        super.init();
        
#line 1083 "parser.d"
	{
	cs = http_response_parser_start;
	}
#line 268 "parser.rl"
    }

protected:
    void exec()
    {
        with(_response.status) {
            with(*_response) {
                
#line 1096 "parser.d"
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
#line 1117 "parser.d"
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
        if (_headerHandled) {
            _headerHandled = false;
        } else {
            char[] fieldValue = mark[0..p - mark];
            unfold(fieldValue);
            this[_fieldName] = fieldValue;
            //    fgoto *http_request_parser_error;
            mark = null;
        }
    }
	break;
	case 5:
#line 86 "parser.rl"
	{
        *_string = mark[0..p - mark];
        mark = null;
    }
	break;
	case 6:
#line 91 "parser.rl"
	{
        _list.insert(mark[0..p-mark]);
        mark = null;
    }
	break;
	case 8:
#line 102 "parser.rl"
	{
        if (general.connection is null) {
            general.connection = new RedBlackTree!(string)();
        }
        _headerHandled = true;
        _list = general.connection;
    }
	break;
	case 9:
#line 235 "parser.rl"
	{
            status.status = cast(Status)to!(int)(mark[0..p - mark]);
            mark = null;
        }
	break;
	case 10:
#line 240 "parser.rl"
	{
            status.reason = mark[0..p - mark];
            mark = null;
        }
	break;
	case 11:
#line 245 "parser.rl"
	{
            _headerHandled = true;
            _string = &response.location;
        }
	break;
#line 1261 "parser.d"
		default: break;
		}
	}

_again:
	if ( cs == 0 )
		goto _out;
	if ( ++p != pe )
		goto _resume;
	_test_eof: {}
	if ( p == eof )
	{
	byte* __acts = &_http_response_parser_actions[_http_response_parser_eof_actions[cs]];
	uint __nacts = cast(uint) *__acts++;
	while ( __nacts-- > 0 ) {
		switch ( *__acts++ ) {
	case 7:
#line 95 "parser.rl"
	{
        _list.insert(mark[0..pe-mark]);
        mark = null;
    }
	break;
#line 1285 "parser.d"
		default: break;
		}
	}
	}

	_out: {}
	}
#line 276 "parser.rl"
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
