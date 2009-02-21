module mordor.triton.client.raw;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;

import mordor.common.asyncsocket;
import mordor.common.iomanager;
import mordor.common.streams.buffered;
import mordor.common.streams.limited;
import mordor.common.streams.socket;
import mordor.common.streams.std;
import mordor.common.streams.transfer;
import mordor.common.stringutils;

result_t raw(BufferedStream tds, string objectName, out Stream object)
{
    char[] command = "raw\nb3b83038ce5abfc071828af9e24d944f\n"
        ~ objectName ~ "\n0\n";
    
    result_t result = tds.write(command);
    if (result < 0) {
        return result;        
    }
    result = tds.flush();
    if (result < 0) {
        return result;        
    }
    
    char[] line;
    result = tds.getDelimited(line);
    
    if (line.length >= 5 && line[0..5] == "ERROR") {
        throw new Exception(line);        
    }
    long length = to!(long)(line);
    object = new LimitedStream(tds, length, false);
    return 0;
}

int main(string[] args)
{
    IOManager ioManager = new IOManager(2);
    int ret = 1;
    
    ioManager.schedule(new Fiber(delegate void() {
        scope (exit) ioManager.stop();
        
        AsyncSocket socket = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        socket.connect(new InternetAddress(args[1], to!(int)(args[2])));
        BufferedStream tds = new BufferedStream(new SocketStream(socket));
        Stream stdout = new StdoutStream;
        Stream object;
        
        result_t result = raw(tds, args[3], object);
        if (result != 0) {
            Stderr.formatln("Failed to communicate with triton: {}", result);
            return;
        }
        result = transferStream(object, stdout);
        if (result < 0) {
            Stderr.formatln("Failed to read object from triton: {}", result);
            return;
        }
        
        ret = 0;
    }));
    
    ioManager.start(true);
    return ret;
}
