module mordor.common.streams.zlib;

import tango.core.Exception;
import tango.io.compress.c.zlib;
import tango.stdc.stringz;
import tango.util.log.Log;

import mordor.common.exception;
import mordor.common.streams.buffered;
public import mordor.common.streams.filter;

pragma (lib, "zlib");
version (build) pragma (link, "z");

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.common.streams.zlib");
}

class ZlibStream : FilterStream
{
public:
    enum Strategy {
        DEFAULT = Z_DEFAULT_STRATEGY,
        FILTERED = Z_FILTERED,
        HUFFMAN = Z_HUFFMAN_ONLY,
        FIXED = Z_FIXED,
        RLE = Z_RLE
    }
protected:
    enum Type {
        ZLIB,
        DEFLATE,
        GZIP
    }

    this(Stream parent, bool ownsParent, Type type, int level = Z_DEFAULT_COMPRESSION,
        int windowBits = 15, int memlevel = 8, Strategy strategy = Strategy.DEFAULT)
    in
    {
        assert(parent !is null);
        assert(parent.supportsRead || parent.supportsWrite);
        assert(!(parent.supportsRead && parent.supportsWrite));
        assert(level >= 0 && level <= 9 || level == Z_DEFAULT_COMPRESSION);
        assert(windowBits >= 8 && windowBits <= 15);
        assert(memlevel >= 1 && memlevel <= 9);
    }
    body
    {
        super(parent, ownsParent);
        _inbuffer = new Buffer; _outbuffer = new Buffer;
        switch (type) {
            case Type.ZLIB:
                break;
            case Type.DEFLATE:
                windowBits = -windowBits;
                break;
            case Type.GZIP:
                windowBits += 16;
                break;
        }
        int ret;
        if (supportsRead) {
            ret = inflateInit2(&_strm, windowBits);
            _log.trace("Initializing inflate stream: {}", ret);
        } else {
            ret = deflateInit2(&_strm, level, Z_DEFLATED, windowBits, memlevel, cast(int)strategy);
        }
        switch (ret) {
            case Z_OK:
                break;
            case Z_MEM_ERROR:
                throw cast(OutOfMemoryException)cast(void*)OutOfMemoryException.init;
            case Z_STREAM_ERROR:
                throw new IllegalArgumentException(fromStringz(_strm.msg));
        }
    }
   
public:
    this(Stream parent, int level, int windowBits, int memlevel, Strategy strategy,
        bool ownsParent)
    {
        this(parent, ownsParent, Type.ZLIB, level, windowBits, memlevel, strategy);
    }
    
    this(Stream parent, bool ownsParent = true)
    {
        this(parent, ownsParent, Type.ZLIB);
    }
    
    ~this()
    {
        if (!_closed) {
            if (supportsRead) {
                inflateEnd(&_strm);
            } else {
                deflateEnd(&_strm);
            }
        }
    }
    
    bool supportsSeek() { return false; }
    bool supportsSize() { return false; }
    bool supportsTruncate() { return false; }
    
    void close(CloseType type = CloseType.BOTH)
    {
        if (type == CloseType.READ && supportsWrite ||
            type == CloseType.WRITE && supportsRead ||
            _closed) {
            super.close(type);
            return;
        }

        if (supportsRead) {
            inflateEnd(&_strm);
        } else {
            flush(Z_FINISH);
            deflateEnd(&_strm);
        }
        _closed = true;
        super.close(type);
    }
    
