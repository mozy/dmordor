module mordor.common.streams.deflate;

import mordor.common.streams.zlib;

class DeflateStream : ZlibStream
{
    this(Stream parent, int level, int windowBits, int memlevel, Strategy strategy,
        bool ownsParent)
    {
        this(parent, ownsParent, Type.DEFLATE, level, windowBits, memlevel, strategy);
    }
    
    this(Stream parent, bool ownsParent = true)
    {
        this(parent, ownsParent, Type.DEFLATE);
    }
}
