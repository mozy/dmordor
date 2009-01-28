module mordor.common.examples.simpleclient;

import tango.core.Thread;
import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;

import mordor.common.asyncsocket;
import mordor.common.iomanager;

void main(char[][] args)
{
    g_ioManager = new IOManager();

    g_ioManager.schedule(new Fiber(delegate void() {
        Socket s = new AsyncSocket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        s.connect(new InternetAddress(args[1], to!(int)(args[2])));
        int rc = s.send("hello\r\n");
        if (rc <= 0) {
            return;
        }
        ubyte[] buf = new ubyte[8192];
        rc = s.receive(buf);
        if (rc < 0) {
            return;
        }
        Stdout.formatln("Read '{}' from conn", cast(char[])buf[0..rc]);

        s.shutdown(SocketShutdown.BOTH);
        s.detach();
    }));

    g_ioManager.start(true);
}
