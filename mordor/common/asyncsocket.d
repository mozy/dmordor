module mordor.common.asyncsocket;

import tango.core.Exception;
import tango.core.Thread;
public import tango.net.Socket;
import tango.io.Stdout;

import mordor.common.iomanager;

version(linux) {
    version = epoll;
}
version(darwin) {
    version = kqueue;
}

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
} else version (Posix) {
    import tango.stdc.errno;
    version (epoll) import tango.sys.linux.epoll;

    struct iovec {
        void*  iov_base;
        size_t iov_len;
    }

    struct msghdr {
         void*         msg_name;
         int           msg_namelen;
         iovec*        msg_iov;
         size_t        msg_iovlen;
         void*         msg_control;
         int           msg_controllen;
         int           msg_flags;
    }

    extern (C) {
        int sendmsg(int s, msghdr *msg, int flags);
        int recvmsg(int s, msghdr *msg, int flags);
    }
}

class AsyncSocket : Socket
{
public:
    this(IOManager mgr, AddressFamily family, SocketType type, ProtocolType protocol, bool create = true)
    {
        version (Windows) {
            // Must always create the socket on Windows
            create = true;
        }
        _ioManager = mgr;
        super(family, type, protocol, create);
        version (Windows) {
            _ioManager.registerFile(cast(HANDLE)sock);
        } else version (epoll) {
            m_readEvent.event.events = EPOLLIN;
            m_writeEvent.event.events = EPOLLOUT;
        } else version (kqueue) {
            m_readEvent.event.filter = EVFILT_READ;
            m_writeEvent.event.filter = EVFILT_WRITE;
        }
        version (Posix) {
            if (create) {
                version (epoll) {
                    m_readEvent.event.data.fd = sock;
                    m_writeEvent.event.data.fd = sock;
                } else version (kqueue) {
                    m_readEvent.event.ident = sock;
                    m_writeEvent.event.ident = sock;
                }
                blocking = false;
            }
        }
    }
    
    version (Posix) {
        override void blocking(bool byes)
        {
            if (byes == false) {
                super.blocking = false;
            }
        }
        
        void reopen(socket_t sock = sock.init)
        {
            super.reopen(sock);
            version (epoll) {
                m_readEvent.event.data.fd = this.sock;
                m_writeEvent.event.data.fd = this.sock;
            } else version (kqueue) {
                m_readEvent.event.ident = this.sock;
                m_writeEvent.event.ident = this.sock;
            }
            blocking = false;
        }
    }

