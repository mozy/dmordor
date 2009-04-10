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
	7, 1, 8, 1, 11, 1, 12, 2, 
	0, 4, 2, 5, 4, 2, 6, 4, 
	2, 7, 4, 2, 9, 3, 2, 10, 
	3, 2, 13, 3
];

static const short[] _http_request_parser_key_offsets = [
	0, 0, 15, 31, 44, 58, 59, 60, 
	61, 62, 63, 65, 68, 70, 74, 93, 
	94, 110, 117, 124, 145, 162, 179, 197, 
	214, 231, 248, 265, 282, 299, 315, 337, 
	359, 380, 397, 414, 431, 447, 460, 473, 
	494, 495, 510, 511, 525, 540, 553, 569, 
	583, 597, 606, 619, 634, 647, 662, 675, 
	691, 692, 713, 721, 742, 743, 760, 777, 
	794, 810, 827, 844, 861, 878, 895, 912, 
	928, 937, 946, 967, 968, 977, 978, 984, 
	990, 1002, 1008, 1014, 1034
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
	90u, 94u, 122u, 33u, 58u, 110u, 116u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 101u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	99u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 116u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 105u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 111u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 110u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 9u, 10u, 13u, 32u, 33u, 
	124u, 126u, 127u, 0u, 31u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 9u, 10u, 13u, 32u, 33u, 124u, 126u, 
	127u, 0u, 31u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 9u, 
	10u, 13u, 32u, 33u, 67u, 72u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 111u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 115u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	116u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 9u, 
	10u, 13u, 32u, 127u, 0u, 31u, 48u, 57u, 
	65u, 90u, 97u, 122u, 9u, 10u, 13u, 32u, 
	127u, 0u, 31u, 48u, 57u, 65u, 90u, 97u, 
	122u, 9u, 10u, 13u, 32u, 33u, 67u, 72u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 10u, 10u, 
	13u, 45u, 46u, 127u, 0u, 8u, 11u, 31u, 
	48u, 57u, 65u, 90u, 97u, 122u, 10u, 10u, 
	13u, 45u, 127u, 0u, 8u, 11u, 31u, 48u, 
	57u, 65u, 90u, 97u, 122u, 10u, 13u, 45u, 
	46u, 127u, 0u, 8u, 11u, 31u, 48u, 57u, 
	65u, 90u, 97u, 122u, 10u, 13u, 127u, 0u, 
	8u, 11u, 31u, 48u, 57u, 65u, 90u, 97u, 
	122u, 9u, 10u, 13u, 32u, 45u, 46u, 58u, 
	127u, 0u, 31u, 48u, 57u, 65u, 90u, 97u, 
	122u, 10u, 13u, 45u, 127u, 0u, 8u, 11u, 
	31u, 48u, 57u, 65u, 90u, 97u, 122u, 9u, 
	10u, 13u, 32u, 58u, 127u, 0u, 31u, 48u, 
	57u, 65u, 90u, 97u, 122u, 9u, 10u, 13u, 
	32u, 127u, 0u, 31u, 48u, 57u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 48u, 57u, 65u, 
	90u, 97u, 122u, 10u, 13u, 45u, 46u, 127u, 
	0u, 8u, 11u, 31u, 48u, 57u, 65u, 90u, 
	97u, 122u, 10u, 13u, 127u, 0u, 8u, 11u, 
	31u, 48u, 57u, 65u, 90u, 97u, 122u, 10u, 
	13u, 45u, 46u, 127u, 0u, 8u, 11u, 31u, 
	48u, 57u, 65u, 90u, 97u, 122u, 10u, 13u, 
	127u, 0u, 8u, 11u, 31u, 48u, 57u, 65u, 
	90u, 97u, 122u, 9u, 10u, 13u, 32u, 45u, 
	46u, 58u, 127u, 0u, 31u, 48u, 57u, 65u, 
	90u, 97u, 122u, 10u, 9u, 10u, 13u, 32u, 
	33u, 44u, 124u, 126u, 127u, 0u, 31u, 35u, 
	39u, 42u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 9u, 10u, 13u, 32u, 44u, 127u, 0u, 
	31u, 9u, 10u, 13u, 32u, 33u, 67u, 72u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 10u, 33u, 
	58u, 101u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 110u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 116u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 45u, 46u, 58u, 124u, 126u, 
	35u, 39u, 42u, 43u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 76u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 101u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 110u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 103u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	116u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 104u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	9u, 10u, 13u, 32u, 127u, 0u, 31u, 48u, 
	57u, 9u, 10u, 13u, 32u, 127u, 0u, 31u, 
	48u, 57u, 9u, 10u, 13u, 32u, 33u, 67u, 
	72u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 10u, 
	9u, 10u, 13u, 32u, 127u, 0u, 31u, 48u, 
	57u, 10u, 48u, 57u, 65u, 70u, 97u, 102u, 
	48u, 57u, 65u, 70u, 97u, 102u, 32u, 33u, 
	37u, 61u, 95u, 126u, 36u, 59u, 63u, 90u, 
	97u, 122u, 48u, 57u, 65u, 70u, 97u, 102u, 
	48u, 57u, 65u, 70u, 97u, 102u, 32u, 33u, 
	37u, 43u, 58u, 59u, 61u, 64u, 95u, 126u, 
	36u, 44u, 45u, 46u, 48u, 57u, 65u, 90u, 
	97u, 122u, 0
];

