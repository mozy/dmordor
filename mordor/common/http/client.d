module mordor.common.http.client;

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

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.common.http.client");
}

class ClientConnection : Connection
{
    this(Stream stream)
    {
        super(stream);
        _pendingRequests = new LinkedList!(ClientRequest, false)();
        _pendingResponses = new LinkedList!(ClientRequest, false)();
    }
    
    ClientRequest request(Request requestHeaders)
    in
    {
        with (requestHeaders) {
            // 1.0, 1.1, or defaulted
            assert(requestLine.ver == Version.init ||
                   requestLine.ver == Version(1, 0) ||
                   requestLine.ver == Version(1, 1));
            // Have to request something
            assert(requestLine.uri.length > 0);
            // Host header required with HTTP/1.1
            assert(request.host.length > 0 || requestLine.ver != Version(1, 1));
            // If any transfer encodings, must include chunked, must have chunked only once, and must be the last one
            if (general.transferEncoding.length > 0) {
                assert(general.transferEncoding[$-1].value == "chunked");
                foreach(tc; general.transferEncoding[0..$-1]) {
                    // Only the last one can be chunked
                    assert(tc.value != "chunked");
                    // identity is only acceptable in the TE header field
                    assert(tc.value != "identity");
                    switch (tc.value) {
                        case "gzip":
                        case "x-gzip":
                        case "deflate":
                            // Known Transfer-Codings
                            break;
                        case "compress":
                        case "x-compress":
                        default:
                            // Unknown/unsupported Transfer-Codings
                            assert(false);
                    }
                }
            }
        }
    }
    body
    {
        bool close;
        with (requestHeaders) {
            // Default HTTP version... 1.1 if possible
            if (requestLine.ver == Version.init) {
                if (request.host.length == 0)
                    requestLine.ver = Version(1, 0);
                else
                    requestLine.ver = Version(1, 1);
            }
            // If not specified, try to keep the connection open
            if (general.connection is null) {
                if (requestLine.ver == Version(1, 0)) {
                    general.connection = new StringSet();
                    general.connection.insert("Keep-Alive");
                }
            }
            // Determine if we're closing the connection after this request
            if (requestLine.ver == Version(1, 0)) {
                if (general.connection !is null && general.connection.find("Keep-Alive") != general.connection.end) {
                    close = false;
                } else {
                    close = true;
                    if (general.connection is null)
                        general.connection = new StringSet();
                    general.connection.insert("close");
                }
            } else {
                if (general.connection !is null && general.connection.find("close") != general.connection.end) {
                    close = true;
                } else {
                    close = false;
                }
            }
        }
        
        auto request = new ClientRequest(this, requestHeaders);

        bool firstRequest;
        // Put the request in the queues
        synchronized (_pendingRequests) synchronized (_pendingResponses) {
            if (_responseException !is null)
                throw _responseException;
            if (_requestException !is null)
                throw _requestException;

            firstRequest = _pendingRequests.empty;
            _pendingRequests.append(request);
            _pendingResponses.append(request);
            if (firstRequest && close) {
                _requestException = new Exception("No more requests are possible because the connection was voluntarily closed");
                // TODO: save this somewhere that requests before this one don't abort, but you can't submit a new request after it
            }
        }
        // If we weren't the first request in the queue, we have to wait for
        // another request to schedule us
        if (!firstRequest) {
            Fiber.yield();
            synchronized (_pendingRequests) {
                if (_requestException !is null)
                    throw _requestException;
                assert(!_pendingRequests.empty);
                assert(_pendingRequests.begin.val._fiber == Fiber.getThis);
                if (close) {
                    _requestException = new Exception("No more requests are possible because the connection was voluntarily closed");
                }
            }
        }
        scope (failure) synchronized (_pendingRequests) {
            _requestException = new Exception("No more requests are possible because a prior request failed");
            auto it = _pendingRequests.end;
            assert(it.val._fiber == Fiber.getThis);
            ++it;
            while (it != _pendingRequests.end) {
                it.val._scheduler.schedule(it.val._fiber);
                ++it;
            }
            _pendingRequests.clear();
        }

        // Do the request
        string requestHeadersString = requestHeaders.toString();
        _log.info("Sending request {}", requestHeadersString);
        _stream.write(requestHeadersString);

        with (requestHeaders) {
            if (!hasMessageBody(general, entity, requestLine.method, Status.init)) {
                scheduleNextRequest();
            }
        }
        return request;
    }
    
private:
    void scheduleNextRequest()
    {
        bool flush;
        synchronized (_pendingRequests) {
            auto it = _pendingRequests.begin;
            assert(it.val._fiber == Fiber.getThis);
            it = _pendingRequests.erase(it);
            if (it == _pendingRequests.end) {
                // No pending requests, make sure to flush
                flush = true;
            } else {
                _log.trace("Scheduling request {}", it.val);
                it.val._scheduler.schedule(it.val._fiber);
            }
        }
        if (flush) {
            _log.trace("Flushing stream after final request");
            _stream.flush();
            synchronized (_pendingRequests) {
                auto it = _pendingRequests.begin;
                if (it != _pendingRequests.end) {
                    _log.trace("Scheduling request {}", it.val);
                    it.val._scheduler.schedule(it.val._fiber);
                }
            }
        }
    }
    