    override Socket connect(Address to)
    {
        version (Windows) {
            // Need to be bound, even to ADDR_ANY, before calling ConnectEx
            bind(newFamilyObject());
            _ioManager.registerEvent(&m_writeEvent);
            if (!ConnectEx(sock, cast(SOCKADDR*)to.name(), to.nameLen(), NULL, 0, NULL, &m_writeEvent.overlapped)) {
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
        } else version (Posix) {
            super.connect(to);
            if (errno == EINPROGRESS) {
                _ioManager.registerEvent(&m_writeEvent);
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
    }

    override Socket accept()
    {
        version (Windows) {
            return accept(new AsyncSocket(_ioManager, family, type, protocol));
        } else version (Posix) {
            return accept(new AsyncSocket(_ioManager, family, type, protocol, false));
        }
    }

    override Socket accept (Socket target)
    {
        version (Windows) {
            _ioManager.registerEvent(&m_readEvent);
            void[] addrs = new void[64];
            DWORD bytes;
            BOOL ret = AcceptEx(sock, target.sock, addrs.ptr, addrs.length, (addrs.length - 16) / 2, (addrs.length - 16) / 2, &bytes,
                &m_readEvent.overlapped);
            if (!ret && GetLastError() != WSA_IO_PENDING) {
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
        } else version (Posix) {
            socket_t newsock = .accept(sock, null, null);
            while (newsock == socket_t.init && errno == EAGAIN) {
                _ioManager.registerEvent(&m_readEvent);
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
    }

    override int send(void[] buf, SocketFlags flags=SocketFlags.NONE)
    {
        version (Windows) {
            WSABUF wsabuf;
            wsabuf.buf = cast(char*)buf.ptr;
            wsabuf.len = buf.length;
            _ioManager.registerEvent(&m_writeEvent);
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
        } else version (Posix) {
            int rc = super.send(buf, flags);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_writeEvent);
                Fiber.yield();
                rc = super.send(buf, flags);
            }
            return rc;
        }
    }

    int send(void[][] bufs, SocketFlags flags=SocketFlags.NONE)
    {
        version (Windows) {
            WSABUF[] wsabufs = new WSABUF[bufs.length];
            foreach (i, buf; bufs) {
                wsabufs[i].buf = cast(char*)buf.ptr;
                wsabufs[i].len = buf.length;
            }
            _ioManager.registerEvent(&m_writeEvent);
            int ret = WSASend(sock, wsabufs.ptr, wsabufs.length, NULL,
                cast(DWORD)flags, &m_writeEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_writeEvent.ret) {
                SetLastError(m_writeEvent.lastError);
                return ERROR;
            }
            return m_writeEvent.numberOfBytes;
        } else version (Posix) {
            msghdr msg;
            iovec[] iovs = new iovec[bufs.length];
            foreach (i, buf; bufs) {
                iovs[i].iov_base = buf.ptr;
                iovs[i].iov_len = buf.length;
            }
            msg.msg_iov = iovs.ptr;
            msg.msg_iovlen = iovs.length;
            int rc = sendmsg(sock, &msg, cast(int)flags);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_writeEvent);
                Fiber.yield();
                rc = sendmsg(sock, &msg, cast(int)flags);
            }
            return rc;
        }
    }

    override int sendTo(void[] buf, SocketFlags flags, Address to)
    {
        version (Windows) {
            WSABUF wsabuf;
            wsabuf.buf = cast(char*)buf.ptr;
            wsabuf.len = buf.length;
            _ioManager.registerEvent(&m_writeEvent);
            int ret = WSASendTo(sock, &wsabuf, 1, NULL, cast(DWORD)flags,
                cast(SOCKADDR*)to.name(), to.nameLen(),
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
        } else version (Posix) {
            int rc = super.sendTo(buf, flags, to);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_writeEvent);
                Fiber.yield();
                rc = super.send(buf, flags);
            }
            return rc;
        }
    }

    int sendTo(void[][] bufs, SocketFlags flags, Address to)
    {
        version (Windows) {
            WSABUF[] wsabufs = new WSABUF[bufs.length];
            foreach (i, buf; bufs) {
                wsabufs[i].buf = cast(char*)buf.ptr;
                wsabufs[i].len = buf.length;
            }
            _ioManager.registerEvent(&m_writeEvent);
            int ret = WSASendTo(sock, wsabufs.ptr, wsabufs.length, NULL,
                cast(DWORD)flags, cast(SOCKADDR*)to.name(), to.nameLen(),
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
        } else version (Posix) {
            msghdr msg;
            msg.msg_name = to.name();
            msg.msg_namelen = to.nameLen();
            iovec[] iovs = new iovec[bufs.length];
            foreach (i, buf; bufs) {
                iovs[i].iov_base = buf.ptr;
                iovs[i].iov_len = buf.length;
            }
            msg.msg_iov = iovs.ptr;
            msg.msg_iovlen = iovs.length;
            int rc = sendmsg(sock, &msg, cast(int)flags);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_writeEvent);
                Fiber.yield();
                rc = sendmsg(sock, &msg, cast(int)flags);
            }
            return rc;
        }
    }

    int sendTo(void[][] bufs, Address to)
    {
        return sendTo(bufs, SocketFlags.NONE, to);
    }

    int sendTo(void[][] bufs, SocketFlags flags=SocketFlags.NONE)
    {
        return send(bufs, flags);
    }