static const byte[] _http_request_parser_single_lengths = [
	0, 3, 4, 7, 6, 1, 1, 1, 
	1, 1, 0, 1, 0, 2, 7, 1, 
	4, 3, 3, 9, 5, 5, 6, 5, 
	5, 5, 5, 5, 5, 4, 8, 8, 
	9, 5, 5, 5, 4, 5, 5, 9, 
	1, 5, 1, 4, 5, 3, 8, 4, 
	6, 5, 3, 5, 3, 5, 3, 8, 
	1, 9, 6, 9, 1, 5, 5, 5, 
	6, 5, 5, 5, 5, 5, 5, 4, 
	5, 5, 9, 1, 5, 1, 0, 0, 
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
	0, 6, 1, 6, 0, 6, 6, 6, 
	5, 6, 6, 6, 6, 6, 6, 6, 
	2, 2, 6, 0, 2, 0, 3, 3, 
	3, 3, 3, 5, 0
];

static const short[] _http_request_parser_index_offsets = [
	0, 0, 10, 21, 32, 43, 45, 47, 
	49, 51, 53, 55, 58, 60, 64, 78, 
	80, 91, 97, 103, 119, 131, 143, 156, 
	168, 180, 192, 204, 216, 228, 239, 255, 
	271, 287, 299, 311, 323, 334, 344, 354, 
	370, 372, 383, 385, 395, 406, 415, 428, 
	438, 449, 457, 466, 477, 486, 497, 506, 
	519, 521, 537, 545, 561, 563, 575, 587, 
	599, 611, 623, 635, 647, 659, 671, 683, 
	694, 702, 710, 726, 728, 736, 738, 742, 
	746, 756, 760, 764, 780
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
	27, 36, 37, 26, 26, 26, 26, 26, 
	26, 26, 26, 1, 26, 27, 38, 26, 
	26, 26, 26, 26, 26, 26, 26, 1, 
	26, 27, 39, 26, 26, 26, 26, 26, 
	26, 26, 26, 1, 26, 27, 40, 26, 
	26, 26, 26, 26, 26, 26, 26, 1, 
	26, 27, 41, 26, 26, 26, 26, 26, 
	26, 26, 26, 1, 26, 27, 42, 26, 
	26, 26, 26, 26, 26, 26, 26, 1, 
	26, 27, 43, 26, 26, 26, 26, 26, 
	26, 26, 26, 1, 26, 44, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 45, 
	46, 47, 45, 48, 48, 48, 1, 1, 
	48, 48, 48, 48, 48, 48, 28, 49, 
	50, 51, 49, 48, 48, 48, 1, 1, 
	48, 48, 48, 48, 48, 48, 31, 49, 
	21, 22, 49, 23, 24, 25, 23, 23, 
	23, 23, 23, 23, 23, 23, 1, 26, 
	27, 52, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 53, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 54, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 55, 26, 26, 26, 
	26, 26, 26, 26, 26, 1, 56, 57, 
	58, 56, 1, 1, 59, 60, 60, 28, 
	61, 62, 63, 61, 1, 1, 59, 60, 
	60, 31, 61, 21, 22, 61, 23, 24, 
	25, 23, 23, 23, 23, 23, 23, 23, 
	23, 1, 64, 1, 32, 33, 65, 66, 
	1, 1, 1, 67, 68, 68, 31, 69, 
	1, 32, 33, 65, 1, 1, 1, 68, 
	68, 68, 31, 32, 33, 65, 70, 1, 
	1, 1, 68, 68, 68, 31, 32, 33, 
	1, 1, 1, 68, 71, 71, 31, 72, 
	73, 74, 72, 75, 76, 77, 1, 1, 
	71, 71, 71, 31, 32, 33, 75, 1, 
	1, 1, 71, 71, 71, 31, 72, 73, 
	74, 72, 77, 1, 1, 68, 71, 71, 
	31, 72, 73, 74, 72, 1, 1, 77, 
	31, 32, 33, 1, 1, 1, 78, 71, 
	71, 31, 32, 33, 65, 79, 1, 1, 
	1, 78, 68, 68, 31, 32, 33, 1, 
	1, 1, 80, 71, 71, 31, 32, 33, 
	65, 81, 1, 1, 1, 80, 68, 68, 
	31, 32, 33, 1, 1, 1, 82, 71, 
	71, 31, 72, 73, 74, 72, 65, 70, 
	77, 1, 1, 82, 68, 68, 31, 83, 
	1, 84, 85, 86, 84, 87, 88, 87, 
	87, 1, 1, 87, 87, 87, 87, 87, 
	31, 89, 90, 91, 89, 49, 1, 1, 
	31, 89, 21, 22, 89, 23, 24, 25, 
	23, 23, 23, 23, 23, 23, 23, 23, 
	1, 92, 1, 26, 27, 93, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 94, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 95, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	96, 26, 27, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 97, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 98, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 99, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 100, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 27, 101, 26, 26, 
	26, 26, 26, 26, 26, 26, 1, 26, 
	27, 102, 26, 26, 26, 26, 26, 26, 
	26, 26, 1, 26, 103, 26, 26, 26, 
	26, 26, 26, 26, 26, 1, 104, 105, 
	106, 104, 1, 1, 107, 28, 108, 109, 
	110, 108, 1, 1, 107, 31, 108, 21, 
	22, 108, 23, 24, 25, 23, 23, 23, 
	23, 23, 23, 23, 23, 1, 111, 1, 
	112, 113, 114, 112, 1, 1, 115, 31, 
	116, 1, 117, 117, 117, 1, 9, 9, 
	9, 1, 8, 118, 119, 118, 118, 118, 
	118, 118, 118, 1, 120, 120, 120, 1, 
	118, 118, 118, 1, 8, 9, 10, 121, 
	118, 9, 9, 9, 9, 9, 9, 121, 
	121, 121, 121, 1, 1, 0
];

