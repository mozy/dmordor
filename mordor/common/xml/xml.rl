/* To compile to .d:
   ragel xml.rl -D -G1 -o parser.d
*/

module mordor.common.xml.parser;

import mordor.common.ragel;
import mordor.common.stringutils;

class XmlParser : RagelParserWithStack
{
private:
    %%{    
        machine xml_parser;
    
        action mark { mark = fpc;}
        action done { fbreak; }
        prepush {
            prepush();
        }
        postpop {
            postpop();
        }
        
        Char = '\t' | '\n' | '\r' | [' '-255];
        S = (' ' | '\t' | '\r' | '\n')+;
    
        NameStartChar = ':' | [A-Z] | '_' | [a-z] | 0xC0..0xD6 | 0xD8..0xF6 | 0xF8..0xFF;
        NameChar = NameStartChar | '-' | '.' | [0-9] | 0xB7;
        Name = NameStartChar NameChar*;
        Names = Name (' ' Name)*;
        Nmtoken = NameChar+;
        Nmtokens = Nmtoken (' ' Nmtoken)*;
        
        CharData = [^<&]* - ([^<&]* ']]>' [^<&]*);
        
        CharRef = '&#' [0-9]+ ';' | '&#x' [0-9a-fA-F]+ ';';
        EntityRef = '&' Name ';';
        Reference = EntityRef | CharRef;
        PEReference = '%' Name ';';
        
        action attrib_value
        {
            if (_attribValue)
                _attribValue(mark[0..fpc-mark]);
            mark = null;
        }
        
        EntityValue = '"' ([^%&"] | PEReference | Reference)* '"' |
                      "'" ([^%&'] | PEReference | Reference)* '"';
        AttValue = '"' ([^<&"] | Reference)* >mark %attrib_value '"' |
                   "'" ([^<&'] | Reference)* >mark %attrib_value "'";
        SystemLiteral = ('"' [^"]* '"') | ("'" [^']* "'");
        PubidChar = ' ' | '\r' | '\n' | [a-zA-Z0-9] | ['()+,./:=?;!*#@$_%] | '-';
        PubidLiteral = '"' PubidChar* '"' | "'" (PubidChar* -- "'") "'";
        
        Comment = '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->';
        
        PITarget = Name - ([Xx][Mm][Ll]);
        PI = '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>';
    
        Misc = Comment | PI | S;
    
        Eq = S? '=' S?;
        VersionNum = '1.' [0-9]+;
        VersionInfo = S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"');
        EncName = [A-Za-z] ([A-Za-z0-9._] | '-')*;
        EncodingDecl = S 'encoding' Eq ('"' EncName '"' | "'" EncName "'");
        SDDecl = S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"'));
        XMLDecl = '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>';
        
        ExternalID = 'SYSTEM' S SystemLiteral | 'PUBLIC' S PubidLiteral S SystemLiteral;
        #markupdecl = elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment;
        #intSubset = (markupdecl | DeclSep)*;
        intSubset = '';
        doctypedecl = '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>';
        prolog = XMLDecl? Misc* (doctypedecl Misc*)?;
    
        CDStart = '<![CDATA[';
        CData = (Char* - (Char* ']]>' Char*));
        CDEnd = ']]>';
        CDSect = CDStart CData CDEnd;
        
        action start_tag {
            if (_startTag)
                _startTag(mark[0..fpc-mark]);
            mark = null;
        }
        action end_tag {
            if (_endTag)
                _endTag(mark[0..fpc-mark]);
            mark = null;
        }
        
        action attrib_name
        {
            if (_attribName)
                _attribName(mark[0..fpc-mark]);
            mark = null;
        }
    
        Attribute = Name >mark %attrib_name Eq AttValue;
        STag = '<' Name >mark %start_tag (S Attribute)* S? '>';
        ETag = '</' Name >mark %end_tag S? '>';
        EmptyElemTag = '<' Name (S Attribute)* S? '/>';
        action call_parse_content {
            fcall *xml_parser_en_parse_content;
        }
        element = EmptyElemTag | STag @call_parse_content; #content ETag;
    
        action inner_text
        {
            if (_innerText)
                _innerText(mark[0..fpc-mark]);
            mark = null;
        }
    
        content = CharData? >mark %inner_text ((element | Reference | CDSect | PI | Comment) CharData?)*;
    
        action element_finished {
            fret;
        }
        parse_content := parse_content_lbl: content ETag @element_finished;
    
        document = prolog element Misc*;

        main := document;
        write data;
    }%%

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
        %% write init;
    }

protected:
    void exec()
    {
        %% write exec;
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
