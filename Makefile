PLATFORM = $(shell uname -s)

CFLAGS += -arch i386 -arch ppc

DFLAGS = -debug -g -odobj -L-lgtango -debug=drama
# DFLAGS = -release -inline -O -odobj -L-lgtango

DFILES = \
		 drama/Drama.d \
		 drama/GameBase.d \
		 drama/Graphics.d \
		 drama/Input.d \
		 drama/Sound.d \
		 drama/soundstream/Ogg.d \
		 drama/soundstream/Wav.d \
		 drama/util/General.d

IGNOREDOCS = \
			 $(wildcard drama/c/*) \
			 $(wildcard drama/system/*)

ifeq ($(PLATFORM), Darwin)
	DFLAGS += -version=Posix -arch i386 -arch ppc \
			  -framework Cocoa -framework OpenGL \
			  -framework OpenAL
	PLATOBJS = obj/MacOSX10.4u/DramaMac.o \
			   libs/MacOSX10.4u/*.a
	DFILES += drama/system/OSX.d
endif

# Main lib

obj/libdrama.a: $(PLATOBJS) $(DFILES)
	gdmd $(DFILES) $(DFLAGS) -c
	libtool -static -o obj/libdrama.a obj/*.o $(PLATOBJS)

# Not really used yet -- just testing D .so support on OS X. I have succesfully
# linked the .so with test/tetris.d and created a UB using the .so
so: $(PLATOBJS) $(DFILES)
	gdmd $(DFILES) $(PLATOBJS) -arch i386 -debug -g -odobj -debug=drama -version=Posix -ofobj/libdrama.i386.so -L-lgtango -q,-dynamiclib,-fPIC,-fno-common,-nophobosli -framework OpenAL -framework OpenGL -framework Cocoa
	gdmd $(DFILES) $(PLATOBJS) -arch ppc -debug -g -odobj -debug=drama -version=Posix -ofobj/libdrama.ppc.so -L-lgtango -q,-dynamiclib,-fPIC,-fno-common,-nophobosli -framework OpenAL -framework OpenGL -framework Cocoa
	lipo -create -output obj/libdrama.so obj/libdrama.*.so

# Docs
docs: doc/modules.ddoc doc/index.html
	gdmd $(filter-out $(IGNOREDOCS), $(DFILES)) -version=Posix -c -o- -Dddoc doc/candy.ddoc doc/modules.ddoc

doc/modules.ddoc: $(DFILES)
	rm -f doc/*.html
	doc/candydoc/find_modules drama doc/modules.ddoc $(IGNOREDOCS)

doc/index.html: README.markdown doc/README.d
	ruby -rubygems -e "require 'bluecloth'; puts 'README_CONTENT = '; puts BlueCloth.new(File.read('README.markdown')).to_html" > doc/tmp.ddoc
	gdmd -o- -D -Dfdoc/index.html doc/candy.ddoc doc/modules.ddoc doc/tmp.ddoc doc/README.d
	rm -f doc/tmp.ddoc

# Platform specific files

obj/MacOSX10.4u/DramaMac.o: drama/DramaMac.m
	mkdir -p obj/MacOSX10.4u
	$(CC) $(CFLAGS) -c -o $@ $<

# Examples

obj/tetris: test/tetris.d obj/libdrama.a
	gdmd $(DFLAGS) $^ -Jtest -of$@

obj/tunnel_flyer: test/tunnel_flyer.d obj/libdrama.a
	gdmd $(DFLAGS) $^ -Jtest -of$@

clean:
	rm -f tetris libdrama.a
	rm -rf obj
.PHONY: clean
