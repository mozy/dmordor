module mordor.common.streams.socket;

import tango.net.Socket;

public import mordor.common.streams.stream;

class SocketStream : Stream
{
public:
    this(Socket s, bool ownSocket = true)
    {
        _s = s;
        _own = ownSocket;
    }

    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    bool supportsEof() { return true; }

    result_t close(CloseType type)
    {        
        if (_s !is null && _own) {
            SocketShutdown socketShutdown;
            switch (type) {
                case CloseType.READ:
                    socketShutdown = SocketShutdown.RECEIVE;
                    break;
                case CloseType.WRITE:
                    socketShutdown = SocketShutdown.SEND;
                    break;
                default:
                    socketShutdown = SocketShutdown.BOTH;
                    break;
            }
            if (socketShutdown == SocketShutdown.BOTH) {
                _s.shutdown(socketShutdown);
                _s.detach();
                _s = null;
            } else {
                _s.shutdown(socketShutdown);
            }
        }
        return 0;
    }

    result_t read(Buffer b, size_t len)
    {
        int rc = _s.receive(b.writeBufs(len));
        if (rc == 0) {
            _eof = true;
        }
        if (rc > 0) {
            b.produce(rc);
        }
        return rc;
    }

    result_t write(Buffer b, size_t len)
    {
        return _s.send(b.readBufs(len));
    }
    
    result_t eof()
    {
        return _eof ? 0 : 1;
    }

private:
    Socket _s;
    bool _own;
    bool _eof;
}
