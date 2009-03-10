module mordor.utils.manifestparser;

import tango.io.Stdout;

import mordor.common.exception;
import mordor.common.streams.buffered;
import mordor.common.streams.std;
import mordor.common.stringutils;
import mordor.triton.py.manifest;

int main(string[] args)
{
    scope Stream stdin = new BufferedStream(new StdinStream());
    
    try {
        parseManifest(stdin,
            delegate void(string file) {
                Stdout.formatln("File: {}", file);
            },
            null,
            delegate void(PatchInfo patch) {
                Stdout.formatln("Patch: {}", dataToHexstring(patch.hash));
            });
    } catch (PlatformException ex) {
        Stderr.formatln("{}", ex);
        return 1;
    }
    return 0;
}
