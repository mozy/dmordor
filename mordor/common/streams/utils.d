module mordor.common.streams.utils;

import mordor.common.streams.buffered;
import mordor.common.streams.duplex;
import mordor.common.streams.singleplex;

// Convenience method for buffering only the read side of a stream
Stream bufferReadStream(Stream parent)
{
    return new DuplexStream(new BufferedStream(new SingleplexStream(parent, SingleplexStream.Type.READ)),
        new SingleplexStream(parent, SingleplexStream.Type.WRITE));
}
