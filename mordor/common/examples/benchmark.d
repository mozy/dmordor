module mordor.common.examples.benchmark;

import tango.core.Atomic;
import tango.core.Thread;
import tango.io.Stdout;
import tango.math.Math;
import tango.net.InternetAddress;
import tango.time.StopWatch;

import mordor.common.asyncsocket;
import mordor.common.iomanager;

const int SERVER_PORT = 60000;

IOManager g_ioManager;

void main(char[][] args)
{
    g_ioManager = new IOManager();

    bool runServer = true;
    bool runClient = true;

    if (runServer) {
        g_ioManager.schedule(new Fiber(delegate void() {
            Socket s = new AsyncSocket(g_ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
            s.bind(new InternetAddress("0.0.0.0", SERVER_PORT));
            s.listen(10);

            while(true) {
                Socket newsocket = s.accept();
                ServerConnection newconn = new ServerConnection(newsocket);
                Scheduler.autoschedule(new Fiber(&newconn.run));
            }
        }));
    }

    if (runClient) {
        Stdout.formatln("# total_conns total_time_usec num_ops avg_time_usec "
	           "ops_per_sec bw_mbps");
        g_clients = new Fiber[g_totalConns];
        ClientConnection.startTest(1);
    }

    g_ioManager.start(true);
}

class ServerConnection
{
public:
    this(Socket s)
    {
        sock = s;
    }

    void run()
    {
        scope (exit) sock.shutdown(SocketShutdown.BOTH);
        while(true) {
            ubyte[1] buffer;
            int rc = sock.receive(buffer);
            if (rc <= 0) {
                Stdout.formatln("Server couldn't receive: {}", rc);
                return;
            }
            rc = sock.send(buffer);
            if (rc <= 0) {
                Stdout.formatln("Server couldn't send: {}", rc);
                return;
            }
        }
    }

private:
    Socket sock;
};

int g_lastIters;
int g_iters;
int g_numDone;
int g_numNew;
int g_connected;
int g_prevActive;
int g_totalConns = 100;
double g_lastElapsed;
bool g_powTwo = false;
Fiber[] g_clients;
StopWatch g_stopwatch;

class ClientConnection
{
public:
    static void startTest(int numNew)
    {
        g_numNew = min(g_connected + numNew, g_totalConns);
        for (int i = g_connected; i < g_numNew; ++i) {
            g_clients[i] = new Fiber(&run);
            g_ioManager.schedule(g_clients[i]);
        }
    }

    static void run()
    {
        Socket s = new AsyncSocket(g_ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        s.connect(new InternetAddress("127.0.0.1", SERVER_PORT));

        if (atomicIncrement(g_connected) == g_numNew) {
            Stdout.format("{} ", g_connected);
	        g_numDone = 0;
	        g_prevActive = g_connected;
	        calcItersNew();
            g_stopwatch.start();
            foreach(f; g_clients[0..g_connected]) {
                Scheduler.autoschedule(f);
            }
        }
        Fiber.yield();

        while (true) {
            ubyte[1] buffer;
            int rc;
            int read = 0;
            while (read < g_iters) {
                rc = s.send(buffer);
                if (rc != 1) {
                    Stdout.formatln("couldn't send because {}", rc);
                    throw new Exception("uh oh 1");
                }
                rc = s.receive(buffer);
                if (rc != 1) {
                    throw new Exception("uh oh 2");
                }
                ++read;
            }

            if (atomicIncrement(g_numDone) == g_connected) {
                g_lastElapsed = g_stopwatch.stop();

                double elapsed = g_lastElapsed;
                double ops = g_connected * g_iters;
                double average = elapsed / ops;
                double opsSec = ops / elapsed;
                double bytes = ops;
                double bw = bytes / elapsed / 1000 / 1000;

                Stdout.formatln("{:.0f} {:.0f} {:.0f} {:.0f} {:.2f}", elapsed * 1_000_000, ops, average * 1_000_000, opsSec, bw);

                if (g_connected == g_totalConns) {
                    // Don't bother cleaning up, just exit
                    assert(false);
                }
                if (g_powTwo) {
                    startTest(g_connected);
                } else {
                    startTest(1);
                }
            }
            Fiber.yield();
        }
    }

    static void calcItersNew()
    {
        if (!g_lastIters) {
	        // TODO: starting at 10000 is about right for 1 byte transfers,
	        // but is way overkill for 64K transfers, etc.  If we ever start
	        // the test at more than 1 active connection, this could make
	        // the initial test take way too long.  Consider adjusting this
	        // based on the number of starting active connections.
	        g_iters = 10000;
	    } else {
	        // If we are doing a power of 2 progression, try to run for at
	        // least 5 seconds
	        double target = g_powTwo ? 5 : 0.001;
	        int numOps = g_prevActive * g_lastIters;
            double optime = g_lastElapsed / numOps;

	        // we want to have the whole loop last 1ms.  So figure out
	        // how many iters per-client's fraction of that time.
            g_iters = cast(int)(target / g_connected / optime);
            if (g_iters == 0) {
                g_iters = 1;
            }
	    }

	    g_lastIters = g_iters;
    }

};
