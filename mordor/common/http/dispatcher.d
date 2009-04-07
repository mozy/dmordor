module mordor.common.http.dispatcher;

import mordor.common.http.http;
import mordor.common.http.servlet;
import mordor.common.streams.stream;

struct Context
{
    Request request;
    Response response;
}

class DefaultServlet : Servlet
{
    bool handle(Context context)
    {
        context.response.status.status = Status.NOT_FOUND;
        return true;
    }    
}

class Dispatcher
{
public:
    static this()
    {
        _defaultServlet = new DefaultServlet;
    }

    void registerServlet(Servlet s)
    {
        _servlets ~= s;
    }

    void dispatch(Stream stream)
    in
    {
        assert(stream.supportsRead);
        assert(stream.supportsWrite);
    }
    body
    {
        while (true) {
            Context context;
            parseRequest(stream, context.request);
            bool handled = false;
            foreach(servlet; _servlets) {
                if (servlet.handle(context)) {
                    handled = true;
                    break;
                }
            }
            if (!handled) {
                _defaultServlet.handle(context);
            }
            if (context.response.general.connection.contains("close"))
                break;
        }
    }
    
private:
    static Servlet _defaultServlet;
    Servlet[] _servlets;
}
