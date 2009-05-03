module mordor.triton.client.store;

import tango.io.Stdout;
import tango.net.InternetAddress;
import tango.util.Convert;
import tango.util.log.AppendConsole;
import tango.util.log.Log;

import mordor.common.asyncsocket;
import mordor.common.config;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.streams.file;
import mordor.common.streams.socket;
import mordor.common.streams.transfer;
import mordor.common.streams.utils;
import mordor.common.stringutils;

Logger _log;

static this()
{
    _log = Log.lookup("triton.client.store");
}

void store(Stream tds, string objectName, Stream object)
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

    _log.trace("Storing object {}", objectName);
    long size = object.size();
    
    command ~= to!(string)(size) ~ "\n";
    
    tds.write(command);
    transferStream(object, tds);
    
    _log.trace("stored object {}", objectName);
    char[] line;
    tds.getDelimited(line);
    _log.trace("Got response '{}' from triton", line);
    
    if (line.length != 2 || line != "OK") {
        throw new Exception(line);        
    }
    return 0;
}

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    IOManager ioManager = new IOManager(1);

    AsyncSocket socket = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
    socket.connect(new InternetAddress(args[1], to!(int)(args[2])));
    Stream tds = bufferReadStream(new SocketStream(socket));
    Stream object = new FileStream(args[3]);
    
    store(tds, args[4], object);
}
