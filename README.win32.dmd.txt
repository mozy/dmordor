Install git, subversion, and patch packages from cygwin.com.

Download latest DMD 1.0 from www.digitalmars.com/d.  Extract to location of your choice (I chose C:\, to end up with C:\dmd).  Also download dmc.zip, since we'll need the C++ compiler to compile tango.  Add the bin folders for both to your path.

svn checkout http://svn.dsource.org/projects/tango/trunk into dmd\import.

git clone mordor from ssh://icarus.dechocorp.com/var/lib/git/mordor.git into a directory of your choice.

From a bash prompt (otherwise you will get errors because of the wildcard), go to the import directory, and type "cat <path/to/mordor>/patches/tango/*" | patch -p0"

Edit sc.ini as described in http://www.dsource.org/projects/tango/wiki/WindowsInstall

From the import\lib folder, run build-dmd.bat, then build-win32.bat.

Download dsss from http://www.dsource.org/projects/dsss, and add it to your path.

Make a directory somewhere, then *inside* that subfolder checkout http://svn.dsource.org/projects/bindings/trunk/win32 into win32.
In the *parent* of Make a dsss.conf file that contains:

[win32]
type=sourcelibrary

Then run "dsss install".

Go to your mordor checkout, and run dsss build.
