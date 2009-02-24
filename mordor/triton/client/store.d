module mordor.triton.client.store;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;

import mordor.common.asyncsocket;
import mordor.common.iomanager;
import mordor.common.streams.buffered;
import mordor.common.streams.digest;
import mordor.common.streams.file;
import mordor.common.streams.socket;
import mordor.common.streams.transfer;
import mordor.common.stringutils;

result_t store(BufferedStream tds, string objectName, Stream object)
in
{
    assert(tds !is null);
    assert(tds.supportsRead);
    assert(tds.supportsWrite);
    assert(object !is null);
    assert(object.supportsRead);
    assert(objectName.length > 4);
    assert(objectName[$ - 4..$] == ".dat" || objectName[$ - 4..$] == ".man");
    assert(objectName[$ - 4..$] == ".man" || objectName.length == 44);
}
body
{
    char[] command = "store\nb3b83038ce5abfc071828af9e24d944f\n"
        ~ objectName ~ "\n0\n";

    long size;
    result_t result = object.size(size);
    if (result < 0) {
        return result;
    }
    
    command ~= to!(string)(size) ~ "\n";
    
    result = tds.write(command);
    if (result < 0) {
        return result;        
    }
    result = transferStream(object, tds);
    if (result < 0) {
        return result;
    }
    result = tds.flush();
    if (result < 0) {
        return result;
    }
    
    char[] line;
    result = tds.getDelimited(line);
    if (result < 0) {
        return result;
    }
    
    if (line.length != 2 || line != "OK") {
        throw new Exception(line);        
    }
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
        Stream object = new FileStream(args[3]);
        
        result_t result = store(tds, args[4], object);
        if (result != 0) {
            Stderr.formatln("Failed to communicate with triton: {}", result);
            return;
        }
        
        ret = 0;
    }));
    
    ioManager.start(true);
    return ret;
}
