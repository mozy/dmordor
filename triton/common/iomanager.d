module triton.common.iomanager;

import tango.core.Thread;
import tango.io.Stdout;

public import triton.common.scheduler;

version(Windows)
{
    import win32.winbase;
    import win32.windef;

    class IOManager : Scheduler
    {
    public:
        this(int threads = 1)
        {
            m_hCompletionPort = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 0);
            super("IOManager", threads);
        }

        void registerFile(HANDLE handle)
        {
            HANDLE hRet = CreateIoCompletionPort(handle, m_hCompletionPort, 0, 0);
            if (hRet != m_hCompletionPort) {
                throw new Exception("Couldn't associate handle with completion port.");
            }
        }

        void registerEvent(AsyncEvent* e)
        {
            e._fiber = Fiber.getThis;
            synchronized (this) {
                assert(!(&e.overlapped in m_pendingEvents));
                m_pendingEvents[&e.overlapped] = e;
            }
        }

    protected:
        void idle()
        {
            DWORD numberOfBytes;
            ULONG_PTR completionKey;
            OVERLAPPED* overlapped;
            while (true) {
                //Stdout.formatln("in idle");
                BOOL ret = GetQueuedCompletionStatus(m_hCompletionPort,
                    &numberOfBytes, &completionKey, &overlapped, INFINITE);
                //Stdout.formatln("Got IO status: {} {} {} {} {}", ret, GetLastError(), completionKey, numberOfBytes, overlapped);

                if (ret && completionKey == ~0) {
                    Fiber.yield();
                    continue;
                }
                if (!ret && overlapped == NULL) {
                    throw new Exception("Fail!");
                }
                AsyncEvent* e;
                
                synchronized (this) {
                    e = m_pendingEvents[overlapped];
                    m_pendingEvents.remove(overlapped);
                }

                e.ret = ret;
                e.numberOfBytes = numberOfBytes;
                e.completionKey = completionKey;
                e.lastError = GetLastError();
                schedule(e._fiber);
                Fiber.yield();
            }
        }

        void tickle()
        {
            PostQueuedCompletionStatus(m_hCompletionPort, 0, ~0, NULL);
        }

    private:
        HANDLE m_hCompletionPort;
        AsyncEvent*[OVERLAPPED*] m_pendingEvents;
    }

    struct AsyncEvent
    {
    public:
        BOOL ret;
        OVERLAPPED overlapped;
        DWORD numberOfBytes;
        ULONG_PTR completionKey;
        DWORD lastError;

    private:
        Fiber _fiber;
    };
} else version(linux) {
    import tango.stdc.posix.unistd;
    import tango.sys.linux.epoll;

    class IOManager : Scheduler
    {
    public:
        this(int threads = 1)
        {
            m_epfd = epoll_create(5000);
            pipe(m_tickleFds);
            Stdout.formatln("EPoll FD: {}, pipe fds: {} {}", m_epfd, m_tickleFds[0], m_tickleFds[1]);
            epoll_event event;
            event.events = EPOLLIN;
            event.data.fd = m_tickleFds[0];
            epoll_ctl(m_epfd, EPOLL_CTL_ADD, m_tickleFds[0], &event);
            super("IOManager", threads);
        }

        void registerEvent(AsyncEvent* e)
        {
            e.event.events &= (EPOLLIN | EPOLLOUT);
            assert(e.event.events != 0);
            synchronized (this) {
                int op;
                AsyncEvent** current = e.event.data.fd in m_pendingEvents;
                if (current is null) {
                    op = EPOLL_CTL_ADD;
                    m_pendingEvents[e.event.data.fd] = new AsyncEvent();
                    current = e.event.data.fd in m_pendingEvents;
                    **current = *e;
                } else {
                    op = EPOLL_CTL_MOD;
                    // OR == XOR means that none of the same bits were set
                    assert(((*current).event.events | e.event.events)
                        == ((*current).event.events ^ e.event.events));
                    (*current).event.events |= e.event.events;
                }
                if (e.event.events & EPOLLIN) {
                    (*current)._fiberIn = Fiber.getThis;
                }
                if (e.event.events & EPOLLOUT) {
                    (*current)._fiberOut = Fiber.getThis;
                }
                Stdout.formatln("Registering events {} for fd {}", (*current).event.events,
                    (*current).event.data.fd);
                int rc = epoll_ctl(m_epfd, op, (*current).event.data.fd,
                    &(*current).event);
                if (rc != 0) {
                    throw new Exception("Couldn't associate fd with epoll.");
                }
            }
        }

    protected:
        void idle()
        {
            epoll_event[] events = new epoll_event[64];
            while (true) {
                Stdout.formatln("idling");
                int rc = epoll_wait(m_epfd, events.ptr, events.length, -1);
                Stdout.formatln("Got {} event(s)", rc);
                if (rc <= 0) {
                    throw new Exception("Fail!");
                }
                
                foreach (event; events[0..rc]) {
                    Stdout.formatln("Got events {} for fd {}", event.events, event.data.fd);
                    if (event.data.fd == m_tickleFds[0]) {
                        ubyte dummy;
                        read(m_tickleFds[0], &dummy, 1);
                        continue;
                    }
                    bool err = event.events & EPOLLERR
                        || event.events & EPOLLHUP;
                    synchronized (this) {
                        AsyncEvent* e = m_pendingEvents[event.data.fd];
                        if (event.events & EPOLLIN ||
                            err && e.event.events & EPOLLIN) {
                            schedule(e._fiberIn);
                        }
                        if (event.events & EPOLLOUT ||
                            err && e.event.events & EPOLLOUT) {
                            schedule(e._fiberOut);
                        }
                        e.event.events &= ~event.events;
                        if (err || e.event.events == 0) {
                            rc = epoll_ctl(m_epfd, EPOLL_CTL_DEL,
                                e.event.data.fd, &e.event);
                            if (rc != 0) {
                            }
                            m_pendingEvents.remove(event.data.fd);
                        }
                    }
                }

                Fiber.yield();
            }
        }

        void tickle()
        {
            write(m_tickleFds[1], "T".ptr, 1);
        }

    private:
        int m_epfd;
        int[2] m_tickleFds;
        AsyncEvent*[int] m_pendingEvents;
    }

    struct AsyncEvent
    {
    public:
        epoll_event event;
    private:
        Fiber _fiberIn, _fiberOut;
    };
}

IOManager g_ioManager;
