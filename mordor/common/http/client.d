module mordor.common.http.client;

import tango.core.Thread;

import mordor.common.containers.linkedlist;
public import mordor.common.http.http;
import mordor.common.scheduler;
public import mordor.common.streams.stream;
import mordor.common.stringutils;

class Connection
{
    this(Stream stream)
    in
    {
        assert(stream !is null);
        assert(stream.supportsRead);
        assert(stream.supportsWrite);
    }
    body
    {
        _pendingRequests = new LinkedList!(FiberAndScheduler, false)();
        _pendingResponses = new LinkedList!(FiberAndScheduler, false)();
        _stream = stream;
    }
    
    void request(Request requestHeaders, void delegate(Stream) request,
                 void delegate(Response, Stream) response)
    in
    {
        with (requestHeaders) {
            assert(requestLine.ver == Version.init ||
                   requestLine.ver == Version(1, 0) ||
                   requestLine.ver == Version(1, 1));
            assert(requestLine.uri.length > 0);
        }
    }
    body
    {        
        // Queue up the request
        bool wait = false;
        synchronized (_pendingRequests) {
            if (_requestException !is null)
                throw _requestException;

            wait = !_pendingRequests.empty;
            _pendingRequests.append(FiberAndScheduler(Fiber.getThis, Scheduler.getThis));
        }
        // If we weren't the first request in the queue, we have to wait for
        // another request to schedule us
        if (wait) {
            Fiber.yield();
            synchronized (_pendingRequests) if (_requestException !is null) {
                assert(_pendingRequests.begin.val.fiber == Fiber.getThis);
                _pendingRequests.erase(_pendingRequests.begin);
                if (!_pendingRequests.empty) {
                    auto fs = _pendingRequests.begin.val;
                    fs.scheduler.schedule(fs.fiber);
                }
                throw _requestException;
            }
        }

        bool close;
        // Do the request
        {
            scope (exit) synchronized (_pendingRequests) {
                assert(_pendingRequests.begin.val.fiber == Fiber.getThis);
                _pendingRequests.erase(_pendingRequests.begin);
                if (!_pendingRequests.empty) {
                    auto fs = _pendingRequests.begin.val;
                    fs.scheduler.schedule(fs.fiber);
                }
            }
            scope (failure) synchronized (_pendingRequests) {
                _requestException = new Exception("A previous exception has stopped processing of more requests");
            }
            
            synchronized (_pendingResponses) if (_responseException !is null)
                throw _responseException;

            Stream requestStream;
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
                        general.connection = new IStringSet();
                        general.connection.insert("keep-alive");
                    }
                }
                // Determine if we're closing the connection after this request
                if (requestLine.ver == Version(1, 0)) {
                    if (general.connection !is null && general.connection.find("keep-alive") != general.connection.end) {
                        close = false;
                    } else {
                        close = true;
                    }
                } else {
                    if (general.connection !is null && general.connection.find("close") != general.connection.end) {
                        close = true;
                    } else {
                        close = false;
                    }
                }
                
            }
            string requestHeadersString = requestHeaders.toString();
            _stream.write(requestHeadersString);
            // TODO: write request headers
            if (requestStream !is null)
                request(requestStream);
            
            synchronized (_pendingRequests) {
                auto it = _pendingRequests.begin;
                assert(it.val.fiber == Fiber.getThis);
                ++it;
                if (it != _pendingRequests.end || close) {
                    // No pending requests, make sure to flush
                    _stream.flush;
                }
                if (close) {
                    _requestException = new Exception("No more requests are possible because the connection was voluntarily closed");
                }
            }
        }
        
        wait = false;
        synchronized (_pendingResponses) {
            if (_responseException !is null)
                throw _responseException;
            wait = !_pendingResponses.empty;
            _pendingResponses.append(FiberAndScheduler(Fiber.getThis, Scheduler.getThis));
        }
        // If another response was still being processed, wait for it to schedule us
        if (wait) {
            Fiber.yield();
            synchronized (_pendingResponses) if (_responseException !is null) {
                assert(_pendingResponses.begin.val.fiber == Fiber.getThis);
                _pendingResponses.erase(_pendingResponses.begin);
                if (!_pendingResponses.empty) {
                    auto fs = _pendingResponses.begin.val;
                    fs.scheduler.schedule(fs.fiber);
                }
                throw _responseException;
            }
        }
        
        // Read the response
        {
            scope (exit) synchronized (_pendingResponses) {
                assert(_pendingResponses.begin.val.fiber == Fiber.getThis);
                _pendingResponses.erase(_pendingResponses.begin);
                if (!_pendingResponses.empty) {
                    auto fs = _pendingResponses.begin.val;
                    fs.scheduler.schedule(fs.fiber);
                }
            }
            scope (failure) synchronized (_pendingResponses) {
                _responseException = new Exception("A previous exception has stopped processing of more responses");
            }
            
            Response responseHeaders;
            Stream responseStream = _stream;
            // TODO: read HTTP headers
            with (responseHeaders) {
                if (status.ver == Version(1, 0)) {
                    if (general.connection is null || general.connection.find("keep-alive") == general.connection.end)
                        close = true;
                } else if (status.ver == Version(1, 1)) {
                    if (general.connection !is null && general.connection.find("close") != general.connection.end)
                        close = true;
                } else {
                    //throw new Exception("Unrecognized HTTP server version.");
                }
            }
            response(responseHeaders, responseStream);
            
            if (close) {
                synchronized (_pendingResponses) _responseException = new Exception("No more requests are possible because the server voluntarily closed the connection");
                _stream.close();
            }
        }
    }

private:
    struct FiberAndScheduler
    {
        Fiber fiber;
        Scheduler scheduler;
    }
private:
    Stream _stream;
    Exception _requestException, _responseException;
    LinkedList!(FiberAndScheduler, false) _pendingRequests;
    LinkedList!(FiberAndScheduler, false) _pendingResponses;
}
