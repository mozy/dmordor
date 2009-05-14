module mordor.triton.client.get;

import tango.util.Convert;

import mordor.common.http.client;
import mordor.common.http.parser;
import mordor.common.http.uri;
import mordor.common.streams.stream;
import mordor.common.stringutils;

Stream get(ClientConnection conn, string principal, long container, string file)
{
    Request requestHeaders;
    requestHeaders.requestLine.uri = "/rest/namedObjects/" ~ escapePath(file);
    requestHeaders.request.host = "triton";
    requestHeaders.entity.extension["X-Emc-Principalid"] = principal;
    requestHeaders.entity.extension["X-Emc-Containerid"] = to!(string)(container);
    auto request = conn.request(requestHeaders);
    scope (failure) request.abort();
    assert(request.response.status.status == Status.OK);
    return request.responseStream;
}

debug (get)
{
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
        s.connect(new InternetAddress(args[1], to!(int)(args[2])));
        SocketStream stream = new SocketStream(s);
        
        scope conn = new ClientConnection(stream);
        transferStream(get(conn, args[3], args[4], to!(long)(args[5])), new StdoutStream());
    }
}
