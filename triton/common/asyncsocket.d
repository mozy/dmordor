module triton.common.asyncsocket;

import tango.core.Exception;
import tango.core.Thread;
public import tango.net.socket;
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
            m_readEvent = new OverlappedEvent();
            m_writeEvent = new OverlappedEvent();
            super(family, type, protocol);
            g_ioManager.registerFile(cast(HANDLE)sock);
        }

        /+override Socket connect(Address to)
        {
            m_writeEvent.register();
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
            m_readEvent.register();
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
            m_writeEvent.register();
            int ret = WSASend(sock, &wsabuf, 1, NULL, cast(DWORD)flags,
                &m_writeEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_writeEvent.ret) {
                SetLastError(m_writeEvent.lastError);
                return tango.net.socket.SOCKET_ERROR;
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
            m_readEvent.register();
            int ret = WSARecv(sock, &wsabuf, 1, NULL, cast(DWORD*)&flags,
                &m_readEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_readEvent.ret) {
                SetLastError(m_readEvent.lastError);
                return tango.net.socket.SOCKET_ERROR;
            }
            return m_readEvent.numberOfBytes;
        }

    private:
        OverlappedEvent m_readEvent;
        OverlappedEvent m_writeEvent;
    }
} else {

}