    void scheduleNextResponse()
    {
        synchronized (_pendingResponses) {
            auto it = _pendingResponses.begin;
            //assert(it.val == this);
            it = _pendingResponses.erase(it);
            if (it != _pendingResponses.end) {
                if (it.val in _waitingResponses) {
                    _waitingResponses.remove(it.val);
                    _log.trace("Scheduling request {}", it.val);
                    it.val._scheduler.schedule(it.val._fiber);
                } else {
                    _log.trace("Response fiber is not waiting for response... doing nothing");
                }
            } else {
                _log.trace("All requests processed");
            }
        }
    }

private:
    Exception _requestException, _responseException;
    LinkedList!(ClientRequest, false) _pendingRequests;
    LinkedList!(ClientRequest, false) _pendingResponses;
    bool[ClientRequest] _waitingResponses;
}
 
class ClientRequest
{
private:
    this(ClientConnection conn, Request request)
    {
        _conn = conn;
        _request = request;
        _scheduler = Scheduler.getThis;
        _fiber = Fiber.getThis;
    }
public:
    
    Stream requestStream()
    {
        if (_requestStream !is null)
            return _requestStream;
        with (_request) {
            return _requestStream = _conn.getStream(general, entity, requestLine.method, Status.init, &requestDone, false);
        }
    }
    EntityHeaders* requestTrailer()
    {
        assert(_request.general.transferEncoding.length > 0);
        return &_requestTrailer;
    }
    /*
    Multipart requestMultipart();
     */
    
    Response response()
    {
        ensureResponse();
        return _response;
    }
    
    Stream responseStream()
    {
        if (_responseStream !is null)
            return _responseStream;
        ensureResponse();
        with (_response) {
            return _responseStream = _conn.getStream(general, entity, _request.requestLine.method, status.status, &responseDone, true);
        }
    }

    /*
    Multipart responseMultipart();
   */
    
    EntityHeaders responseTrailer()
    {
        assert(_hasTrailer);
        return _responseTrailer;
    }
    