static const byte[] _http_request_parser_trans_targs = [
	2, 0, 3, 2, 4, 78, 80, 83, 
	5, 4, 78, 6, 7, 8, 9, 10, 
	11, 12, 13, 14, 77, 84, 15, 16, 
	20, 33, 16, 17, 18, 19, 42, 18, 
	19, 42, 21, 22, 23, 61, 24, 25, 
	26, 27, 28, 29, 30, 31, 32, 56, 
	57, 31, 32, 56, 34, 35, 36, 37, 
	38, 39, 40, 41, 46, 38, 39, 40, 
	39, 43, 50, 41, 44, 19, 45, 46, 
	18, 19, 42, 47, 48, 49, 51, 52, 
	53, 54, 55, 32, 58, 59, 60, 57, 
	31, 58, 59, 60, 59, 62, 63, 64, 
	65, 66, 67, 68, 69, 70, 71, 72, 
	73, 74, 75, 76, 73, 74, 75, 74, 
	18, 19, 42, 76, 14, 79, 80, 81, 
	82, 83
];

static const byte[] _http_request_parser_trans_actions = [
	1, 0, 19, 0, 1, 1, 1, 1, 
	21, 0, 0, 1, 0, 0, 0, 0, 
	0, 0, 0, 5, 5, 0, 0, 1, 
	1, 1, 0, 7, 1, 23, 23, 0, 
	9, 9, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 35, 1, 23, 23, 
	1, 0, 9, 9, 0, 0, 0, 41, 
	1, 23, 23, 1, 1, 0, 9, 9, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	11, 26, 26, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 15, 32, 32, 0, 
	15, 0, 9, 9, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 38, 
	1, 23, 23, 1, 0, 9, 9, 0, 
	13, 29, 29, 0, 0, 0, 0, 0, 
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
	0, 17, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0
];

