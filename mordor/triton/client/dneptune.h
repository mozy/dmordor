#ifndef __DNEPTUNE_H__
#define __DNEPTUNE_H__

extern "C" {

int dneptuneInit();
int dneptuneTerminate();

typedef struct _RestoreFile
{
    void* context;
    size_t pathLength;
    const char* path;
    long long version;
    size_t tempPathLength;
    const char* tempPath;
} RestoreFile;

typedef void (*FileRestoredCB)(void*, int, long long);
typedef void (*RestoreDoneCB)(void*, int);

int dneptuneRestoreFiles(const char* tritonHost,
                         size_t count, RestoreFile* files,
                         const char* username,
                         long long machineId,
                         FileRestoredCB fileCB, RestoreDoneCB doneCB,
                         void* context);

}

#endif
