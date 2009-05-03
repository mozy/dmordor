module mordor.triton.client.raw;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;
import tango.util.log.AppendConsole;

import mordor.common.asyncsocket;
import mordor.common.config;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.streams.limited;
import mordor.common.streams.socket;
import mordor.common.streams.std;
import mordor.common.streams.transfer;
import mordor.common.streams.utils;
import mordor.common.stringutils;

Stream raw(Stream tds, string objectName)
in
{
    assert(tds !is null);
    assert(tds.supportsRead);
    assert(tds.supportsWrite);
    assert(objectName.length > 4);
    assert(objectName[$ - 4..$] == ".dat" || objectName[$ - 4..$] == ".man");
    assert(objectName[$ - 4..$] == ".man" || objectName.length == 44);
}
body
{
    char[] command = "raw\nb3b83038ce5abfc071828af9e24d944f\n"
        ~ objectName ~ "\n0\n";
    
    tds.write(command);
    
    char[] line;
    tds.getDelimited(line);
    
    if (line.length >= 5 && line[0..5] == "ERROR") {
        throw new Exception(line);        
    }
    long length = to!(long)(line);
    return new LimitedStream(tds, length, false);
}

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    IOManager ioManager = new IOManager(2);

    AsyncSocket socket = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
    socket.connect(new InternetAddress(args[1], to!(int)(args[2])));
    Stream tds = bufferReadStream(new SocketStream(socket));
    Stream stdout = new StdoutStream;
    
    Stream object = raw(tds, args[3]);
    transferStream(object, stdout);
}
