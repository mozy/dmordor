module mordor.common.http.server;
/+
import tango.core.Thread;
import tango.util.log.Log;

import mordor.common.containers.linkedlist;
import mordor.common.http.connection;
public import mordor.common.http.parser;
import mordor.common.scheduler;
import mordor.common.streams.nil;
import mordor.common.streams.stream;
import mordor.common.streams.transfer;
import mordor.common.stringutils;

private Logger _log, _fiberLog;

static this()
{
    _log = Log.lookup("mordor.common.http.client");
}

class ServerConnection : Connection
{
    this(Stream stream, void delegate(ServerRequest) dg)
    {
        super(stream);
        _dg = dg;
        _pendingResponses = new LinkedList!(ServerRequest, false)();
    }
    
    void run()
    {
        _scheduler = Scheduler.getThis;
        _fiber = Fiber.getThis;
        while (true) {
            auto request = new ServerRequest(this);
            // TODO: try...catch, 400 Bad Request
            _log.trace("Reading request headers");
            // Read and parse headers
            scope parser = new RequestParser(request._request);
            parser.init();
            scope buffer = new Buffer();
            while (!parser.complete && !parser.error) {
                // TODO: limit total amount read
                size_t read = _conn._readStream.read(buffer, 65536);
                if (read == 0) {
                    parser.run([], true);
                } else {
                    void[][] bufs = buffer.readBufs;
                    while (bufs.length > 0) {
                        size_t consumed = parser.run(cast(char[])bufs[0], false);
                        buffer.consume(consumed);
                        if (parser.complete || parser.error)
                            break;
                        bufs = bufs[1..$];
                    }
                }
            }
            _conn._readStream.unread(buffer, buffer.readAvailable);
            buffer.clear();
            if (parser.error) {
                throw new Exception("Error parsing response");
            }
            _log.info("Got request {}", headers.toString());
            with (request._request) {
                if (requestLine.ver == Version(1, 0)) {
                    if (general.connection is null || general.connection.find("keep-alive") == general.connection.end)
                        _close = true;
                } else if (requestLine.ver == Version(1, 1)) {
                    if (general.connection !is null && general.connection.find("close") != general.connection.end)
                        _close = true;
                } else {
                    throw new Exception("Unrecognized HTTP server version.");
                }
            }
            
            synchronized (_pendingResponses) {
                _pendingResponses.append(request);
            }
            
            request._fiber = new Fiber(delegate void() {
                auto dgRequest = request;
                Fiber.yield();
                _dg(dgRequest);
            });
            // "dynamic closure"
            request._fiber.call();
            _scheduler.schedule(request._fiber);
            
            with (request._request) {
                if (hasMessageBody(general, entity, requestLine.method, Status.init)) {
                    Fiber.yield();
                }
            }
            
            if (close) {
                _stream.close(Stream.CloseType.READ);
                break;
            }
        }        
    }
    
private:
    void delegate(ServerRequest) _dg;
    Scheduler _scheduler;
    Fiber _fiber;
    LinkedList!(ServerRequest, false) _pendingResponses;
    bool[ServerRequest] _waitingResponses;
}

class ServerRequest
{
private:
    this(ServerConnection conn)
    {
        _conn = conn;
    }

public:
    Request requestHeaders() { return _request; }
    Stream requestStream()
    {
        if (_requestStream !is null)
            return _requestStream;
        with (_request) {
            return _requestStream = _conn.getStream(general, entity, requestLine.method, Status.init);
        }
    }
    /*
    Multipart requestMultipart();
     */
    
    Response* responseHeaders() { return _response; }
    Stream responseStream()
    {
        if (_responseStream !is null)
            return _responseStream;
        commit();
        with (_response) {
            return _responseStream = _conn.getStream(general, entity, _request.requestLine.method, Status.init);
        }
    }    
    /*
    Multipart responseMultipart();
     */
    void respond()
    in
    {
        assert(_response.entity.contentLength == 0);
    }
    body
    {
        commit();
        // For empty message body
    }

private:
    void commit()
    {
        // TODO: queue up and wait until our turn to respond
        string responseHeadersString = _response.toString();
        _log.info("Responding {}", responseHeadersString);
        _stream.write(responseHeadersString);
    }
    
private:
    Request _request;
    Response _response;
    Entity _requestTrailer, _responseTrailer;
    Stream _requestStream, _responseStream;
    ServerConnection _conn;
}
+/