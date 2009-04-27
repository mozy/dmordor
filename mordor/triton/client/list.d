module mordor.triton.client.list;

import tango.util.Convert;

import mordor.common.http.client;
import mordor.common.http.parser;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.common.xml.parser;

void list(Stream xml, void delegate(string, bool) fileDg)
{
    string element;
    string attrib;
    
    string path;
    bool deleted;
    bool isdir;
    scope parser = new XmlParser(
        delegate void(string startTag) {
            element = startTag.dup;            
        },
        delegate void(string endTag) {
            if (endTag == "NamedObject") {
                if (path.length == 0)
                    throw new Exception("No fullpath!");
                fileDg(path, isdir);
                path.length = 0;
                isdir = false;
            }            
        },
        delegate void(string attribName) {
            attrib = attribName.dup;
        },
        delegate void(string attribValue) {
            if (element == "NamedObject" && attrib == "directory")
                isdir = to!(bool)(attribValue);
        },
        delegate void(string innerText) {
            if (element == "fullpath")
                path = innerText.dup;
        });
    parser.run(xml);
    if (parser.error)
        throw new Exception("Invalid XML");
}

void list(ClientConnection conn, string principal, long container,
            string prefix, bool recurse, string beginName, long limit,
            bool includeVersions, bool includeDirectories,
            void delegate(string, bool) fileDg)
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

    list(request.responseStream, fileDg);
}

debug (list)
{
    import tango.io.Stdout;
    import tango.net.InternetAddress;
    import tango.util.log.AppendConsole;

    import mordor.common.asyncsocket;
    import mordor.common.config;
    import mordor.common.iomanager;
    import mordor.common.log;
    import mordor.common.streams.file;
    import mordor.common.streams.socket;
    import mordor.common.streams.std;
    import mordor.common.streams.transfer;
    
    void main(string[] args)
    {
        Config.loadFromEnvironment();
        Log.root.add(new AppendConsole());
        enableLoggers();
        
        if (args.length == 3 && args[1] == "-f") {
            list(new FileStream(args[2], FileStream.Flags.READ),
                delegate void(string path, bool isdir) {
                    Stdout.formatln("File '{}' is dir {}", path, isdir);
                });
            return;
        }
    
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
            list(conn, args[3], to!(long)(args[4]), prefix, recurse, beginName, limit, includeVersions, includeDirectories,
                delegate void(string path, bool isdir) {
                    Stdout.formatln("File '{}' is dir {}", path, isdir);
                });
    
            ioManager.stop();
        }, 64 * 1024));
    
        ioManager.start(true);
    }
}
