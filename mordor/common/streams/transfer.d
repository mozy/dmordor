module mordor.common.streams.transfer;

import tango.math.Math;
import tango.util.log.Log;

import mordor.common.config;
import mordor.common.exception;
import mordor.common.scheduler;
import mordor.common.streams.stream;

private ConfigVar!(size_t) _chunkSize;
private Logger _log;

static this()
{
    _chunkSize =
    Config.lookup!(size_t)("stream.transfer.chunksize",
        cast(size_t)(64 * 1024), "Size of buffers to use when transferring streams");
    _log = Log.lookup("mordor.common.streams.transfer");
}

void transferStream(Stream src, Stream dst, long toTransfer, out long totalRead, out long totalWritten)
in
{
    assert(src !is null);
    assert(src.supportsRead);
    assert(dst !is null);
    assert(dst.supportsWrite);
    assert(toTransfer >= 0L || toTransfer == -1L);
}
body
{
    scope buf1 = new Buffer, buf2 = new Buffer;
    Buffer* readBuffer, writeBuffer;
    size_t chunkSize = _chunkSize.val;
    size_t todo;
    size_t readResult, writeResult;
    Exception readException, writeException;
    
    void read()
    {
        todo = chunkSize;
        if (toTransfer != -1L && toTransfer - totalRead < todo)
            todo = toTransfer;
        try {
            totalRead += readResult = src.read(*readBuffer, todo);
        } catch (Exception ex) {
            readException = ex;
        }
    }
    
    void write()
    {
        try {
            while(writeBuffer.readAvailable > 0) {
                 writeResult = dst.write(*writeBuffer, writeBuffer.readAvailable);
                 writeBuffer.consume(writeResult);
                 totalWritten += writeResult;
            }
        } catch (Exception ex) {
            writeException = ex;
        }
    }
    
    void throwException()
    {
        if (readException !is null || writeException !is null)
            throw new StreamTransferException(readException, writeException);
    }
    
    _log.trace("Transferring from {} to {}, limit {}", src, dst, toTransfer);        
    readBuffer = &buf1;
    read();
    throwException();
    _log.trace("Read {} from {}", readResult, src);
    if (readResult == 0 && toTransfer != -1L)
        throw new UnexpectedEofException();
    if (readResult == 0)
        return;

    while (totalRead < toTransfer  || toTransfer == -1L) {
        writeBuffer = readBuffer;
        if (readBuffer == &buf1)
            readBuffer = &buf2;
        else
            readBuffer = &buf1;
        parallel_do(&read, &write);
        throwException();
        _log.trace("Read {} from {}; wrote {} to {}; {}/{} total read/written",
            readResult, src, writeResult, dst, totalRead, totalWritten);
        if (readResult == 0 && toTransfer != -1L)
            throw new UnexpectedEofException();
        if (readResult == 0)
            return;
    }
    writeBuffer = readBuffer;
    write();
    throwException();
    _log.trace("Wrote {} to {}; {}/{} total read/written", writeResult,
        dst, totalRead, totalWritten);
}

void transferStream(Stream src, Stream dst)
{
    long totalRead, totalWritten;
    return transferStream(src, dst, -1L, totalRead, totalWritten);
}

void transferStream(Stream src, Stream dst, long toTransfer)
{
    long totalRead, totalWritten;
    return transferStream(src, dst, toTransfer, totalRead, totalWritten);
}

void transferStream(Stream src, Stream dst, out long totalRead, out long totalWritten)
{
    return transferStream(src, dst, -1L, totalRead, totalWritten);
}

