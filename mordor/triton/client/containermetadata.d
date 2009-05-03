module mordor.triton.client.containermetadata;

import tango.util.Convert;

import mordor.common.http.client;
import mordor.common.http.parser;
import mordor.common.http.uri;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.common.xml.parser;

void getMetadata(ClientConnection conn, string principal, long container,
            string[] keys)
{
    Request requestHeaders;
    requestHeaders.requestLine.method = Method.HEAD;
    requestHeaders.requestLine.uri = "/rest/container";
    requestHeaders.request.host = "triton";
    requestHeaders.entity.extension["X-Emc-Principalid"] = principal;
    requestHeaders.entity.extension["X-Emc-Containerid"] = to!(string)(container);
    if (keys.length > 0) {
        string metadataList;
        foreach(k; keys) {
            if (metadataList.length > 0)
                metadataList ~= ", ";
            metadataList ~= k;
        }
        requestHeaders.entity.extension["X-Emc-Metadata-List"] = metadataList;
    }
    auto request = conn.request(requestHeaders);
    scope (failure) request.abort();
    assert(request.response.entity.contentLength == 0);
}

void setMetadata(ClientConnection conn, string principal, long container,
                   string[string] pairs)
in
{
    assert(pairs.length > 0);
}
body
{
   Request requestHeaders;
   requestHeaders.requestLine.method = Method.POST;
   requestHeaders.requestLine.uri = "/rest/container";
   requestHeaders.request.host = "triton";
   requestHeaders.entity.extension["X-Emc-Principalid"] = principal;
   requestHeaders.entity.extension["X-Emc-Containerid"] = to!(string)(container);
   string metadata;
   foreach(string k, string v; pairs) {
       if (metadata.length != 0)
           metadata ~= ", ";
       metadata ~= k ~ "=" ~ v;
   }
   requestHeaders.entity.extension["X-Emc-Metadata"] = metadata;
   auto request = conn.request(requestHeaders);
   scope (failure) request.abort();
   assert(request.response.entity.contentLength == 0);
}

debug (containermetadata)
{
    import tango.io.Stdout;
    import tango.net.InternetAddress;
    import tango.util.log.AppendConsole;

    import mordor.common.asyncsocket;
    import mordor.common.config;
    import mordor.common.iomanager;
    import mordor.common.log;
    import mordor.common.streams.socket;
    
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
        
        if (args.length > 4 && args[4] == "-s") {
            string[string] pairs;
            for (size_t i = 5; i < args.length; i += 2) {
                pairs[args[i]] = args[i + 1];
            }
            setMetadata(conn, args[2], to!(long)(args[3]), pairs);
        } else {
            string[] keys;
            if (args.length > 4)
                keys = args[4..$];
            
            getMetadata(conn, args[2], to!(long)(args[3]), keys);
        }
    }
}
