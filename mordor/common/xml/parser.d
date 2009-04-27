#line 1 "xml.rl"
/* To compile to .d:
   ragel xml.rl -D -G1 -o parser.d
*/

module mordor.common.xml.parser;

import mordor.common.ragel;
import mordor.common.stringutils;

class XmlParser : RagelParserWithStack
{
private:
    
#line 16 "parser.d"
static const byte[] _xml_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 1, 
	7, 2, 0, 1, 2, 0, 6, 2, 
	2, 5, 2, 3, 7
];

static const int xml_parser_start = 1;
static const int xml_parser_first_final = 212;
static const int xml_parser_error = 0;

static const int xml_parser_en_parse_content = 154;
static const int xml_parser_en_main = 1;

#line 129 "xml.rl"


public:
    this(void delegate(string) startTag,
         void delegate(string) endTag,
         void delegate(string) attribName,
         void delegate(string) attribValue,
         void delegate(string) innerText)
    {
        _startTag = startTag;
        _endTag = endTag;
        _attribName = attribName;
        _attribValue = attribValue;
        _innerText = innerText;
    }

    void init()
    {
        super.init();
        
#line 52 "parser.d"
	{
	cs = xml_parser_start;
	top = 0;
	}
#line 149 "xml.rl"
    }

protected:
    void exec()
    {
        
#line 64 "parser.d"
	{
	byte* _acts;
	uint _nacts;

	if ( p == pe )
		goto _test_eof;
	if ( cs == 0 )
		goto _out;
_resume:
	switch ( cs ) {
case 1:
	switch( (*p) ) {
		case 13u: goto tr0;
		case 32u: goto tr0;
		case 60u: goto tr2;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr0;
	goto tr1;
case 0:
	goto _out;
case 2:
	switch( (*p) ) {
		case 13u: goto tr0;
		case 32u: goto tr0;
		case 60u: goto tr3;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr0;
	goto tr1;
case 3:
	switch( (*p) ) {
		case 33u: goto tr4;
		case 58u: goto tr5;
		case 63u: goto tr6;
		case 95u: goto tr5;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr5;
		} else if ( (*p) >= 65u )
			goto tr5;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr5;
		} else if ( (*p) >= 216u )
			goto tr5;
	} else
		goto tr5;
	goto tr1;
case 4:
	switch( (*p) ) {
		case 45u: goto tr7;
		case 68u: goto tr8;
		default: break;
	}
	goto tr1;
case 5:
	if ( (*p) == 45u )
		goto tr9;
	goto tr1;
case 6:
	switch( (*p) ) {
		case 13u: goto tr9;
		case 32u: goto tr9;
		case 45u: goto tr10;
		case 53u: goto tr9;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr9;
	} else if ( (*p) >= 9u )
		goto tr9;
	goto tr1;
case 7:
	switch( (*p) ) {
		case 13u: goto tr9;
		case 32u: goto tr9;
		case 45u: goto tr11;
		case 53u: goto tr9;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr9;
	} else if ( (*p) >= 9u )
		goto tr9;
	goto tr1;
case 8:
	if ( (*p) == 62u )
		goto tr0;
	goto tr1;
case 9:
	if ( (*p) == 79u )
		goto tr12;
	goto tr1;
case 10:
	if ( (*p) == 67u )
		goto tr13;
	goto tr1;
case 11:
	if ( (*p) == 84u )
		goto tr14;
	goto tr1;
case 12:
	if ( (*p) == 89u )
		goto tr15;
	goto tr1;
case 13:
	if ( (*p) == 80u )
		goto tr16;
	goto tr1;
case 14:
	if ( (*p) == 69u )
		goto tr17;
	goto tr1;
case 15:
	switch( (*p) ) {
		case 13u: goto tr18;
		case 32u: goto tr18;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr18;
	goto tr1;
case 16:
	switch( (*p) ) {
		case 13u: goto tr18;
		case 32u: goto tr18;
		case 58u: goto tr19;
		case 95u: goto tr19;
		default: break;
	}
	if ( (*p) < 97u ) {
		if ( (*p) > 10u ) {
			if ( 65u <= (*p) && (*p) <= 90u )
				goto tr19;
		} else if ( (*p) >= 9u )
			goto tr18;
	} else if ( (*p) > 122u ) {
		if ( (*p) < 216u ) {
			if ( 192u <= (*p) && (*p) <= 214u )
				goto tr19;
		} else if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr19;
		} else
			goto tr19;
	} else
		goto tr19;
	goto tr1;
case 17:
	switch( (*p) ) {
		case 13u: goto tr20;
		case 32u: goto tr20;
		case 47u: goto tr1;
		case 62u: goto tr21;
		case 91u: goto tr22;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr20;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 92u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr19;
case 18:
	switch( (*p) ) {
		case 13u: goto tr20;
		case 32u: goto tr20;
		case 62u: goto tr21;
		case 80u: goto tr23;
		case 83u: goto tr24;
		case 91u: goto tr22;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr20;
	goto tr1;
case 19:
	switch( (*p) ) {
		case 13u: goto tr21;
		case 32u: goto tr21;
		case 60u: goto tr25;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr21;
	goto tr1;
case 20:
	switch( (*p) ) {
		case 33u: goto tr26;
		case 58u: goto tr5;
		case 63u: goto tr27;
		case 95u: goto tr5;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr5;
		} else if ( (*p) >= 65u )
			goto tr5;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr5;
		} else if ( (*p) >= 216u )
			goto tr5;
	} else
		goto tr5;
	goto tr1;
case 21:
	if ( (*p) == 45u )
		goto tr28;
	goto tr1;
case 22:
	if ( (*p) == 45u )
		goto tr29;
	goto tr1;
case 23:
	switch( (*p) ) {
		case 13u: goto tr29;
		case 32u: goto tr29;
		case 45u: goto tr30;
		case 53u: goto tr29;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr29;
	} else if ( (*p) >= 9u )
		goto tr29;
	goto tr1;
case 24:
	switch( (*p) ) {
		case 13u: goto tr29;
		case 32u: goto tr29;
		case 45u: goto tr31;
		case 53u: goto tr29;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr29;
	} else if ( (*p) >= 9u )
		goto tr29;
	goto tr1;
case 25:
	if ( (*p) == 62u )
		goto tr21;
	goto tr1;
case 26:
	switch( (*p) ) {
		case 13u: goto tr32;
		case 32u: goto tr32;
		case 47u: goto tr34;
		case 62u: goto tr35;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr32;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr33;
case 27:
	switch( (*p) ) {
		case 13u: goto tr36;
		case 32u: goto tr36;
		case 47u: goto tr34;
		case 58u: goto tr37;
		case 62u: goto tr38;
		case 95u: goto tr37;
		default: break;
	}
	if ( (*p) < 97u ) {
		if ( (*p) > 10u ) {
			if ( 65u <= (*p) && (*p) <= 90u )
				goto tr37;
		} else if ( (*p) >= 9u )
			goto tr36;
	} else if ( (*p) > 122u ) {
		if ( (*p) < 216u ) {
			if ( 192u <= (*p) && (*p) <= 214u )
				goto tr37;
		} else if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr37;
		} else
			goto tr37;
	} else
		goto tr37;
	goto tr1;
case 28:
	if ( (*p) == 62u )
		goto tr39;
	goto tr1;
case 212:
	switch( (*p) ) {
		case 13u: goto tr39;
		case 32u: goto tr39;
		case 60u: goto tr244;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr39;
	goto tr1;
case 29:
	switch( (*p) ) {
		case 33u: goto tr40;
		case 63u: goto tr41;
		default: break;
	}
	goto tr1;
case 30:
	if ( (*p) == 45u )
		goto tr42;
	goto tr1;
case 31:
	if ( (*p) == 45u )
		goto tr43;
	goto tr1;
case 32:
	switch( (*p) ) {
		case 13u: goto tr43;
		case 32u: goto tr43;
		case 45u: goto tr44;
		case 53u: goto tr43;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr43;
	} else if ( (*p) >= 9u )
		goto tr43;
	goto tr1;
case 33:
	switch( (*p) ) {
		case 13u: goto tr43;
		case 32u: goto tr43;
		case 45u: goto tr34;
		case 53u: goto tr43;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr43;
	} else if ( (*p) >= 9u )
		goto tr43;
	goto tr1;
case 34:
	switch( (*p) ) {
		case 58u: goto tr45;
		case 88u: goto tr46;
		case 95u: goto tr45;
		case 120u: goto tr46;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr45;
		} else if ( (*p) >= 65u )
			goto tr45;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr45;
		} else if ( (*p) >= 216u )
			goto tr45;
	} else
		goto tr45;
	goto tr1;
case 35:
	switch( (*p) ) {
		case 13u: goto tr47;
		case 32u: goto tr47;
		case 47u: goto tr1;
		case 63u: goto tr34;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr47;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr45;
case 36:
	switch( (*p) ) {
		case 13u: goto tr47;
		case 32u: goto tr47;
		case 53u: goto tr47;
		case 63u: goto tr34;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr47;
	} else if ( (*p) >= 9u )
		goto tr47;
	goto tr1;
case 37:
	switch( (*p) ) {
		case 13u: goto tr47;
		case 32u: goto tr47;
		case 47u: goto tr1;
		case 63u: goto tr34;
		case 77u: goto tr48;
		case 96u: goto tr1;
		case 109u: goto tr48;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr47;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr45;
case 38:
	switch( (*p) ) {
		case 13u: goto tr47;
		case 32u: goto tr47;
		case 47u: goto tr1;
		case 63u: goto tr34;
		case 76u: goto tr49;
		case 96u: goto tr1;
		case 108u: goto tr49;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr47;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr45;
case 39:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 59u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr45;
case 40:
	switch( (*p) ) {
		case 13u: goto tr50;
		case 32u: goto tr50;
		case 47u: goto tr1;
		case 61u: goto tr52;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr50;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr51;
case 41:
	switch( (*p) ) {
		case 13u: goto tr53;
		case 32u: goto tr53;
		case 61u: goto tr54;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr53;
	goto tr1;
case 42:
	switch( (*p) ) {
		case 13u: goto tr54;
		case 32u: goto tr54;
		case 34u: goto tr55;
		case 39u: goto tr56;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr54;
	goto tr1;
case 43:
	switch( (*p) ) {
		case 34u: goto tr58;
		case 38u: goto tr59;
		case 60u: goto tr1;
		default: break;
	}
	goto tr57;
case 44:
	switch( (*p) ) {
		case 34u: goto tr61;
		case 38u: goto tr62;
		case 60u: goto tr1;
		default: break;
	}
	goto tr60;
case 45:
	switch( (*p) ) {
		case 13u: goto tr36;
		case 32u: goto tr36;
		case 47u: goto tr34;
		case 62u: goto tr38;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr36;
	goto tr1;
case 46:
	switch( (*p) ) {
		case 35u: goto tr63;
		case 58u: goto tr64;
		case 95u: goto tr64;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr64;
		} else if ( (*p) >= 65u )
			goto tr64;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr64;
		} else if ( (*p) >= 216u )
			goto tr64;
	} else
		goto tr64;
	goto tr1;
case 47:
	if ( (*p) == 120u )
		goto tr66;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr65;
	goto tr1;
case 48:
	if ( (*p) == 59u )
		goto tr60;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr65;
	goto tr1;
case 49:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr67;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr67;
	} else
		goto tr67;
	goto tr1;
case 50:
	if ( (*p) == 59u )
		goto tr60;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr67;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr67;
	} else
		goto tr67;
	goto tr1;
case 51:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 59u: goto tr60;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 60u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr64;
case 52:
	switch( (*p) ) {
		case 38u: goto tr69;
		case 39u: goto tr58;
		case 60u: goto tr1;
		default: break;
	}
	goto tr68;
case 53:
	switch( (*p) ) {
		case 38u: goto tr71;
		case 39u: goto tr61;
		case 60u: goto tr1;
		default: break;
	}
	goto tr70;
case 54:
	switch( (*p) ) {
		case 35u: goto tr72;
		case 58u: goto tr73;
		case 95u: goto tr73;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr73;
		} else if ( (*p) >= 65u )
			goto tr73;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr73;
		} else if ( (*p) >= 216u )
			goto tr73;
	} else
		goto tr73;
	goto tr1;
case 55:
	if ( (*p) == 120u )
		goto tr75;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr74;
	goto tr1;
case 56:
	if ( (*p) == 59u )
		goto tr70;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr74;
	goto tr1;
case 57:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr76;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr76;
	} else
		goto tr76;
	goto tr1;
case 58:
	if ( (*p) == 59u )
		goto tr70;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr76;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr76;
	} else
		goto tr76;
	goto tr1;
case 59:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 59u: goto tr70;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 60u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr73;
case 60:
	switch( (*p) ) {
		case 58u: goto tr77;
		case 88u: goto tr78;
		case 95u: goto tr77;
		case 120u: goto tr78;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr77;
		} else if ( (*p) >= 65u )
			goto tr77;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr77;
		} else if ( (*p) >= 216u )
			goto tr77;
	} else
		goto tr77;
	goto tr1;
