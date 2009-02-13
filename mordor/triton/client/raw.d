module mordor.triton.client.raw;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;

import mordor.common.asyncsocket;
import mordor.common.iomanager;
import mordor.common.streams.buffered;
import mordor.common.streams.socket;
import mordor.common.streams.fd;
import mordor.common.streams.streamtostream;
import mordor.common.stringutils;

int main(string[] args)
{
    IOManager ioManager = new IOManager(2);
    int ret = 1;
    
    ioManager.schedule(new Fiber(delegate void() {
        scope (exit) ioManager.stop();
        
        AsyncSocket socket = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        socket.connect(new InternetAddress(args[1], to!(int)(args[2])));
        BufferedStream triton = new BufferedStream(new SocketStream(socket));
        Stream stdout = new FDStream(1);
        
        char[] command = "raw\nb3b83038ce5abfc071828af9e24d944f\n".dup;
        command ~= args[3];
        command ~= "\n0\n";
        
        result_t result = triton.write(command);
        if (result < 0) {
            Stderr.formatln("Failed to send command: {}", result);
            return;
        }
        result = triton.flush();
        if (result < 0) {
            Stderr.formatln("Failed to send command: {}", result);
            return;
        }
        
        char[] line;
        result = triton.getDelimited(line);
        if (result < 0) {
            Stderr.formatln("Failed to read triton's response: {}", result);
            return;
        }
        if (line.length >= 5 && line[0..5] == "ERROR") {
            Stderr.formatln("{}", line);
            return;
        }
        size_t length = to!(size_t)(line);
        long transferred;
        result = streamToStream(triton, stdout, transferred, length);
        if (result < 0) {
            Stderr.formatln("Failed to read object from triton: {}", result);
            return;
        }
        
        ret = 0;
    }));
    
    ioManager.start(true);
    return ret;
}
