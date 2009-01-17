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

        void registerEvent(OverlappedEvent e)
        {
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
                OverlappedEvent e;
                
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
        OverlappedEvent[OVERLAPPED*] m_pendingEvents;
    }

    IOManager g_ioManager;

    class OverlappedEvent
    {
    public:
        this()
        {}

        void register()
        {
            _fiber = Fiber.getThis;
            g_ioManager.registerEvent(this);
        }

        BOOL ret;
        OVERLAPPED overlapped;
        DWORD numberOfBytes;
        ULONG_PTR completionKey;
        DWORD lastError;

    private:
        Fiber _fiber;
    };
}