    void abort()
    {
        if (_responseDone) {
            return;
        }
        synchronized (_conn._pendingRequests) {
            _conn._requestException = new Exception("No more requests are possible because a previous request resulted in an exception");
            auto it = _conn._pendingRequests.begin;
            assert(it.val == this);
            while (it != _conn._pendingRequests.end) {
                it.val._scheduler.schedule(it.val._fiber);
                ++it;
            }
            _conn._pendingRequests.clear();
            if (_hasResponse) synchronized (_conn._pendingResponses)  {
                _conn._responseException = new Exception("Unable to read response, because a previous response resulted in an exception");
                foreach(r, dummy; _conn._waitingResponses) {
                    r._scheduler.schedule(r._fiber);
                }
                bool[ClientRequest] empty;
                _conn._waitingResponses = empty;
            }
        }
    }

private:
    void ensureResponse()
    {
        if (_hasResponse)
            return;
        _hasResponse = true;
        bool wait;
        synchronized (_conn._pendingResponses) {
            if (_conn._responseException !is null)
                throw _conn._responseException;
            auto it = _conn._pendingResponses.begin;
            assert(it != _conn._pendingResponses.end);
            if (it.val != this) {
                _conn._waitingResponses[this] = true;
                wait = true;
            }
        }
        // If we weren't the first response in the queue, wait for someone else to schedule us
        if (wait) {
            _log.trace("Yielding response {}", this);
            Fiber.yield();
            synchronized (_conn._pendingResponses) {
                if (_conn._responseException !is null)
                    throw _conn._responseException;
            }
        }
        _log.trace("Reading response headers ({})", cast(void*)this);
        // Read and parse headers
        scope parser = new ResponseParser(_response);
        parser.run(_conn._readStream);
        if (parser.error) {
            throw new Exception("Error parsing response");
        }
        assert(parser.complete);
        _log.info("Got response {}", _response.toString());
        bool close;
        with (_response) {
            if (status.ver == Version(1, 0)) {
                if (general.connection is null || general.connection.find("keep-alive") == general.connection.end)
                    close = true;
            } else if (status.ver == Version(1, 1)) {
                if (general.connection !is null && general.connection.find("close") != general.connection.end)
                    close = true;
            } else {
                throw new Exception("Unrecognized HTTP server version.");
            }
            // Remove identity from the Transfer-Encodings
            for (size_t i = 0; i < general.transferEncoding.length; ++i) {
                if (general.transferEncoding[i].value == "identity") {
                    general.transferEncoding[i..$-1] = general.transferEncoding[i+1..$];
                    general.transferEncoding.length = general.transferEncoding.length - 1;
                    --i;
                }
            }
            if (general.transferEncoding.length > 0) {
                if (general.transferEncoding[$-1].value != "chunked") {
                    throw new Exception("The last transfer-encoding is not chunked.");
                }
                foreach (tc; general.transferEncoding[0..$-1]) {
                    switch(tc.value) {
                        case "chunked":
                            throw new Exception("chunked transfer-coding applied multiple times");
                        case "deflate":
                        case "gzip":
                        case "x-gzip":
                            break;
                        case "compress":
                        case "x-compress":
                            throw new Exception("compress transfer-coding is unsupported");
                        default:
                            throw new Exception("Unrecognized transfer-coding: " ~ tc.value);
                    }                    
                }
            }
        }

        if (close) {
            synchronized (_conn._pendingRequests) synchronized (_conn._pendingResponses) {
                _conn._requestException = new Exception("No more requests are possible because the server voluntarily closed the connection");
                _conn._responseException = new Exception("This request will not receive a response because the server voluntarily closed the connection on a previous response");
                auto it = _conn._pendingRequests.begin;
                if (it != _conn._pendingRequests.end) {
                    ++it;
                    while (it != _conn._pendingRequests.end) {
                        it.val._scheduler.schedule(it.val._fiber);
                        it = _conn._pendingRequests.erase(it);
                    }
                }
                foreach(r, b; _conn._waitingResponses) {
                    r._scheduler.schedule(r._fiber);
                }
                bool[ClientRequest] empty;
                _conn._waitingResponses = empty;
            }
        }
        with (_response) {
            if (!_conn.hasMessageBody(general, entity, _request.requestLine.method, status.status)) {
                _responseDone = true;
                if (close) {
                    _conn._stream.close();
                } else {
                    _conn.scheduleNextResponse();
                }
            }
        }
    }
    
    void requestDone()
    {
        if (_request.general.transferEncoding.length > 0) {
            string trailerString = _requestTrailer.toString() ~ "\r\n";
            if (trailerString != "\r\n")
                _log.info("Trailer: {}", trailerString);
            _conn._stream.write(trailerString);
        }
        _conn.scheduleNextRequest();
    }
    
    void responseDone()
    {
        if (_response.general.transferEncoding.length > 0) {
            // Read and parse the trailer
            scope parser = new TrailerParser(_responseTrailer);
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
                throw new Exception("Error parsing trailer");
            }
            string trailerString = _responseTrailer.toString();
            if (trailerString.length > 0)
                _log.info("Got trailer: {}", trailerString);
        }
        _responseDone = true;
        _conn.scheduleNextResponse();
    }

private:
    ClientConnection _conn;
    Scheduler _scheduler;
    Fiber _fiber;
    Request _request;
    Response _response;
    EntityHeaders _requestTrailer, _responseTrailer;
    Stream _requestStream, _responseStream;
    bool _requestDone;
    bool _hasResponse;
    bool _hasTrailer;
    bool _responseDone;
}