case 61:
	switch( (*p) ) {
		case 13u: goto tr79;
		case 32u: goto tr79;
		case 47u: goto tr1;
		case 63u: goto tr31;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr79;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr77;
case 62:
	switch( (*p) ) {
		case 13u: goto tr79;
		case 32u: goto tr79;
		case 53u: goto tr79;
		case 63u: goto tr31;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr79;
	} else if ( (*p) >= 9u )
		goto tr79;
	goto tr1;
case 63:
	switch( (*p) ) {
		case 13u: goto tr79;
		case 32u: goto tr79;
		case 47u: goto tr1;
		case 63u: goto tr31;
		case 77u: goto tr80;
		case 96u: goto tr1;
		case 109u: goto tr80;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr79;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr77;
case 64:
	switch( (*p) ) {
		case 13u: goto tr79;
		case 32u: goto tr79;
		case 47u: goto tr1;
		case 63u: goto tr31;
		case 76u: goto tr81;
		case 96u: goto tr1;
		case 108u: goto tr81;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr79;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr77;
case 65:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 59u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr77;
case 66:
	if ( (*p) == 85u )
		goto tr82;
	goto tr1;
case 67:
	if ( (*p) == 66u )
		goto tr83;
	goto tr1;
case 68:
	if ( (*p) == 76u )
		goto tr84;
	goto tr1;
case 69:
	if ( (*p) == 73u )
		goto tr85;
	goto tr1;
case 70:
	if ( (*p) == 67u )
		goto tr86;
	goto tr1;
case 71:
	switch( (*p) ) {
		case 13u: goto tr87;
		case 32u: goto tr87;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr87;
	goto tr1;
case 72:
	switch( (*p) ) {
		case 13u: goto tr87;
		case 32u: goto tr87;
		case 34u: goto tr88;
		case 39u: goto tr89;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr87;
	goto tr1;
case 73:
	switch( (*p) ) {
		case 10u: goto tr88;
		case 13u: goto tr88;
		case 34u: goto tr90;
		case 61u: goto tr88;
		case 95u: goto tr88;
		default: break;
	}
	if ( (*p) < 39u ) {
		if ( 32u <= (*p) && (*p) <= 37u )
			goto tr88;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr88;
		} else if ( (*p) >= 63u )
			goto tr88;
	} else
		goto tr88;
	goto tr1;
case 74:
	switch( (*p) ) {
		case 13u: goto tr91;
		case 32u: goto tr91;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr91;
	goto tr1;
case 75:
	switch( (*p) ) {
		case 13u: goto tr91;
		case 32u: goto tr91;
		case 34u: goto tr92;
		case 39u: goto tr93;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr91;
	goto tr1;
case 76:
	if ( (*p) == 34u )
		goto tr94;
	goto tr92;
case 77:
	switch( (*p) ) {
		case 13u: goto tr94;
		case 32u: goto tr94;
		case 62u: goto tr21;
		case 91u: goto tr22;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr94;
	goto tr1;
case 78:
	if ( (*p) == 93u )
		goto tr95;
	goto tr1;
case 79:
	switch( (*p) ) {
		case 13u: goto tr95;
		case 32u: goto tr95;
		case 62u: goto tr21;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr95;
	goto tr1;
case 80:
	if ( (*p) == 39u )
		goto tr94;
	goto tr93;
case 81:
	switch( (*p) ) {
		case 10u: goto tr89;
		case 13u: goto tr89;
		case 39u: goto tr90;
		case 61u: goto tr89;
		case 95u: goto tr89;
		default: break;
	}
	if ( (*p) < 40u ) {
		if ( (*p) > 33u ) {
			if ( 35u <= (*p) && (*p) <= 37u )
				goto tr89;
		} else if ( (*p) >= 32u )
			goto tr89;
	} else if ( (*p) > 59u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr89;
		} else if ( (*p) >= 63u )
			goto tr89;
	} else
		goto tr89;
	goto tr1;
case 82:
	if ( (*p) == 89u )
		goto tr96;
	goto tr1;
case 83:
	if ( (*p) == 83u )
		goto tr97;
	goto tr1;
case 84:
	if ( (*p) == 84u )
		goto tr98;
	goto tr1;
case 85:
	if ( (*p) == 69u )
		goto tr99;
	goto tr1;
case 86:
	if ( (*p) == 77u )
		goto tr90;
	goto tr1;
case 87:
	switch( (*p) ) {
		case 58u: goto tr100;
		case 88u: goto tr101;
		case 95u: goto tr100;
		case 120u: goto tr101;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr100;
		} else if ( (*p) >= 65u )
			goto tr100;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr100;
		} else if ( (*p) >= 216u )
			goto tr100;
	} else
		goto tr100;
	goto tr1;
case 88:
	switch( (*p) ) {
		case 13u: goto tr102;
		case 32u: goto tr102;
		case 47u: goto tr1;
		case 63u: goto tr11;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr102;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 89:
	switch( (*p) ) {
		case 13u: goto tr102;
		case 32u: goto tr102;
		case 53u: goto tr102;
		case 63u: goto tr11;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr102;
	} else if ( (*p) >= 9u )
		goto tr102;
	goto tr1;
case 90:
	switch( (*p) ) {
		case 13u: goto tr102;
		case 32u: goto tr102;
		case 47u: goto tr1;
		case 63u: goto tr11;
		case 77u: goto tr103;
		case 96u: goto tr1;
		case 109u: goto tr103;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr102;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 91:
	switch( (*p) ) {
		case 13u: goto tr102;
		case 32u: goto tr102;
		case 47u: goto tr1;
		case 63u: goto tr11;
		case 76u: goto tr104;
		case 96u: goto tr1;
		case 108u: goto tr104;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr102;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 92:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 59u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 93:
	switch( (*p) ) {
		case 33u: goto tr4;
		case 58u: goto tr5;
		case 63u: goto tr105;
		case 95u: goto tr5;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr5;
		} else if ( (*p) >= 65u )
			goto tr5;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr5;
		} else if ( (*p) >= 216u )
			goto tr5;
	} else
		goto tr5;
	goto tr1;
case 94:
	switch( (*p) ) {
		case 58u: goto tr100;
		case 88u: goto tr101;
		case 95u: goto tr100;
		case 120u: goto tr106;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr100;
		} else if ( (*p) >= 65u )
			goto tr100;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr100;
		} else if ( (*p) >= 216u )
			goto tr100;
	} else
		goto tr100;
	goto tr1;
case 95:
	switch( (*p) ) {
		case 13u: goto tr102;
		case 32u: goto tr102;
		case 47u: goto tr1;
		case 63u: goto tr11;
		case 77u: goto tr103;
		case 96u: goto tr1;
		case 109u: goto tr107;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr102;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 96:
	switch( (*p) ) {
		case 13u: goto tr102;
		case 32u: goto tr102;
		case 47u: goto tr1;
		case 63u: goto tr11;
		case 76u: goto tr104;
		case 96u: goto tr1;
		case 108u: goto tr108;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr102;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 97:
	switch( (*p) ) {
		case 13u: goto tr109;
		case 32u: goto tr109;
		case 47u: goto tr1;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr109;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr100;
case 98:
	switch( (*p) ) {
		case 13u: goto tr109;
		case 32u: goto tr109;
		case 118u: goto tr110;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr109;
	goto tr1;
case 99:
	if ( (*p) == 101u )
		goto tr111;
	goto tr1;
case 100:
	if ( (*p) == 114u )
		goto tr112;
	goto tr1;
case 101:
	if ( (*p) == 115u )
		goto tr113;
	goto tr1;
case 102:
	if ( (*p) == 105u )
		goto tr114;
	goto tr1;
case 103:
	if ( (*p) == 111u )
		goto tr115;
	goto tr1;
case 104:
	if ( (*p) == 110u )
		goto tr116;
	goto tr1;
case 105:
	switch( (*p) ) {
		case 13u: goto tr116;
		case 32u: goto tr116;
		case 61u: goto tr117;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr116;
	goto tr1;
case 106:
	switch( (*p) ) {
		case 13u: goto tr117;
		case 32u: goto tr117;
		case 34u: goto tr118;
		case 39u: goto tr119;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr117;
	goto tr1;
case 107:
	if ( (*p) == 49u )
		goto tr120;
	goto tr1;
case 108:
	if ( (*p) == 46u )
		goto tr121;
	goto tr1;
case 109:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr122;
	goto tr1;
case 110:
	if ( (*p) == 34u )
		goto tr123;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr122;
	goto tr1;
case 111:
	switch( (*p) ) {
		case 13u: goto tr124;
		case 32u: goto tr124;
		case 63u: goto tr11;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr124;
	goto tr1;
case 112:
	switch( (*p) ) {
		case 13u: goto tr124;
		case 32u: goto tr124;
		case 63u: goto tr11;
		case 101u: goto tr125;
		case 115u: goto tr126;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr124;
	goto tr1;
case 113:
	if ( (*p) == 110u )
		goto tr127;
	goto tr1;
case 114:
	if ( (*p) == 99u )
		goto tr128;
	goto tr1;
case 115:
	if ( (*p) == 111u )
		goto tr129;
	goto tr1;
case 116:
	if ( (*p) == 100u )
		goto tr130;
	goto tr1;
case 117:
	if ( (*p) == 105u )
		goto tr131;
	goto tr1;
case 118:
	if ( (*p) == 110u )
		goto tr132;
	goto tr1;
case 119:
	if ( (*p) == 103u )
		goto tr133;
	goto tr1;
case 120:
	switch( (*p) ) {
		case 13u: goto tr133;
		case 32u: goto tr133;
		case 61u: goto tr134;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr133;
	goto tr1;
case 121:
	switch( (*p) ) {
		case 13u: goto tr134;
		case 32u: goto tr134;
		case 34u: goto tr135;
		case 39u: goto tr136;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr134;
	goto tr1;
case 122:
	if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr137;
	} else if ( (*p) >= 65u )
		goto tr137;
	goto tr1;
case 123:
	switch( (*p) ) {
		case 34u: goto tr138;
		case 95u: goto tr137;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 45u <= (*p) && (*p) <= 46u )
			goto tr137;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr137;
		} else if ( (*p) >= 65u )
			goto tr137;
	} else
		goto tr137;
	goto tr1;
case 124:
	switch( (*p) ) {
		case 13u: goto tr139;
		case 32u: goto tr139;
		case 63u: goto tr11;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr139;
	goto tr1;
case 125:
	switch( (*p) ) {
		case 13u: goto tr139;
		case 32u: goto tr139;
		case 63u: goto tr11;
		case 115u: goto tr126;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr139;
	goto tr1;
case 126:
	if ( (*p) == 116u )
		goto tr140;
	goto tr1;
case 127:
	if ( (*p) == 97u )
		goto tr141;
	goto tr1;
case 128:
	if ( (*p) == 110u )
		goto tr142;
	goto tr1;
case 129:
	if ( (*p) == 100u )
		goto tr143;
	goto tr1;
case 130:
	if ( (*p) == 97u )
		goto tr144;
	goto tr1;
case 131:
	if ( (*p) == 108u )
		goto tr145;
	goto tr1;
case 132:
	if ( (*p) == 111u )
		goto tr146;
	goto tr1;
case 133:
	if ( (*p) == 110u )
		goto tr147;
	goto tr1;
case 134:
	if ( (*p) == 101u )
		goto tr148;
	goto tr1;
case 135:
	switch( (*p) ) {
		case 13u: goto tr148;
		case 32u: goto tr148;
		case 61u: goto tr149;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr148;
	goto tr1;
case 136:
	switch( (*p) ) {
		case 13u: goto tr149;
		case 32u: goto tr149;
		case 34u: goto tr150;
		case 39u: goto tr151;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr149;
	goto tr1;
case 137:
	switch( (*p) ) {
		case 110u: goto tr152;
		case 121u: goto tr153;
		default: break;
	}
	goto tr1;
case 138:
	if ( (*p) == 111u )
		goto tr154;
	goto tr1;
case 139:
	if ( (*p) == 34u )
		goto tr155;
	goto tr1;
case 140:
	switch( (*p) ) {
		case 13u: goto tr155;
		case 32u: goto tr155;
		case 63u: goto tr11;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr155;
	goto tr1;
case 141:
	if ( (*p) == 101u )
		goto tr156;
	goto tr1;
case 142:
	if ( (*p) == 115u )
		goto tr154;
	goto tr1;
case 143:
	switch( (*p) ) {
		case 110u: goto tr157;
		case 121u: goto tr158;
		default: break;
	}
	goto tr1;
case 144:
	if ( (*p) == 111u )
		goto tr159;
	goto tr1;
case 145:
	if ( (*p) == 39u )
		goto tr155;
	goto tr1;
case 146:
	if ( (*p) == 101u )
		goto tr160;
	goto tr1;
case 147:
	if ( (*p) == 115u )
		goto tr159;
	goto tr1;
case 148:
	if ( (*p) > 90u ) {
		if ( 97u <= (*p) && (*p) <= 122u )
			goto tr161;
	} else if ( (*p) >= 65u )
		goto tr161;
	goto tr1;
case 149:
	switch( (*p) ) {
		case 39u: goto tr138;
		case 95u: goto tr161;
		default: break;
	}
	if ( (*p) < 48u ) {
		if ( 45u <= (*p) && (*p) <= 46u )
			goto tr161;
	} else if ( (*p) > 57u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr161;
		} else if ( (*p) >= 65u )
			goto tr161;
	} else
		goto tr161;
	goto tr1;
case 150:
	if ( (*p) == 49u )
		goto tr162;
	goto tr1;
case 151:
	if ( (*p) == 46u )
		goto tr163;
	goto tr1;
case 152:
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr164;
	goto tr1;
case 153:
	if ( (*p) == 39u )
		goto tr123;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr164;
	goto tr1;
case 154:
	switch( (*p) ) {
		case 38u: goto tr166;
		case 60u: goto tr167;
		case 93u: goto tr168;
		default: break;
	}
	goto tr165;
case 155:
	switch( (*p) ) {
		case 38u: goto tr170;
		case 60u: goto tr171;
		case 93u: goto tr172;
		default: break;
	}
	goto tr169;
case 156:
	switch( (*p) ) {
		case 35u: goto tr173;
		case 58u: goto tr174;
		case 95u: goto tr174;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr174;
		} else if ( (*p) >= 65u )
			goto tr174;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr174;
		} else if ( (*p) >= 216u )
			goto tr174;
	} else
		goto tr174;
	goto tr1;
case 157:
	if ( (*p) == 120u )
		goto tr176;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr175;
	goto tr1;
case 158:
	if ( (*p) == 59u )
		goto tr177;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr175;
	goto tr1;
case 159:
	switch( (*p) ) {
		case 38u: goto tr178;
		case 60u: goto tr179;
		case 93u: goto tr180;
		default: break;
	}
	goto tr177;
case 160:
	switch( (*p) ) {
		case 33u: goto tr181;
		case 47u: goto tr182;
		case 58u: goto tr183;
		case 63u: goto tr184;
		case 95u: goto tr183;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr183;
		} else if ( (*p) >= 65u )
			goto tr183;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr183;
		} else if ( (*p) >= 216u )
			goto tr183;
	} else
		goto tr183;
	goto tr1;
case 161:
	switch( (*p) ) {
		case 45u: goto tr185;
		case 91u: goto tr186;
		default: break;
	}
	goto tr1;
case 162:
	if ( (*p) == 45u )
		goto tr187;
	goto tr1;
case 163:
	switch( (*p) ) {
		case 13u: goto tr187;
		case 32u: goto tr187;
		case 45u: goto tr188;
		case 53u: goto tr187;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr187;
	} else if ( (*p) >= 9u )
		goto tr187;
	goto tr1;
case 164:
	switch( (*p) ) {
		case 13u: goto tr187;
		case 32u: goto tr187;
		case 45u: goto tr189;
		case 53u: goto tr187;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr187;
	} else if ( (*p) >= 9u )
		goto tr187;
	goto tr1;
case 165:
	if ( (*p) == 62u )
		goto tr177;
	goto tr1;
case 166:
	if ( (*p) == 67u )
		goto tr190;
	goto tr1;
case 167:
	if ( (*p) == 68u )
		goto tr191;
	goto tr1;
case 168:
	if ( (*p) == 65u )
		goto tr192;
	goto tr1;
case 169:
	if ( (*p) == 84u )
		goto tr193;
	goto tr1;
case 170:
	if ( (*p) == 65u )
		goto tr194;
	goto tr1;
case 171:
	if ( (*p) == 91u )
		goto tr195;
	goto tr1;
case 172:
	switch( (*p) ) {
		case 13u: goto tr195;
		case 32u: goto tr195;
		case 53u: goto tr195;
		case 93u: goto tr196;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr195;
	} else if ( (*p) >= 9u )
		goto tr195;
	goto tr1;
case 173:
	if ( (*p) == 93u )
		goto tr189;
	goto tr1;
case 174:
	switch( (*p) ) {
		case 58u: goto tr197;
		case 95u: goto tr197;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr197;
		} else if ( (*p) >= 65u )
			goto tr197;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr197;
		} else if ( (*p) >= 216u )
			goto tr197;
	} else
		goto tr197;
	goto tr1;
case 175:
	switch( (*p) ) {
		case 13u: goto tr198;
		case 32u: goto tr198;
		case 47u: goto tr1;
		case 62u: goto tr200;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr198;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr199;
case 176:
	switch( (*p) ) {
		case 13u: goto tr201;
		case 32u: goto tr201;
		case 62u: goto tr202;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr201;
	goto tr1;
case 213:
	goto tr1;
case 177:
	switch( (*p) ) {
		case 13u: goto tr203;
		case 32u: goto tr203;
		case 47u: goto tr189;
		case 62u: goto tr205;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr203;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr204;
case 178:
	switch( (*p) ) {
		case 13u: goto tr206;
		case 32u: goto tr206;
		case 47u: goto tr189;
		case 58u: goto tr207;
		case 62u: goto tr208;
		case 95u: goto tr207;
		default: break;
	}
	if ( (*p) < 97u ) {
		if ( (*p) > 10u ) {
			if ( 65u <= (*p) && (*p) <= 90u )
				goto tr207;
		} else if ( (*p) >= 9u )
			goto tr206;
	} else if ( (*p) > 122u ) {
		if ( (*p) < 216u ) {
			if ( 192u <= (*p) && (*p) <= 214u )
				goto tr207;
		} else if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr207;
		} else
			goto tr207;
	} else
		goto tr207;
	goto tr1;
case 179:
	switch( (*p) ) {
		case 13u: goto tr209;
		case 32u: goto tr209;
		case 47u: goto tr1;
		case 61u: goto tr211;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr209;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr210;
case 180:
	switch( (*p) ) {
		case 13u: goto tr212;
		case 32u: goto tr212;
		case 61u: goto tr213;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr212;
	goto tr1;
case 181:
	switch( (*p) ) {
		case 13u: goto tr213;
		case 32u: goto tr213;
		case 34u: goto tr214;
		case 39u: goto tr215;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr213;
	goto tr1;
case 182:
	switch( (*p) ) {
		case 34u: goto tr217;
		case 38u: goto tr218;
		case 60u: goto tr1;
		default: break;
	}
	goto tr216;
case 183:
	switch( (*p) ) {
		case 34u: goto tr220;
		case 38u: goto tr221;
		case 60u: goto tr1;
		default: break;
	}
	goto tr219;
case 184:
	switch( (*p) ) {
		case 13u: goto tr206;
		case 32u: goto tr206;
		case 47u: goto tr189;
		case 62u: goto tr208;
		default: break;
	}
	if ( 9u <= (*p) && (*p) <= 10u )
		goto tr206;
	goto tr1;
case 185:
	switch( (*p) ) {
		case 35u: goto tr222;
		case 58u: goto tr223;
		case 95u: goto tr223;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr223;
		} else if ( (*p) >= 65u )
			goto tr223;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr223;
		} else if ( (*p) >= 216u )
			goto tr223;
	} else
		goto tr223;
	goto tr1;
case 186:
	if ( (*p) == 120u )
		goto tr225;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr224;
	goto tr1;
case 187:
	if ( (*p) == 59u )
		goto tr219;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr224;
	goto tr1;
case 188:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr226;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr226;
	} else
		goto tr226;
	goto tr1;
case 189:
	if ( (*p) == 59u )
		goto tr219;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr226;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr226;
	} else
		goto tr226;
	goto tr1;
case 190:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 59u: goto tr219;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 60u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr223;
case 191:
	switch( (*p) ) {
		case 38u: goto tr228;
		case 39u: goto tr217;
		case 60u: goto tr1;
		default: break;
	}
	goto tr227;
case 192:
	switch( (*p) ) {
		case 38u: goto tr230;
		case 39u: goto tr220;
		case 60u: goto tr1;
		default: break;
	}
	goto tr229;
case 193:
	switch( (*p) ) {
		case 35u: goto tr231;
		case 58u: goto tr232;
		case 95u: goto tr232;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr232;
		} else if ( (*p) >= 65u )
			goto tr232;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr232;
		} else if ( (*p) >= 216u )
			goto tr232;
	} else
		goto tr232;
	goto tr1;
case 194:
	if ( (*p) == 120u )
		goto tr234;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr233;
	goto tr1;
case 195:
	if ( (*p) == 59u )
		goto tr229;
	if ( 48u <= (*p) && (*p) <= 57u )
		goto tr233;
	goto tr1;
case 196:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr235;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr235;
	} else
		goto tr235;
	goto tr1;
case 197:
	if ( (*p) == 59u )
		goto tr229;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr235;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr235;
	} else
		goto tr235;
	goto tr1;
case 198:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 59u: goto tr229;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 60u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr232;
case 199:
	switch( (*p) ) {
		case 58u: goto tr236;
		case 88u: goto tr237;
		case 95u: goto tr236;
		case 120u: goto tr237;
		default: break;
	}
	if ( (*p) < 192u ) {
		if ( (*p) > 90u ) {
			if ( 97u <= (*p) && (*p) <= 122u )
				goto tr236;
		} else if ( (*p) >= 65u )
			goto tr236;
	} else if ( (*p) > 214u ) {
		if ( (*p) > 246u ) {
			if ( 248u <= (*p) )
				goto tr236;
		} else if ( (*p) >= 216u )
			goto tr236;
	} else
		goto tr236;
	goto tr1;
case 200:
	switch( (*p) ) {
		case 13u: goto tr238;
		case 32u: goto tr238;
		case 47u: goto tr1;
		case 63u: goto tr189;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr238;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr236;
case 201:
	switch( (*p) ) {
		case 13u: goto tr238;
		case 32u: goto tr238;
		case 53u: goto tr238;
		case 63u: goto tr189;
		default: break;
	}
	if ( (*p) > 10u ) {
		if ( 39u <= (*p) && (*p) <= 50u )
			goto tr238;
	} else if ( (*p) >= 9u )
		goto tr238;
	goto tr1;
case 202:
	switch( (*p) ) {
		case 13u: goto tr238;
		case 32u: goto tr238;
		case 47u: goto tr1;
		case 63u: goto tr189;
		case 77u: goto tr239;
		case 96u: goto tr1;
		case 109u: goto tr239;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr238;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr236;
case 203:
	switch( (*p) ) {
		case 13u: goto tr238;
		case 32u: goto tr238;
		case 47u: goto tr1;
		case 63u: goto tr189;
		case 76u: goto tr240;
		case 96u: goto tr1;
		case 108u: goto tr240;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 59u ) {
		if ( (*p) < 9u ) {
			if ( (*p) <= 8u )
				goto tr1;
		} else if ( (*p) > 10u ) {
			if ( 11u <= (*p) && (*p) <= 44u )
				goto tr1;
		} else
			goto tr238;
	} else if ( (*p) > 64u ) {
		if ( (*p) < 123u ) {
			if ( 91u <= (*p) && (*p) <= 94u )
				goto tr1;
		} else if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else
			goto tr1;
	} else
		goto tr1;
	goto tr236;
case 204:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 59u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr236;
case 205:
	switch( (*p) ) {
		case 38u: goto tr178;
		case 60u: goto tr179;
		case 93u: goto tr241;
		default: break;
	}
	goto tr177;
case 206:
	switch( (*p) ) {
		case 38u: goto tr178;
		case 60u: goto tr179;
		case 62u: goto tr1;
		case 93u: goto tr241;
		default: break;
	}
	goto tr177;
case 207:
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr242;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr242;
	} else
		goto tr242;
	goto tr1;
case 208:
	if ( (*p) == 59u )
		goto tr177;
	if ( (*p) < 65u ) {
		if ( 48u <= (*p) && (*p) <= 57u )
			goto tr242;
	} else if ( (*p) > 70u ) {
		if ( 97u <= (*p) && (*p) <= 102u )
			goto tr242;
	} else
		goto tr242;
	goto tr1;
case 209:
	switch( (*p) ) {
		case 47u: goto tr1;
		case 59u: goto tr177;
		case 96u: goto tr1;
		case 215u: goto tr1;
		case 247u: goto tr1;
		default: break;
	}
	if ( (*p) < 91u ) {
		if ( (*p) > 44u ) {
			if ( 60u <= (*p) && (*p) <= 64u )
				goto tr1;
		} else
			goto tr1;
	} else if ( (*p) > 94u ) {
		if ( (*p) > 182u ) {
			if ( 184u <= (*p) && (*p) <= 191u )
				goto tr1;
		} else if ( (*p) >= 123u )
			goto tr1;
	} else
		goto tr1;
	goto tr174;
case 210:
	switch( (*p) ) {
		case 38u: goto tr170;
		case 60u: goto tr171;
		case 93u: goto tr243;
		default: break;
	}
	goto tr169;
case 211:
	switch( (*p) ) {
		case 38u: goto tr170;
		case 60u: goto tr171;
		case 62u: goto tr1;
		case 93u: goto tr243;
		default: break;
	}
	goto tr169;
		default: break;
	}

	tr1: cs = 0; goto _again;
	tr0: cs = 2; goto _again;
	tr3: cs = 3; goto _again;
	tr4: cs = 4; goto _again;
	tr7: cs = 5; goto _again;
	tr9: cs = 6; goto _again;
	tr10: cs = 7; goto _again;
	tr11: cs = 8; goto _again;
	tr8: cs = 9; goto _again;
	tr12: cs = 10; goto _again;
	tr13: cs = 11; goto _again;
	tr14: cs = 12; goto _again;
	tr15: cs = 13; goto _again;
	tr16: cs = 14; goto _again;
	tr17: cs = 15; goto _again;
	tr18: cs = 16; goto _again;
	tr19: cs = 17; goto _again;
	tr20: cs = 18; goto _again;
	tr21: cs = 19; goto _again;
	tr25: cs = 20; goto _again;
	tr26: cs = 21; goto _again;
	tr28: cs = 22; goto _again;
	tr29: cs = 23; goto _again;
	tr30: cs = 24; goto _again;
	tr31: cs = 25; goto _again;
	tr33: cs = 26; goto _again;
	tr5: cs = 26; goto f0;
	tr36: cs = 27; goto _again;
	tr32: cs = 27; goto f1;
	tr34: cs = 28; goto _again;
	tr244: cs = 29; goto _again;
	tr40: cs = 30; goto _again;
	tr42: cs = 31; goto _again;
	tr43: cs = 32; goto _again;
	tr44: cs = 33; goto _again;
	tr41: cs = 34; goto _again;
	tr45: cs = 35; goto _again;
	tr47: cs = 36; goto _again;
	tr46: cs = 37; goto _again;
	tr48: cs = 38; goto _again;
	tr49: cs = 39; goto _again;
	tr51: cs = 40; goto _again;
	tr37: cs = 40; goto f0;
	tr53: cs = 41; goto _again;
	tr50: cs = 41; goto f4;
	tr54: cs = 42; goto _again;
	tr52: cs = 42; goto f4;
	tr55: cs = 43; goto _again;
	tr60: cs = 44; goto _again;
	tr57: cs = 44; goto f0;
	tr58: cs = 45; goto f5;
	tr61: cs = 45; goto f6;
	tr62: cs = 46; goto _again;
	tr59: cs = 46; goto f0;
	tr63: cs = 47; goto _again;
	tr65: cs = 48; goto _again;
	tr66: cs = 49; goto _again;
	tr67: cs = 50; goto _again;
	tr64: cs = 51; goto _again;
	tr56: cs = 52; goto _again;
	tr70: cs = 53; goto _again;
	tr68: cs = 53; goto f0;
	tr71: cs = 54; goto _again;
	tr69: cs = 54; goto f0;
	tr72: cs = 55; goto _again;
	tr74: cs = 56; goto _again;
	tr75: cs = 57; goto _again;
	tr76: cs = 58; goto _again;
	tr73: cs = 59; goto _again;
	tr27: cs = 60; goto _again;
	tr77: cs = 61; goto _again;
	tr79: cs = 62; goto _again;
	tr78: cs = 63; goto _again;
	tr80: cs = 64; goto _again;
	tr81: cs = 65; goto _again;
	tr23: cs = 66; goto _again;
	tr82: cs = 67; goto _again;
	tr83: cs = 68; goto _again;
	tr84: cs = 69; goto _again;
	tr85: cs = 70; goto _again;
	tr86: cs = 71; goto _again;
	tr87: cs = 72; goto _again;
	tr88: cs = 73; goto _again;
	tr90: cs = 74; goto _again;
	tr91: cs = 75; goto _again;
	tr92: cs = 76; goto _again;
	tr94: cs = 77; goto _again;
	tr22: cs = 78; goto _again;
	tr95: cs = 79; goto _again;
	tr93: cs = 80; goto _again;
	tr89: cs = 81; goto _again;
	tr24: cs = 82; goto _again;
	tr96: cs = 83; goto _again;
	tr97: cs = 84; goto _again;
	tr98: cs = 85; goto _again;
	tr99: cs = 86; goto _again;
	tr6: cs = 87; goto _again;
	tr100: cs = 88; goto _again;
	tr102: cs = 89; goto _again;
	tr101: cs = 90; goto _again;
	tr103: cs = 91; goto _again;
	tr104: cs = 92; goto _again;
	tr2: cs = 93; goto _again;
	tr105: cs = 94; goto _again;
	tr106: cs = 95; goto _again;
	tr107: cs = 96; goto _again;
	tr108: cs = 97; goto _again;
	tr109: cs = 98; goto _again;
	tr110: cs = 99; goto _again;
	tr111: cs = 100; goto _again;
	tr112: cs = 101; goto _again;
	tr113: cs = 102; goto _again;
	tr114: cs = 103; goto _again;
	tr115: cs = 104; goto _again;
	tr116: cs = 105; goto _again;
	tr117: cs = 106; goto _again;
	tr118: cs = 107; goto _again;
	tr120: cs = 108; goto _again;
	tr121: cs = 109; goto _again;
	tr122: cs = 110; goto _again;
	tr123: cs = 111; goto _again;
	tr124: cs = 112; goto _again;
	tr125: cs = 113; goto _again;
	tr127: cs = 114; goto _again;
	tr128: cs = 115; goto _again;
	tr129: cs = 116; goto _again;
	tr130: cs = 117; goto _again;
	tr131: cs = 118; goto _again;
	tr132: cs = 119; goto _again;
	tr133: cs = 120; goto _again;
	tr134: cs = 121; goto _again;
	tr135: cs = 122; goto _again;
	tr137: cs = 123; goto _again;
	tr138: cs = 124; goto _again;
	tr139: cs = 125; goto _again;
	tr126: cs = 126; goto _again;
	tr140: cs = 127; goto _again;
	tr141: cs = 128; goto _again;
	tr142: cs = 129; goto _again;
	tr143: cs = 130; goto _again;
	tr144: cs = 131; goto _again;
	tr145: cs = 132; goto _again;
	tr146: cs = 133; goto _again;
	tr147: cs = 134; goto _again;
	tr148: cs = 135; goto _again;
	tr149: cs = 136; goto _again;
	tr150: cs = 137; goto _again;
	tr152: cs = 138; goto _again;
	tr154: cs = 139; goto _again;
	tr155: cs = 140; goto _again;
	tr153: cs = 141; goto _again;
	tr156: cs = 142; goto _again;
	tr151: cs = 143; goto _again;
	tr157: cs = 144; goto _again;
	tr159: cs = 145; goto _again;
	tr158: cs = 146; goto _again;
	tr160: cs = 147; goto _again;
	tr136: cs = 148; goto _again;
	tr161: cs = 149; goto _again;
	tr119: cs = 150; goto _again;
	tr162: cs = 151; goto _again;
	tr163: cs = 152; goto _again;
	tr164: cs = 153; goto _again;
	tr169: cs = 155; goto _again;
	tr165: cs = 155; goto f0;
	tr178: cs = 156; goto _again;
	tr166: cs = 156; goto f7;
	tr170: cs = 156; goto f8;
	tr173: cs = 157; goto _again;
	tr175: cs = 158; goto _again;
	tr177: cs = 159; goto _again;
	tr205: cs = 159; goto f2;
	tr208: cs = 159; goto f3;
	tr179: cs = 160; goto _again;
	tr167: cs = 160; goto f7;
	tr171: cs = 160; goto f8;
	tr181: cs = 161; goto _again;
	tr185: cs = 162; goto _again;
	tr187: cs = 163; goto _again;
	tr188: cs = 164; goto _again;
	tr189: cs = 165; goto _again;
	tr186: cs = 166; goto _again;
	tr190: cs = 167; goto _again;
	tr191: cs = 168; goto _again;
	tr192: cs = 169; goto _again;
	tr193: cs = 170; goto _again;
	tr194: cs = 171; goto _again;
	tr195: cs = 172; goto _again;
	tr196: cs = 173; goto _again;
	tr182: cs = 174; goto _again;
	tr199: cs = 175; goto _again;
	tr197: cs = 175; goto f0;
	tr201: cs = 176; goto _again;
	tr198: cs = 176; goto f9;
	tr204: cs = 177; goto _again;
	tr183: cs = 177; goto f0;
	tr206: cs = 178; goto _again;
	tr203: cs = 178; goto f1;
	tr210: cs = 179; goto _again;
	tr207: cs = 179; goto f0;
	tr212: cs = 180; goto _again;
	tr209: cs = 180; goto f4;
	tr213: cs = 181; goto _again;
	tr211: cs = 181; goto f4;
	tr214: cs = 182; goto _again;
	tr219: cs = 183; goto _again;
	tr216: cs = 183; goto f0;
	tr217: cs = 184; goto f5;
	tr220: cs = 184; goto f6;
	tr221: cs = 185; goto _again;
	tr218: cs = 185; goto f0;
	tr222: cs = 186; goto _again;
	tr224: cs = 187; goto _again;
	tr225: cs = 188; goto _again;
	tr226: cs = 189; goto _again;
	tr223: cs = 190; goto _again;
	tr215: cs = 191; goto _again;
	tr229: cs = 192; goto _again;
	tr227: cs = 192; goto f0;
	tr230: cs = 193; goto _again;
	tr228: cs = 193; goto f0;
	tr231: cs = 194; goto _again;
	tr233: cs = 195; goto _again;
	tr234: cs = 196; goto _again;
	tr235: cs = 197; goto _again;
	tr232: cs = 198; goto _again;
	tr184: cs = 199; goto _again;
	tr236: cs = 200; goto _again;
	tr238: cs = 201; goto _again;
	tr237: cs = 202; goto _again;
	tr239: cs = 203; goto _again;
	tr240: cs = 204; goto _again;
	tr180: cs = 205; goto _again;
	tr241: cs = 206; goto _again;
	tr176: cs = 207; goto _again;
	tr242: cs = 208; goto _again;
	tr174: cs = 209; goto _again;
	tr172: cs = 210; goto _again;
	tr168: cs = 210; goto f0;
	tr243: cs = 211; goto _again;
	tr39: cs = 212; goto _again;
	tr35: cs = 212; goto f2;
	tr38: cs = 212; goto f3;
	tr200: cs = 213; goto f10;
	tr202: cs = 213; goto f11;

	f0: _acts = &_xml_parser_actions[1]; goto execFuncs;
	f6: _acts = &_xml_parser_actions[3]; goto execFuncs;
	f1: _acts = &_xml_parser_actions[5]; goto execFuncs;
	f9: _acts = &_xml_parser_actions[7]; goto execFuncs;
	f4: _acts = &_xml_parser_actions[9]; goto execFuncs;
	f3: _acts = &_xml_parser_actions[11]; goto execFuncs;
	f8: _acts = &_xml_parser_actions[13]; goto execFuncs;
	f11: _acts = &_xml_parser_actions[15]; goto execFuncs;
	f5: _acts = &_xml_parser_actions[17]; goto execFuncs;
	f7: _acts = &_xml_parser_actions[20]; goto execFuncs;
	f2: _acts = &_xml_parser_actions[23]; goto execFuncs;
	f10: _acts = &_xml_parser_actions[26]; goto execFuncs;

execFuncs:
	_nacts = *_acts++;
	while ( _nacts-- > 0 ) {
		switch ( *_acts++ ) {
	case 0:
#line 16 "xml.rl"
	{ mark = p;}
	break;
	case 1:
#line 43 "xml.rl"
	{
            if (_attribValue)
                _attribValue(mark[0..p-mark]);
            mark = null;
        }
	break;
	case 2:
#line 84 "xml.rl"
	{
            if (_startTag)
                _startTag(mark[0..p-mark]);
            mark = null;
        }
	break;
	case 3:
#line 89 "xml.rl"
	{
            if (_endTag)
                _endTag(mark[0..p-mark]);
            mark = null;
        }
	break;
	case 4:
#line 96 "xml.rl"
	{
            if (_attribName)
                _attribName(mark[0..p-mark]);
            mark = null;
        }
	break;
	case 5:
#line 106 "xml.rl"
	{
            {
            prepush();
        {stack[top++] = cs; cs = (xml_parser_en_parse_content); if (true) goto _again;}}
        }
	break;
	case 6:
#line 112 "xml.rl"
	{
            if (_innerText)
                _innerText(mark[0..p-mark]);
            mark = null;
        }
	break;
	case 7:
#line 120 "xml.rl"
	{
            {cs = stack[--top];{
            postpop();
        }if (true) goto _again;}
        }
	break;
#line 2957 "parser.d"
		default: break;
		}
	}
	goto _again;

_again:
	if ( cs == 0 )
		goto _out;
	if ( ++p != pe )
		goto _resume;
	_test_eof: {}
	_out: {}
	}
#line 155 "xml.rl"
    }

public:
    bool complete()
    {
        return cs >= xml_parser_first_final;
    }

    bool error()
    {
        return cs == xml_parser_error;
    }

private:
    void delegate(string) _startTag, _endTag, _attribName, _attribValue, _innerText;
}
