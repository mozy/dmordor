module mordor.common.examples.echoserver;

import tango.core.Thread;
import tango.io.Stdout;
import tango.net.InternetAddress;

import mordor.common.asyncsocket;
import mordor.common.iomanager;

void main(char[][])
{
    IOManager ioManager = new IOManager(5);

    ioManager.schedule(new Fiber(delegate void() {
        Socket s = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        s.bind(new InternetAddress("127.0.0.1", 8000));
        s.listen(10);

        while(true) {
            Socket newsocket = s.accept();
            Connection newconn = new Connection(newsocket);
            Scheduler.getThis.schedule(new Fiber(&newconn.run));
        }
    }));

    ioManager.start(true);
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
