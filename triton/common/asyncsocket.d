module triton.common.asyncsocket;

import tango.core.Exception;
import tango.core.Thread;
public import tango.net.Socket;
import tango.io.Stdout;

import triton.common.iomanager;

version (Windows) {
    import win32.basetyps;
    import win32.mswsock;
    import win32.winbase;
    import win32.windef;
    import win32.winsock2;

    const LPFN_ACCEPTEX AcceptEx;
    const LPFN_CONNECTEX ConnectEx;

    extern (Windows) {
        private BOOL AcceptExNotImpl(
            SOCKET sListenSocket,
            SOCKET sAcceptSocket,
            PVOID lpOutputBuffer,
            DWORD dwReceiveDataLength,
            DWORD dwLocalAddressLength,
            DWORD dwRemoteAddressLength,
            LPDWORD lpdwBytesReceived,
            LPOVERLAPPED lpOverlapped)
        {
            SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
            return FALSE;
        }

        private BOOL ConnectExNotImpl(
            SOCKET s,
            SOCKADDR* name,
            int nameLen,
            PVOID lpSendBuffer,
            DWORD dwSendDataLength,
            LPDWORD lpdwByesSent,
            LPOVERLAPPED lpOverlapped)
        {
            SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
            return FALSE;
        }
    }
    
    static this()
    {
        AcceptEx = &AcceptExNotImpl;
        ConnectEx = &ConnectExNotImpl;

        Socket s = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);

        DWORD bytes = 0;
        WSAIoctl(s.sock,
            SIO_GET_EXTENSION_FUNCTION_POINTER,
            &WSAID_ACCEPTEX,
            WSAID_ACCEPTEX.sizeof,
            &AcceptEx,
            AcceptEx.sizeof,
            &bytes,
            NULL,
            NULL);
        Stdout.format("Got acceptex: {}", bytes);
        WSAIoctl(s.sock,
            SIO_GET_EXTENSION_FUNCTION_POINTER,
            &WSAID_CONNECTEX,
            WSAID_CONNECTEX.sizeof,
            &ConnectEx,
            ConnectEx.sizeof,
            &bytes,
            NULL,
            NULL);

        delete s;
    }

    class AsyncSocket : Socket
    {
    public:
        this(AddressFamily family, SocketType type, ProtocolType protocol)
        {
            super(family, type, protocol);
            g_ioManager.registerFile(cast(HANDLE)sock);
        }

        /+override Socket connect(Address to)
        {
            g_ioManager.registerEvent(m_writeEvent);
            if (!ConnectEx(sock, to.name(), to.nameLen(), NULL, 0, NULL, &m_writeEvent.overlapped)) {
                if (GetLastError() != WSA_IO_PENDING) {
                    exception("Unable to connect socket: ");
                }
            }
            Fiber.yield();
            if (!m_writeEvent.ret) {
                SetLastError(m_writeEvent.lastError);
                exception("Unable to connect socket: ");
            }
            return this;
        }+/

        override Socket accept()
        {
            return accept(new AsyncSocket(family, type, protocol));
        }

        override Socket accept (Socket target)
        {
            g_ioManager.registerEvent(&m_readEvent);
            void[] addrs = new void[64];
            DWORD bytes;
            Stdout.format("accepting: {} {} {} {}\r\n", addrs.ptr, addrs.length, &bytes, &m_readEvent.overlapped);
            BOOL ret = AcceptEx(sock, target.sock, addrs.ptr, addrs.length, (addrs.length - 16) / 2, (addrs.length - 16) / 2, &bytes,
                &m_readEvent.overlapped);
            if (!ret && GetLastError() != WSA_IO_PENDING) {
                Stdout.format("accept ex: {}, {}, {}, {}", ret, GetLastError(), sock, target.sock);
                exception(
                    "Unable to accept socket connection");
            }
            Fiber.yield();
            if (!m_readEvent.ret && m_readEvent.lastError != ERROR_MORE_DATA) {
                SetLastError(m_readEvent.lastError);
                throw new SocketAcceptException(
                    "Unable to accept socket connection");
            }

            // TODO: inherit properties
            return target;
        }

        override int send(void[] buf, SocketFlags flags=SocketFlags.NONE)
        {
            WSABUF wsabuf;
            wsabuf.buf = cast(char*)buf.ptr;
            wsabuf.len = buf.length;
            g_ioManager.registerEvent(&m_writeEvent);
            int ret = WSASend(sock, &wsabuf, 1, NULL, cast(DWORD)flags,
                &m_writeEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_writeEvent.ret) {
                SetLastError(m_writeEvent.lastError);
                return tango.net.Socket.SOCKET_ERROR;
            }
            return m_writeEvent.numberOfBytes;
        }

        override int receive(void[] buf, SocketFlags flags=SocketFlags.NONE)
        {
            if (!buf.length)
                badArg ("Socket.receive :: target buffer has 0 length");

            WSABUF wsabuf;
            wsabuf.buf = cast(char*)buf.ptr;
            wsabuf.len = buf.length;
            g_ioManager.registerEvent(&m_readEvent);
            int ret = WSARecv(sock, &wsabuf, 1, NULL, cast(DWORD*)&flags,
                &m_readEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_readEvent.ret) {
                SetLastError(m_readEvent.lastError);
                return tango.net.Socket.SOCKET_ERROR;
            }
            return m_readEvent.numberOfBytes;
        }

    private:
        AsyncEvent m_readEvent;
        AsyncEvent m_writeEvent;
    }
} else version(linux) {
    import tango.stdc.errno;
    import tango.sys.linux.epoll;

    class AsyncSocket : Socket
    {
    public:
        this(AddressFamily family, SocketType type, ProtocolType protocol, bool create=true)
        {
            m_readEvent.event.events = EPOLLIN;
            m_writeEvent.event.events = EPOLLOUT;
            super(family, type, protocol, create);
            if (create) {
                m_readEvent.event.data.fd = sock;
                m_writeEvent.event.data.fd = sock;
                blocking = false;
            }
        }

        override void blocking(bool byes)
        {
            if (byes == false) {
                super.blocking = false;
            }
        }

        override void reopen(socket_t sock = sock.init)
        {
            super.reopen(sock);
            m_readEvent.event.data.fd = this.sock;
            m_writeEvent.event.data.fd = this.sock;
            blocking = false;
        }

        override Socket connect(Address to)
        {
            super.connect(to);
            if (errno == EINPROGRESS) {
                g_ioManager.registerEvent(&m_writeEvent);
                Fiber.yield();
                int err;
                getOption(SocketOptionLevel.SOCKET, SocketOption.SO_ERROR, (cast(void*)&err)[0..int.sizeof]);
                if (err != 0) {
                    errno = err;
                    exception ("Unable to connect socket: ");
                }
            }
            return this;
        }

        override Socket accept()
        {
            return accept(new AsyncSocket(family, type, protocol, false));
        }

        override Socket accept (Socket target)
        {
            Stdout.formatln("accepting on socket {}", sock);
            socket_t newsock = .accept(sock, null, null);
            while (newsock == socket_t.init && errno == EAGAIN) {
                g_ioManager.registerEvent(&m_readEvent);
                Fiber.yield();
                newsock = .accept(sock, null, null);
            }
            if (newsock == socket_t.init) {
                exception("Unable to accept socket connection: ");
            }

            target.reopen(newsock);

            target.protocol = protocol;
            target.family = family;
            target.type = type;

            return target;
        }

        override int send(void[] buf, SocketFlags flags=SocketFlags.NONE)
        {
            int rc = super.send(buf, flags);
            while (rc == ERROR && errno == EAGAIN) {
                g_ioManager.registerEvent(&m_writeEvent);
                Fiber.yield();
                rc = super.send(buf, flags);
            }
            return rc;
        }

        override int receive(void[] buf, SocketFlags flags=SocketFlags.NONE)
        {
            int rc = super.receive(buf, flags);
            while (rc == ERROR && errno == EAGAIN) {
                g_ioManager.registerEvent(&m_readEvent);
                Fiber.yield();
                rc = super.receive(buf, flags);
            }
            return rc;
        }

    private:
        AsyncEvent m_readEvent;
        AsyncEvent m_writeEvent;
    }
}
