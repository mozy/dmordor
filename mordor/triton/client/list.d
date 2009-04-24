module mordor.triton.client.list;

import tango.util.Convert;

import mordor.common.http.client;
import mordor.common.http.parser;
import mordor.common.streams.stream;
import mordor.common.stringutils;

Stream list(ClientConnection conn, string principal, long container,
            string prefix, bool recurse, string beginName, long limit,
            bool includeVersions, bool includeDirectories)
{
    Request requestHeaders;
    requestHeaders.requestLine.uri = "/rest/namedObjects?Prefix=" ~ prefix ~
        "&Recurse=" ~ (recurse ? "1" : "0") ~ "&BeginName=" ~ beginName ~
        (limit == -1 ? "" : "&Limit=" ~ to!(string)(limit)) ~
        "&IncludeVersions=" ~ (includeVersions ? "1" : "0") ~
        "&IncludeDirectories=" ~ (includeDirectories ? "1" : "0");
    requestHeaders.request.host = "triton";
    requestHeaders.entity.extension["X-Emc-Principalid"] = principal;
    requestHeaders.entity.extension["X-Emc-Containerid"] = to!(string)(container);
    auto request = conn.request(requestHeaders);
    scope (failure) request.abort();
    return request.responseStream;
}

debug (list)
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
    
        ioManager.schedule(new Fiber(delegate void() {
            AsyncSocket s = new AsyncSocket(ioManager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
            s.connect(new InternetAddress(args[1], to!(int)(args[2])));
            SocketStream stream = new SocketStream(s);
            
            scope conn = new ClientConnection(stream);
            
            string prefix;
            bool recurse = true;
            string beginName;
            long limit = -1;
            bool includeVersions = true;
            bool includeDirectories = false;
            if (args.length > 5)
                prefix = args[5];
            if (args.length > 6)
                recurse = to!(bool)(args[6]);
            if (args.length > 7)
                beginName = args[7];
            if (args.length > 8)
                limit = to!(long)(args[8]);
            if (args.length > 9)
                includeVersions = to!(bool)(args[9]);
            if (args.length > 10)
                includeDirectories = to!(bool)(args[10]);
            transferStream(list(conn, args[3], to!(long)(args[4]), prefix, recurse, beginName, limit, includeVersions, includeDirectories), new StdoutStream());
    
            ioManager.stop();
        }, 128 * 1024));
    
        ioManager.start(true);
    }
}
