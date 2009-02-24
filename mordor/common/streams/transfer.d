module mordor.common.streams.transfer;

import tango.math.Math;
import tango.util.log.Log;

import mordor.common.config;
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

result_t transferStream(Stream src, Stream dst, long toTransfer, out long totalRead, out long totalWritten,
                        out result_t readResult, out result_t writeResult)
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
    Buffer buf1 = new Buffer, buf2 = new Buffer;
    Buffer* readBuffer, writeBuffer;
    size_t chunkSize = _chunkSize.val;
    size_t todo;
    
    void read()
    {
        todo = chunkSize;
        if (toTransfer != -1L && toTransfer - totalRead < todo)
            todo = toTransfer;
        readResult = src.read(*readBuffer, todo);
        if (SUCCEEDED(readResult)) {
            totalRead += readResult;
        }
    }
    
    void write()
    {
        while(writeBuffer.readAvailable > 0) {
            writeResult = dst.write(*writeBuffer, writeBuffer.readAvailable);
            if (writeResult == 0)
                writeResult = MORDOR_E_ZEROLENGTHWRITE;
            if (FAILED(writeResult))
                break;
            writeBuffer.consume(writeResult);
            totalWritten += writeResult;
        }
    }
    
    _log.trace("Transferring from {} to {}, limit {}", cast(void*)src,
        cast(void*)dst, toTransfer);        
    readBuffer = &buf1;
    read();
    _log.trace("Read {} from {}", readResult, cast(void*)src);
    if (readResult == 0 && toTransfer != -1L)
        return MORDOR_E_UNEXPECTEDEOF;
    if (FAILED(readResult))
        return MORDOR_E_READFAILURE;
    if (readResult == 0)
        return S_OK;
    
    while (totalRead < toTransfer  || toTransfer == -1L) {
        writeBuffer = readBuffer;
        if (readBuffer == &buf1)
            readBuffer = &buf2;
        else
            readBuffer = &buf1;
        parallel_do(&read, &write);
        _log.trace("Read {} from {}; wrote {} to {}; {}/{} total read/written",
            readResult, cast(void*)src, writeResult, cast(void*)dst, totalRead, totalWritten);
        if (readResult == 0 && toTransfer != -1L)
            return MORDOR_E_UNEXPECTEDEOF;
        if (FAILED(readResult))
            return MORDOR_E_READFAILURE;
        if (FAILED(writeResult))
            return MORDOR_E_WRITEFAILURE;
        if (readResult == 0)
            return S_OK;
    }
    writeBuffer = readBuffer;
    write();
    _log.trace("Wrote {} to {}; {}/{} total read/written", writeResult,
        cast(void*)dst, totalRead, totalWritten);
    if (FAILED(writeResult))
        return MORDOR_E_WRITEFAILURE;
    return S_OK;
}

result_t transferStream(Stream src, Stream dst)
{
    long totalRead, totalWritten;
    result_t readResult, writeResult;
    return transferStream(src, dst, -1L, totalRead, totalWritten, readResult, writeResult);
}

result_t transferStream(Stream src, Stream dst, long toTransfer)
{
    long totalRead, totalWritten;
    result_t readResult, writeResult;
    return transferStream(src, dst, toTransfer, totalRead, totalWritten, readResult, writeResult);
}

result_t transferStream(Stream src, Stream dst, out long totalRead, out long totalWritten)
{
    result_t readResult, writeResult;
    return transferStream(src, dst, -1L, totalRead, totalWritten, readResult, writeResult);
}

result_t transferStream(Stream src, Stream dst, long toTransfer, out long totalRead, out long totalWritten)
{
    result_t readResult, writeResult;
    return transferStream(src, dst, toTransfer, totalRead, totalWritten, readResult, writeResult);
}

result_t transferStream(Stream src, Stream dst, out long totalRead, out long totalWritten,
                        out result_t readResult, out result_t writeResult)
{
    return transferStream(src, dst, -1L, totalRead, totalWritten, readResult, writeResult);
}
