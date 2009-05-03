module mordor.common.examples.simpleclient;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;

import mordor.common.asyncsocket;
import mordor.common.iomanager;

void main(char[][] args)
{
    IOManager ioManager = new IOManager();

    Socket s = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
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
}
