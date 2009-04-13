module mordor.common.examples.wget;

import tango.net.InternetAddress;
import tango.util.Convert;
import tango.util.log.AppendConsole;

import mordor.common.asyncsocket;
import mordor.common.config;
import mordor.common.http.client;
import mordor.common.http.parser;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.streams.socket;
import mordor.common.streams.std;
import mordor.common.streams.transfer;
import mordor.common.stringutils;

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    IOManager ioManager = new IOManager();

    ioManager.schedule(new Fiber(delegate void() {
        AsyncSocket s = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        s.connect(new InternetAddress(args[1], to!(int)(args[2])));
        SocketStream stream = new SocketStream(s);
        
        scope conn = new ClientConnection(stream);
        Request requestHeaders;
        requestHeaders.requestLine.uri = args[3];
        requestHeaders.general.connection = new StringSet;
        requestHeaders.general.connection.insert("close");
        auto request = conn.request(requestHeaders);
        scope (failure) request.abort();
        scope stdout = new StdoutStream();
        transferStream(request.responseStream, stdout);

        ioManager.stop();
    }, 128 * 1024));

    ioManager.start(true);
}