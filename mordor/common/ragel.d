module mordor.common.ragel;

import tango.core.Exception;

class RagelException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }
}

class RagelParser
{
    // Complete parsing
    void run(char[] str)
    {
        init();
        p = str.ptr;
        pe = p + str.length;
        pe = eof;

        exec();

        if (error) {
            return;
        }
        if (p == pe) {
            return;
        } else {
            init();
        }
    }
    
    // Partial parsing
    void init()
    {
        mark = null;
        fullString.length = 0;
    }

    final size_t run(char[] buffer, bool isEof)
    in
    {
        assert(!complete);
        assert(!error);
    }
    body
    {
        size_t markSpot = ~0;

        // Remember and reset mark in case fullString gets moved
        if (mark !is null) {
            markSpot = mark - fullString.ptr;
        }

        fullString ~= buffer;

        if (markSpot != ~0) {
            mark = fullString.ptr + markSpot;
        }

        p = fullString.ptr;
        pe = p + fullString.length;
        p = pe - buffer.length;
        if (isEof) {
            eof = pe;
        } else {
            eof = null;
        }

        exec();

        if (mark is null) {
            fullString.length = 0;
        } else {
            markSpot = mark - fullString.ptr;
            fullString = fullString[markSpot..$];
            mark = fullString.ptr;
        }

        return p - (pe - buffer.length); 
    }

    abstract bool error();
    abstract bool complete();
    
protected:
    abstract void exec();
    
protected:
    // Ragel state
    int cs;
    char* p, pe, eof, mark;
    char[] fullString;
}
