module mordor.common.streams.socket;

import tango.net.Socket;
import tango.util.log.Log;

import mordor.common.exception;
public import mordor.common.streams.stream;

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.common.streams.socket");
}

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

    void close(CloseType type = CloseType.BOTH)
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
    }

    size_t read(Buffer b, size_t len)
    {
        _log.trace("Receiving {} from socket {}", len, cast(void*)_s);
        int rc = _s.receive(b.writeBufs(len));
        _log.trace("Received {} from socket {}", rc, cast(void*)_s);
        if (rc < 0) {
            throw exceptionFromLastError();
        }
        b.produce(rc);
        return rc;
    }

    size_t write(Buffer b, size_t len)
    {
        int rc = _s.send(b.readBufs(len));
        if (rc == 0) {
            throw new ZeroLengthWriteException();
        } else if (rc < 0) {
            throw exceptionFromLastError();
        }
        return rc;
    }

private:
    Socket _s;
    bool _own;
}
