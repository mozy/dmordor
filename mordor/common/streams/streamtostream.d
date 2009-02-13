module mordor.common.streams.streamtostream;

import tango.io.Stdout;

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
    Fiber thisFiber = Fiber.getThis;
    Fiber readFiber, writeFiber;
    size_t chunkSize = 65536;
    size_t ticket = Scheduler.getThis.ticket;
    
    readFiber = new Fiber(delegate void() {
        bool first = true;
        while (toTransfer > 0 || toTransfer == -1L) {
            if (readBuffer == &buf1)
                readBuffer = &buf2;
            else
                readBuffer = &buf1;
            size_t todo = chunkSize;
            if (toTransfer != -1L && toTransfer < todo)
                todo = toTransfer;
            readResult = src.read(*readBuffer, todo);
            if (readResult == 0 && toTransfer != -1L) {
                readResult = -1;
            }
            if (readResult <= 0) {
                if (first) {
                    // writeFiber has never been run
                    break;
                } else {
                    // Wait for the previous write to finish
                    Scheduler.getThis.wait(ticket);
                    // Signal write fiber to cleanup
                    writeBuffer = readBuffer;
                    writeBuffer.clear();
                    Scheduler.getThis.schedule(writeFiber);
                    // Wait for write fiber to complete
                    Scheduler.getThis.wait(ticket);
                    break;
                }
            }
            if (toTransfer != -1L) {
                toTransfer -= readResult;
            }
            if (first) {
                first = false;
            } else {
                // Wait for the previous write to finish
                Scheduler.getThis.wait(ticket);
                if (writeResult <= 0) {
                    break;
                }
            }
            writeBuffer = readBuffer;

            Scheduler.getThis.schedule(writeFiber);
            if (toTransfer == 0) {
                // Wait for the previous write to finish
                Scheduler.getThis.wait(ticket);
                // Signal write fiber to cleanup
                writeBuffer = readBuffer;
                writeBuffer.clear();
                Scheduler.getThis.schedule(writeFiber);
                // Wait for write fiber to complete
                Scheduler.getThis.wait(ticket);
            }
        }
        // This may not be accurate in a multi-threaded environment... we
        // might get here in another thread before the fiber actually
        // terminates
        assert(writeFiber.state == Fiber.State.TERM);
        Scheduler.getThis.schedule(thisFiber);
    });
    
    writeFiber = new Fiber(delegate void() {
        while (true) {
            assert(writeBuffer != null);
            if (writeBuffer.readAvailable == 0) {
                Scheduler.getThis.schedule(readFiber, ticket);
                return;
            }
            while (writeBuffer.readAvailable > 0) {
                writeResult = dst.write(*writeBuffer, writeBuffer.readAvailable);
                if (writeResult <= 0) {
                    Scheduler.getThis.schedule(readFiber, ticket);
                    return;
                }
                transferred += writeResult;
                writeBuffer.consume(writeResult);
            }
            Scheduler.getThis.schedule(readFiber, ticket);
            Fiber.yield();
        }
    });

    Scheduler.getThis.schedule(readFiber);
    Fiber.yield();

    if (readResult < 0)
        return readResult;
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
