module mordor.common.streams.socket;

import mordor.common.asyncsocket;

public import mordor.common.streams.stream;

class SocketStream : Stream
{
public:
    this(AsyncSocket s, bool ownSocket = true)
    {
        _s = s;
        _own = ownSocket;
    }

    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    bool supportsEof() { return true; }

    result_t close()
    {
        if (_s !is null && _own) {
            _s.detach();
            _s = null;
        }
        return 0;
    }

    result_t read(ref Buffer b, size_t len)
    {
        int rc = _s.receive(b.writeBuf(len));
        if (rc == 0) {
            _eof = true;
        }
        if (rc > 0) {
            b.produce(rc);
        }
        return cast(result_t)rc;
    }

    result_t write(Buffer b, size_t len)
    {
        return cast(result_t)_s.send(b.readBuf(len));
    }
    
    result_t eof()
    {
        return _eof ? 0 : 1;
    }

private:
    AsyncSocket _s;
    bool _own;
    bool _eof;
}
