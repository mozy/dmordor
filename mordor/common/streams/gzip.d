module mordor.common.streams.gzip;

import mordor.common.streams.zlib;

class GzipStream : ZlibStream
{
    this(Stream parent, int level, int windowBits, int memlevel, Strategy strategy,
        bool ownsParent)
    {
        super(parent, ownsParent, Type.GZIP, level, windowBits, memlevel, strategy);
    }
    
    this(Stream parent, bool ownsParent = true)
    {
        super(parent, ownsParent, Type.GZIP);
    }
}
