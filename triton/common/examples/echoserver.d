module triton.common.examples.echoserver;

import tango.core.Thread;
import tango.io.Stdout;
import tango.net.InternetAddress;

import triton.common.asyncsocket;
import triton.common.iomanager;

void main(char[][])
{
    g_ioManager = new IOManager(5);

    Fiber f = new Fiber(&fiberMain);
    g_ioManager.schedule(f);

    g_ioManager.start(true);
}

class Connection
{
public:
    this(Socket s)
    {
        sock = s;
    }

    void run()
    {
        while(true) {
            Stdout.formatln("starting a new read");
            void[] buffer = new void[4096];
            int rc = sock.receive(buffer);
            Stdout.formatln("Received {}", rc);
            if (rc <= 0) {
                return;
            }
            rc = sock.send(buffer[0..rc]);
            if (rc <= 0) {
                return;
            }
            Stdout.formatln("Sent {}", rc);
        }
    }

private:
    Socket sock;
};

void fiberMain()
{
    Socket s = new AsyncSocket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
    s.bind(new InternetAddress("127.0.0.1", 8000));
    s.listen(10);

    while(true) {
        Socket newsocket = s.accept();
        Connection newconn = new Connection(newsocket);
        Scheduler.autoschedule(new Fiber(&newconn.run));
    }
}