    override int receive(void[] buf, SocketFlags flags=SocketFlags.NONE)
    {
        version (Windows) {
            if (!buf.length)
                badArg ("Socket.receive :: target buffer has 0 length");

            WSABUF wsabuf;
            wsabuf.buf = cast(char*)buf.ptr;
            wsabuf.len = buf.length;
            _ioManager.registerEvent(&m_readEvent);
            int ret = WSARecv(sock, &wsabuf, 1, NULL, cast(DWORD*)&flags,
                &m_readEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_readEvent.ret) {
                SetLastError(m_readEvent.lastError);
                return ERROR;
            }
            return m_readEvent.numberOfBytes;
        } else version (Posix) {
            int rc = super.receive(buf, flags);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_readEvent);
                Fiber.yield();
                rc = super.receive(buf, flags);
            }
            return rc;
        }
    }

    int receive(void[][] bufs, SocketFlags flags=SocketFlags.NONE)
    {
        version (Windows) {
            if (!bufs.length)
                badArg ("Socket.receive :: target buffer has 0 length");

            WSABUF[] wsabufs = new WSABUF[bufs.length];
            foreach (i, buf; bufs) {
                if (!buf.length)
                    badArg ("Socket.receive :: target buffer has 0 length");
                wsabufs[i].buf = cast(char*)buf.ptr;
                wsabufs[i].len = buf.length;
            }
            _ioManager.registerEvent(&m_readEvent);
            int ret = WSARecv(sock, wsabufs.ptr, wsabufs.length, NULL,
                cast(DWORD*)&flags, &m_readEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_readEvent.ret) {
                SetLastError(m_readEvent.lastError);
                return tango.net.Socket.SOCKET_ERROR;
            }
            return m_readEvent.numberOfBytes;
        } else version (Posix) {
            if (!bufs.length)
                badArg ("Socket.receive :: target buffer has 0 length");

            msghdr msg;
            iovec[] iovs = new iovec[bufs.length];
            foreach (i, buf; bufs) {
                if (!buf.length)
                    badArg ("Socket.receive :: target buffer has 0 length");
                iovs[i].iov_base = buf.ptr;
                iovs[i].iov_len = buf.length;
            }
            msg.msg_iov = iovs.ptr;
            msg.msg_iovlen = iovs.length;
            int rc = recvmsg(sock, &msg, cast(int)flags);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_readEvent);
                Fiber.yield();
                rc = recvmsg(sock, &msg, cast(int)flags);
            }
            return rc;
        }
    }

    override int receiveFrom(void[] buf, SocketFlags flags, Address from)
    {
        version (Windows) {
            if (!buf.length)
                badArg ("Socket.receiveFrom :: target buffer has 0 length");

            WSABUF wsabuf;
            wsabuf.buf = cast(char*)buf.ptr;
            wsabuf.len = buf.length;
            int nameLen = from.nameLen();
            _ioManager.registerEvent(&m_readEvent);
            int ret = WSARecvFrom(sock, &wsabuf, 1, NULL, cast(DWORD*)&flags,
                cast(SOCKADDR*)from.name(), &nameLen,
                &m_readEvent.overlapped, NULL);
            if (ret && GetLastError() != WSA_IO_PENDING) {
                return ret;
            }
            Fiber.yield();
            if (!m_readEvent.ret) {
                SetLastError(m_readEvent.lastError);
                return ERROR;
            }
            return m_readEvent.numberOfBytes;
        } else version (Posix) {
            int rc = super.receiveFrom(buf, flags, from);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_readEvent);
                Fiber.yield();
                rc = super.receiveFrom(buf, flags, from);
            }
            return rc;   
        }
    }

    int receiveFrom(void[][] bufs, SocketFlags flags, Address from)
    {
        version (Windows) {
            if (!bufs.length)
                badArg ("Socket.receiveFrom :: target buffer has 0 length");

            WSABUF[] wsabufs = new WSABUF[bufs.length];
            foreach (i, buf; bufs) {
                if (!buf.length)
                    badArg ("Socket.receiveFrom :: target buffer has 0 length");
                wsabufs[i].buf = cast(char*)buf.ptr;
                wsabufs[i].len = buf.length;
            }
            int nameLen = from.nameLen();
            _ioManager.registerEvent(&m_readEvent);
            int ret = WSARecvFrom(sock, wsabufs.ptr, wsabufs.length, NULL,
                cast(DWORD*)&flags, cast(SOCKADDR*)from.name(), &nameLen,
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
        } else version (Posix) {
            if (!bufs.length)
                badArg ("Socket.receive :: target buffer has 0 length");

            msghdr msg;
            msg.msg_name = from.name();
            msg.msg_namelen = from.nameLen();
            iovec[] iovs = new iovec[bufs.length];
            foreach (i, buf; bufs) {
                if (!buf.length)
                    badArg ("Socket.receive :: target buffer has 0 length");
                iovs[i].iov_base = buf.ptr;
                iovs[i].iov_len = buf.length;
            }
            msg.msg_iov = iovs.ptr;
            msg.msg_iovlen = iovs.length;
            int rc = recvmsg(sock, &msg, cast(int)flags);
            while (rc == ERROR && errno == EAGAIN) {
                _ioManager.registerEvent(&m_readEvent);
                Fiber.yield();
                rc = recvmsg(sock, &msg, cast(int)flags);
            }
            return rc;
        }
    }

    int receiveFrom(void[][] bufs, Address from)
    {
        return receiveFrom(bufs, SocketFlags.NONE, from);
    }

    int receiveFrom(void[][] bufs, SocketFlags flags = SocketFlags.NONE)
    {
        return receive(bufs, flags);
    }

private:
    IOManager _ioManager;
    AsyncEvent m_readEvent;
    AsyncEvent m_writeEvent;
}