static const int http_request_parser_start = 1;
static const int http_request_parser_first_final = 84;
static const int http_request_parser_error = 0;

static const int http_request_parser_en_main = 1;

#line 179 "parser.rl"


public:
    void init()
    {
        super.init();
        
#line 637 "parser.d"
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
                
#line 650 "parser.d"
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
#line 671 "parser.d"
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
            string* value = _fieldName in entity.extension;
            if (value is null) {
                entity.extension[_fieldName] = fieldValue;
            } else {
                *value ~= ", " ~ fieldValue;
            }
            //    fgoto *http_request_parser_error;
            mark = null;
        }
    }
	break;
	case 5:
#line 91 "parser.rl"
	{
        *_string = mark[0..p - mark];
        mark = null;
    }
	break;
	case 6:
#line 95 "parser.rl"
	{
        *_ulong = to!(ulong)(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 7:
#line 100 "parser.rl"
	{
        _list.insert(mark[0..p-mark]);
        mark = null;
    }
	break;
	case 9:
#line 111 "parser.rl"
	{
        if (general.connection is null) {
            general.connection = new IStringSet();
        }
        _headerHandled = true;
        _list = general.connection;
    }
	break;
	case 10:
#line 123 "parser.rl"
	{
        _headerHandled = true;
        _ulong = &entity.contentLength;
    }
	break;
	case 11:
#line 151 "parser.rl"
	{
            requestLine.method =
                parseHttpMethod(mark[0..p - mark]);
            mark = null;
        }
	break;
	case 12:
#line 157 "parser.rl"
	{
            requestLine.uri = mark[0..p - mark];
            mark = null;
        }
	break;
	case 13:
#line 162 "parser.rl"
	{
            _headerHandled = true;
            _string = &request.host;
        }
	break;
#line 835 "parser.d"
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
	case 8:
#line 104 "parser.rl"
	{
        _list.insert(mark[0..pe-mark]);
        mark = null;
    }
	break;
#line 859 "parser.d"
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
    Request* _request;
    bool _headerHandled;
    string _fieldName;
    IStringSet _list;
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
    
#line 901 "parser.d"
static const byte[] _http_response_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 1, 
	7, 1, 8, 1, 11, 1, 12, 2, 
	0, 4, 2, 0, 12, 2, 5, 4, 
	2, 6, 4, 2, 7, 4, 2, 9, 
	3, 2, 10, 3, 2, 13, 3
];

static const short[] _http_response_parser_key_offsets = [
	0, 0, 1, 2, 3, 4, 5, 7, 
	10, 12, 15, 17, 19, 21, 22, 29, 
	36, 55, 56, 72, 79, 86, 107, 124, 
	141, 159, 176, 193, 210, 227, 244, 261, 
	277, 299, 321, 342, 359, 376, 393, 410, 
	427, 444, 461, 477, 488, 499, 520, 521, 
	538, 539, 557, 575, 588, 601, 602, 623, 
	631, 652, 653, 670, 687, 704, 720, 737, 
	754, 771, 788, 805, 822, 838, 847, 856, 
	877, 878, 887, 888
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
	116u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 101u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 99u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 116u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 105u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 111u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 110u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 9u, 10u, 13u, 
	32u, 33u, 124u, 126u, 127u, 0u, 31u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 9u, 10u, 13u, 32u, 33u, 
	124u, 126u, 127u, 0u, 31u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 9u, 10u, 13u, 32u, 33u, 67u, 76u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	111u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 99u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 97u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 116u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 105u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 111u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 110u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 9u, 10u, 13u, 
	32u, 127u, 0u, 31u, 65u, 90u, 97u, 122u, 
	9u, 10u, 13u, 32u, 127u, 0u, 31u, 65u, 
	90u, 97u, 122u, 9u, 10u, 13u, 32u, 33u, 
	67u, 76u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	10u, 10u, 13u, 43u, 58u, 127u, 0u, 8u, 
	11u, 31u, 45u, 46u, 48u, 57u, 65u, 90u, 
	97u, 122u, 10u, 10u, 13u, 33u, 37u, 61u, 
	95u, 126u, 127u, 0u, 8u, 11u, 31u, 36u, 
	59u, 63u, 90u, 97u, 122u, 9u, 10u, 13u, 
	32u, 33u, 37u, 61u, 95u, 126u, 127u, 0u, 
	31u, 36u, 59u, 63u, 90u, 97u, 122u, 10u, 
	13u, 127u, 0u, 8u, 11u, 31u, 48u, 57u, 
	65u, 70u, 97u, 102u, 10u, 13u, 127u, 0u, 
	8u, 11u, 31u, 48u, 57u, 65u, 70u, 97u, 
	102u, 10u, 9u, 10u, 13u, 32u, 33u, 44u, 
	124u, 126u, 127u, 0u, 31u, 35u, 39u, 42u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 9u, 
	10u, 13u, 32u, 44u, 127u, 0u, 31u, 9u, 
	10u, 13u, 32u, 33u, 67u, 76u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 10u, 33u, 58u, 101u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	110u, 124u, 126u, 35u, 39u, 42u, 43u, 45u, 
	46u, 48u, 57u, 65u, 90u, 94u, 122u, 33u, 
	58u, 116u, 124u, 126u, 35u, 39u, 42u, 43u, 
	45u, 46u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 45u, 46u, 58u, 124u, 126u, 35u, 39u, 
	42u, 43u, 48u, 57u, 65u, 90u, 94u, 122u, 
	33u, 58u, 76u, 124u, 126u, 35u, 39u, 42u, 
	43u, 45u, 46u, 48u, 57u, 65u, 90u, 94u, 
	122u, 33u, 58u, 101u, 124u, 126u, 35u, 39u, 
	42u, 43u, 45u, 46u, 48u, 57u, 65u, 90u, 
	94u, 122u, 33u, 58u, 110u, 124u, 126u, 35u, 
	39u, 42u, 43u, 45u, 46u, 48u, 57u, 65u, 
	90u, 94u, 122u, 33u, 58u, 103u, 124u, 126u, 
	35u, 39u, 42u, 43u, 45u, 46u, 48u, 57u, 
	65u, 90u, 94u, 122u, 33u, 58u, 116u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 33u, 58u, 104u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 33u, 58u, 
	124u, 126u, 35u, 39u, 42u, 43u, 45u, 46u, 
	48u, 57u, 65u, 90u, 94u, 122u, 9u, 10u, 
	13u, 32u, 127u, 0u, 31u, 48u, 57u, 9u, 
	10u, 13u, 32u, 127u, 0u, 31u, 48u, 57u, 
	9u, 10u, 13u, 32u, 33u, 67u, 76u, 124u, 
	126u, 35u, 39u, 42u, 43u, 45u, 46u, 48u, 
	57u, 65u, 90u, 94u, 122u, 10u, 9u, 10u, 
	13u, 32u, 127u, 0u, 31u, 48u, 57u, 10u, 
	0
];

static const byte[] _http_response_parser_single_lengths = [
	0, 1, 1, 1, 1, 1, 0, 1, 
	0, 1, 0, 0, 0, 1, 3, 3, 
	7, 1, 4, 3, 3, 9, 5, 5, 
	6, 5, 5, 5, 5, 5, 5, 4, 
	8, 8, 9, 5, 5, 5, 5, 5, 
	5, 5, 4, 5, 5, 9, 1, 5, 
	1, 8, 10, 3, 3, 1, 9, 6, 
	9, 1, 5, 5, 5, 6, 5, 5, 
	5, 5, 5, 5, 4, 5, 5, 9, 
	1, 5, 1, 0
];

static const byte[] _http_response_parser_range_lengths = [
	0, 0, 0, 0, 0, 0, 1, 1, 
	1, 1, 1, 1, 1, 0, 2, 2, 
	6, 0, 6, 2, 2, 6, 6, 6, 
	6, 6, 6, 6, 6, 6, 6, 6, 
	7, 7, 6, 6, 6, 6, 6, 6, 
	6, 6, 6, 3, 3, 6, 0, 6, 
	0, 5, 4, 5, 5, 0, 6, 1, 
	6, 0, 6, 6, 6, 5, 6, 6, 
	6, 6, 6, 6, 6, 2, 2, 6, 
	0, 2, 0, 0
];

static const short[] _http_response_parser_index_offsets = [
	0, 0, 2, 4, 6, 8, 10, 12, 
	15, 17, 20, 22, 24, 26, 28, 34, 
	40, 54, 56, 67, 73, 79, 95, 107, 
	119, 132, 144, 156, 168, 180, 192, 204, 
	215, 231, 247, 263, 275, 287, 299, 311, 
	323, 335, 347, 358, 367, 376, 392, 394, 
	406, 408, 422, 437, 446, 455, 457, 473, 
	481, 497, 499, 511, 523, 535, 547, 559, 
	571, 583, 595, 607, 619, 630, 638, 646, 
	662, 664, 672, 674
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
	26, 35, 36, 25, 25, 25, 25, 25, 
	25, 25, 25, 1, 25, 26, 37, 25, 
	25, 25, 25, 25, 25, 25, 25, 1, 
	25, 26, 38, 25, 25, 25, 25, 25, 
	25, 25, 25, 1, 25, 26, 39, 25, 
	25, 25, 25, 25, 25, 25, 25, 1, 
	25, 26, 40, 25, 25, 25, 25, 25, 
	25, 25, 25, 1, 25, 26, 41, 25, 
	25, 25, 25, 25, 25, 25, 25, 1, 
	25, 26, 42, 25, 25, 25, 25, 25, 
	25, 25, 25, 1, 25, 43, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 44, 
	45, 46, 44, 47, 47, 47, 1, 1, 
	47, 47, 47, 47, 47, 47, 27, 48, 
	49, 50, 48, 47, 47, 47, 1, 1, 
	47, 47, 47, 47, 47, 47, 30, 48, 
	20, 21, 48, 22, 23, 24, 22, 22, 
	22, 22, 22, 22, 22, 22, 1, 25, 
	26, 51, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 52, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 53, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 54, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 55, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 56, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 57, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 58, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 59, 60, 
	61, 59, 1, 1, 62, 62, 27, 63, 
	64, 65, 63, 1, 1, 62, 62, 30, 
	63, 20, 21, 63, 22, 23, 24, 22, 
	22, 22, 22, 22, 22, 22, 22, 1, 
	66, 1, 31, 32, 67, 68, 1, 1, 
	1, 67, 67, 67, 67, 30, 69, 1, 
	31, 32, 70, 71, 70, 70, 70, 1, 
	1, 1, 70, 70, 70, 30, 72, 73, 
	74, 72, 70, 71, 70, 70, 70, 1, 
	1, 70, 70, 70, 30, 31, 32, 1, 
	1, 1, 75, 75, 75, 30, 31, 32, 
	1, 1, 1, 70, 70, 70, 30, 76, 
	1, 77, 78, 79, 77, 80, 81, 80, 
	80, 1, 1, 80, 80, 80, 80, 80, 
	30, 82, 83, 84, 82, 48, 1, 1, 
	30, 82, 20, 21, 82, 22, 23, 24, 
	22, 22, 22, 22, 22, 22, 22, 22, 
	1, 85, 1, 25, 26, 86, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 87, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 88, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	89, 25, 26, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 90, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 91, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 92, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 93, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 26, 94, 25, 25, 
	25, 25, 25, 25, 25, 25, 1, 25, 
	26, 95, 25, 25, 25, 25, 25, 25, 
	25, 25, 1, 25, 96, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 97, 98, 
	99, 97, 1, 1, 100, 27, 101, 102, 
	103, 101, 1, 1, 100, 30, 101, 20, 
	21, 101, 22, 23, 24, 22, 22, 22, 
	22, 22, 22, 22, 22, 1, 104, 1, 
	105, 106, 107, 105, 1, 1, 108, 30, 
	109, 1, 1, 0
];

static const byte[] _http_response_parser_trans_targs = [
	2, 0, 3, 4, 5, 6, 7, 8, 
	9, 10, 11, 12, 13, 14, 15, 16, 
	74, 15, 16, 74, 75, 17, 18, 22, 
	35, 18, 19, 20, 21, 48, 20, 21, 
	48, 23, 24, 25, 58, 26, 27, 28, 
	29, 30, 31, 32, 33, 34, 53, 54, 
	33, 34, 53, 36, 37, 38, 39, 40, 
	41, 42, 43, 44, 45, 46, 47, 44, 
	45, 46, 45, 47, 49, 21, 50, 51, 
	20, 21, 48, 52, 34, 55, 56, 57, 
	54, 33, 55, 56, 57, 56, 59, 60, 
	61, 62, 63, 64, 65, 66, 67, 68, 
	69, 70, 71, 72, 73, 70, 71, 72, 
	71, 20, 21, 48, 73, 16
];

static const byte[] _http_response_parser_trans_actions = [
	1, 0, 0, 0, 0, 0, 0, 0, 
	0, 5, 1, 0, 0, 19, 1, 26, 
	26, 0, 21, 21, 0, 0, 1, 1, 
	1, 0, 7, 1, 23, 23, 0, 9, 
	9, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 38, 1, 23, 23, 1, 
	0, 9, 9, 0, 0, 0, 0, 0, 
	0, 0, 44, 1, 23, 23, 1, 0, 
	9, 9, 0, 0, 0, 0, 0, 0, 
	11, 29, 29, 0, 0, 15, 35, 35, 
	0, 15, 0, 9, 9, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	41, 1, 23, 23, 1, 0, 9, 9, 
	0, 13, 32, 32, 0, 0
];

static const byte[] _http_response_parser_from_state_actions = [
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
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
	0, 0, 0, 0, 0, 0, 17, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0
];

static const int http_response_parser_start = 1;
static const int http_response_parser_first_final = 75;
static const int http_response_parser_error = 0;

static const int http_response_parser_en_main = 1;

#line 258 "parser.rl"


public:
    void init()
    {
        super.init();
        
#line 1240 "parser.d"
	{
	cs = http_response_parser_start;
	}
#line 265 "parser.rl"
    }

protected:
    void exec()
    {
        with(_response.status) {
            with(*_response) {
                
#line 1253 "parser.d"
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
#line 1274 "parser.d"
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
            string* value = _fieldName in entity.extension;
            if (value is null) {
                entity.extension[_fieldName] = fieldValue;
            } else {
                *value ~= ", " ~ fieldValue;
            }
            //    fgoto *http_request_parser_error;
            mark = null;
        }
    }
	break;
	case 5:
#line 91 "parser.rl"
	{
        *_string = mark[0..p - mark];
        mark = null;
    }
	break;
	case 6:
#line 95 "parser.rl"
	{
        *_ulong = to!(ulong)(mark[0..p - mark]);
        mark = null;
    }
	break;
	case 7:
#line 100 "parser.rl"
	{
        _list.insert(mark[0..p-mark]);
        mark = null;
    }
	break;
	case 9:
#line 111 "parser.rl"
	{
        if (general.connection is null) {
            general.connection = new IStringSet();
        }
        _headerHandled = true;
        _list = general.connection;
    }
	break;
	case 10:
#line 123 "parser.rl"
	{
        _headerHandled = true;
        _ulong = &entity.contentLength;
    }
	break;
	case 11:
#line 231 "parser.rl"
	{
            status.status = cast(Status)to!(int)(mark[0..p - mark]);
            mark = null;
        }
	break;
	case 12:
#line 236 "parser.rl"
	{
            status.reason = mark[0..p - mark];
            mark = null;
        }
	break;
	case 13:
#line 241 "parser.rl"
	{
            _headerHandled = true;
            _string = &response.location;
        }
	break;
#line 1437 "parser.d"
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
	case 8:
#line 104 "parser.rl"
	{
        _list.insert(mark[0..pe-mark]);
        mark = null;
    }
	break;
#line 1461 "parser.d"
		default: break;
		}
	}
	}

	_out: {}
	}
#line 273 "parser.rl"
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
    Response* _response;
    bool _headerHandled;
    string _fieldName;
    IStringSet _list;
    string* _string;
    ulong* _ulong;
    static Logger _log;
}
