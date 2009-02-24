module mordor.common.examples.streamclient;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;

import mordor.common.asyncsocket;
import mordor.common.iomanager;
import mordor.common.streams.socket;

void main(char[][] args)
{
    IOManager ioManager = new IOManager();

    ioManager.schedule(new Fiber(delegate void() {
        AsyncSocket s = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        s.connect(new InternetAddress(args[1], to!(int)(args[2])));
        Buffer sendBuf = new Buffer(), receiveBuf = new Buffer();
        scope SocketStream stream = new SocketStream(s);
        sendBuf.copyIn("hello\r\n");
        result_t result = stream.write(sendBuf, sendBuf.readAvailable);
        if (FAILED(result) || result == 0) {
            return;
        }
        result = stream.read(receiveBuf, 8192);
        if (FAILED(result)) {
            return;
        }
        Stdout.formatln("Read {} bytes from conn", result);
        ioManager.stop();
    }));

    ioManager.start(true);
}
