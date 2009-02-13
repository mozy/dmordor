module mordor.common.streams.streamtostream;

import tango.core.Thread;
import tango.math.Math;

import mordor.common.scheduler;
import mordor.common.streams.stream;

result_t streamToStream(Stream src, Stream dst, out long transferred, long toTransfer)
in
{
    assert(src !is null);
    assert(dst !is null);
    assert(toTransfer >= 0L || toTransfer == -1L);
}
body
{
    Buffer buf1 = new Buffer, buf2 = new Buffer;
    Buffer* readBuffer, writeBuffer;
    result_t readResult, writeResult;
    size_t chunkSize = 65536;
    size_t todo;
    
    void read()
    {
        todo = chunkSize;
        if (toTransfer != -1L && toTransfer < todo)
            todo = toTransfer;
        readResult = src.read(*readBuffer, todo);
    }
    
    void write()
    {
        while(writeBuffer.readAvailable > 0) {
            writeResult = dst.write(*writeBuffer, writeBuffer.readAvailable);
            if (writeResult == 0)
                writeResult = -1;
            if (writeResult < 0)
                break;
            writeBuffer.consume(writeResult);
            transferred += writeResult;
        }
    }
    
    readBuffer = &buf1;
    read();
    if (readResult == 0 && toTransfer != -1L)
        readResult = -1;
    if (readResult < 0)
        return readResult;
    if (readResult == 0)
        return 0;    
    
    while (toTransfer > 0  || toTransfer == -1L) {
        writeBuffer = readBuffer;
        if (readBuffer == &buf1)
            readBuffer = &buf2;
        else
            readBuffer = &buf1;
        parallel_do(&read, &write);
        if (readResult == 0 && toTransfer != -1L)
            readResult = -1;
        if (readResult < 0)
            return readResult;
        if (writeResult < 0)
            return writeResult;
        if (readResult == 0)
            return 0;
    }
    writeBuffer = readBuffer;
    write();
    if (writeResult < 0)
        return writeResult;
    return 0;
}

result_t streamToStream(Stream src, Stream dst)
{
    long transferred;
    return streamToStream(src, dst, transferred, -1L);
}

result_t streamToStream(Stream src, Stream dst, out long transferred)
{
    return streamToStream(src, dst, transferred, -1L);
}