    size_t read(Buffer b, size_t len)
    {
        if (_closed)
            return 0;
        b.reserve(len);
        void[] outbuf = b.writeBufs(len)[0];
        _strm.next_out = cast(ubyte*)outbuf.ptr;
        scope (exit) _strm.next_out = null;
        _strm.avail_out = outbuf.length;
        
        while (true) {
            void[][] inbufs = _inbuffer.readBufs;
            size_t avail_in;
            if (inbufs.length > 0) {
                _strm.next_in = cast(ubyte*)inbufs[0].ptr;
                _strm.avail_in = avail_in = inbufs[0].length;
            } else {
                _strm.next_in = null;
                _strm.avail_in = 0;
            }
            int ret = inflate(&_strm, Z_NO_FLUSH);
            _log.trace("Inflate: {}, input/output provide: {}/{}, remaining: {}/{}",
                ret, avail_in, outbuf.length, _strm.avail_in, _strm.avail_out);
            if (inbufs.length > 0) {
                _inbuffer.consume(inbufs[0].length - _strm.avail_in);
            }
            switch(ret) {
                case Z_STREAM_END:
                    // May have still produced output
                    size_t result = outbuf.length - _strm.avail_out;
                    b.produce(result);
                    inflateEnd(&_strm);
                    _closed = true;
                    return result;
                case Z_OK:
                    size_t result = outbuf.length - _strm.avail_out;
                    // It consumed input, but produced no output... DON'T return eof
                    if (result == 0)
                        continue;
                    b.produce(result);
                    return result;
                case Z_BUF_ERROR:
                    // no progress... we need to provide more input (since we're
                    // guaranteed to provide output)
                    assert(_strm.avail_in == 0);
                    assert(inbufs.length == 0);
                    size_t result = super.read(_inbuffer, _bufferSize);
                    if (result == 0) {
                        throw new UnexpectedEofException();
                    }
                    break;
                default:
                    throw new PlatformException("zlib error");
            }
        }        
    }
    
    size_t write(Buffer b, size_t len)
    {
        if (_closed)
            throw new StreamClosedException();
        flushBuffer();
        while (true) {
            if (_outbuffer.writeAvailable == 0)
                _outbuffer.reserve(_bufferSize);
            void[] inbuf = b.readBufs[0];
            void[] outbuf = _outbuffer.writeBufs[0];
            _strm.next_in = cast(ubyte*)inbuf.ptr;
            _strm.avail_in = inbuf.length;
            scope (exit) _strm.next_in = null;
            _strm.next_out = cast(ubyte*)outbuf.ptr;
            _strm.avail_out = outbuf.length;
            scope (exit) _strm.next_out = null;            
            int ret = deflate(&_strm, Z_NO_FLUSH);
            _outbuffer.produce(outbuf.length - _strm.avail_out);
            // We are always providing both input and output
            assert(ret != Z_BUF_ERROR);
            // We're not doing Z_FINISH, so we shouldn't get EOF
            assert(ret != Z_STREAM_END);
            switch (ret) {                    
                case Z_OK:
                    size_t result = inbuf.length - _strm.avail_in;
                    if (result == 0)
                        continue;
                    try {
                        flushBuffer();
                    } catch (PlatformException ex) {
                        // Swallow it
                    }
                    return result;
                default:
                    throw new PlatformException("zlib error");
            }
        }
    }
    
    void flush()
    {
        flush(Z_SYNC_FLUSH);
        super.flush();
    }
    
private:    
    void flush(int flush)
    {
        flushBuffer();
        while (true) {
            if (_outbuffer.writeAvailable == 0)
                _outbuffer.reserve(_bufferSize);
            void[] outbuf = _outbuffer.writeBufs[0];
            _strm.next_out = cast(ubyte*)outbuf.ptr;
            _strm.avail_out = outbuf.length;
            scope (exit) _strm.next_out = null;            
            int ret = deflate(&_strm, flush);
            _outbuffer.produce(outbuf.length - _strm.avail_out);
            assert(flush == Z_FINISH || ret != Z_STREAM_END);
            switch (ret) {
                case Z_STREAM_END:
                    _closed = true;
                    deflateEnd(&_strm);
                    flushBuffer();
                    return;
                case Z_OK:
                    break;
                case Z_BUF_ERROR:
                    flushBuffer();
                    return;
                default:
                    throw new PlatformException("zlib error");
            }
        }
    }
    
    void flushBuffer()
    {
        while (_outbuffer.readAvailable > 0) {
            _outbuffer.consume(super.write(_outbuffer, _outbuffer.readAvailable));
        }
    }
    
private:
    size_t _bufferSize = 64 * 1024;
    Buffer _inbuffer, _outbuffer;
    z_stream _strm;
    bool _closed;
}
