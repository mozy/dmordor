module mordor.triton.client.head;

import tango.util.Convert;

import mordor.common.http.client;
import mordor.common.http.parser;
import mordor.common.http.uri;
import mordor.common.streams.stream;
import mordor.common.stringutils;

void head(ClientConnection conn, string principal, long container, string file)
{
    Request requestHeaders;
    requestHeaders.requestLine.method = Method.HEAD;
    requestHeaders.requestLine.uri = "/rest/namedObjects/" ~ escapePath(file);
    requestHeaders.request.host = "triton";
    requestHeaders.entity.extension["X-Emc-Principalid"] = principal;
    requestHeaders.entity.extension["X-Emc-Containerid"] = to!(string)(container);
    auto request = conn.request(requestHeaders);
    scope (failure) request.abort();
    auto response = request.response;
}

debug (head) {    
    import tango.net.InternetAddress;
    import tango.util.log.AppendConsole;
    
    import mordor.common.asyncsocket;
    import mordor.common.config;
    import mordor.common.iomanager;
    import mordor.common.log;
    import mordor.common.streams.socket;
    import mordor.common.streams.std;
    import mordor.common.streams.transfer;
    
    void main(string[] args)
    {
        Config.loadFromEnvironment();
        Log.root.add(new AppendConsole());
        enableLoggers();
    
        IOManager ioManager = new IOManager();
    
        AsyncSocket s = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        s.connect(new InternetAddress(args[1]));
        SocketStream stream = new SocketStream(s);
        
        scope conn = new ClientConnection(stream);
        head(conn, args[2], to!(long)(args[3]), args[4]);
    }
}
