#********************************************************************************
# Makefile for the libsnark library.
#********************************************************************************
#* @author     This file is part of libsnark, developed by SCIPR Lab
#*             and contributors (see AUTHORS).
#* @copyright  MIT license (see LICENSE file)
#*******************************************************************************/

CXXFLAGS += -O2 -Wall -Wextra -Wno-unused-parameter -Wno-comment -march=native -mtune=native -std=c++11

DEPSRC=depsrc
DEPINST=depinst

LDFLAGS += -L $(DEPINST)/lib -Wl,-rpath $(DEPINST)/lib
LDLIBS += -lgmpxx -lgmp
CXXFLAGS += -I $(DEPINST)/include -I src -DUSE_ASM
DEFAULT_CURVE=BN128

ifneq ($(NO_GTEST),1)
	GTESTDIR=/usr/src/gtest
# Recompile GTest, if we can (e.g., Ubuntu). Otherwise use precompiled one (e.g., Fedora).
# See https://code.google.com/p/googletest/wiki/FAQ#Why_is_it_not_recommended_to_install_a_pre-compiled_copy_of_Goog .
	COMPILE_GTEST:=$(shell test -d $(GTESTDIR) && echo 1)   # Found GTest sourcecode?
	LDLIBS += -lgtest -lpthread
endif

SRCS= \
	src/common/profiling.cpp \
	src/common/utils.cpp \
	src/gadgetlib2/examples/simple_example.cpp \
	src/gadgetlib2/infrastructure.cpp \
	src/gadgetlib2/adapters.cpp \
	src/gadgetlib2/constraint.cpp \
	src/gadgetlib2/gadget.cpp \
	src/gadgetlib2/integration.cpp \
	src/gadgetlib2/pp.cpp \
	src/gadgetlib2/protoboard.cpp \
	src/gadgetlib2/variable.cpp

EXECUTABLES= \
	src/r1cs_ppzksnark/examples/demo_r1cs_ppzksnark

ifneq ($(NO_GTEST),1)
	EXECUTABLES += \
		src/gadgetlib2/examples/tutorial \
		src/gadgetlib2/tests/gadgetlib2_test
endif

DOCS= README.html

# For documentation of the following options, see README.md .

ifeq ($(NO_PROCPS),1)
	CXXFLAGS += -DNO_PROCPS
else
	LDLIBS += -lprocps
endif

ifeq ($(LOWMEM),1)
	CXXFLAGS += -DLOWMEM
endif

ifeq ($(STATIC),1)
	CXXFLAGS += -static -DSTATIC
else
	CXXFLAGS += -fPIC
endif

ifeq ($(PROFILE_OP_COUNTS),1)
	CXXFLAGS += -static -DPROFILE_OP_COUNTS
endif

ifeq ($(MULTICORE),1)
	CXXFLAGS += -DMULTICORE -fopenmp
endif

ifeq ($(CPPDEBUG),1)
        CXXFLAGS += -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC
        DEBUG = 1
endif

ifeq ($(DEBUG),1)
        CXXFLAGS += -DDEBUG -ggdb3
endif

ifeq ($(PERFORMANCE),1)
        CXXFLAGS += -flto -fuse-linker-plugin
        CXXFLAGS += -march=native -mtune=native
        CXXFLAGS += -DNDEBUG
        LDFLAGS += -flto
endif

ifeq ($(CURVE),)
	CURVE = $(DEFAULT_CURVE)
endif
CXXFLAGS += -DCURVE_$(CURVE)

ifeq ($(CURVE),EDWARDS)
endif

ifeq ($(CURVE),BN128)
	SRCS += \
	        src/algebra/curves/bn128/bn128_g1.cpp \
		src/algebra/curves/bn128/bn128_g2.cpp \
	        src/algebra/curves/bn128/bn128_gt.cpp \
		src/algebra/curves/bn128/bn128_init.cpp \
	        src/algebra/curves/bn128/bn128_pairing.cpp \
		src/algebra/curves/bn128/bn128_pp.cpp
	CXXFLAGS += -DBN_SUPPORT_SNARK
	LDLIBS += -lzm
endif

ifeq ($(CURVE),ALT_BN128)
	SRCS += \
		src/algebra/curves/alt_bn128/alt_bn128_g1.cpp \
		src/algebra/curves/alt_bn128/alt_bn128_g2.cpp \
		src/algebra/curves/alt_bn128/alt_bn128_init.cpp \
		src/algebra/curves/alt_bn128/alt_bn128_pairing.cpp \
		src/algebra/curves/alt_bn128/alt_bn128_pp.cpp
endif

ifeq ($(CURVE),EDWARDS)
	SRCS += \
	        src/algebra/curves/edwards/edwards_g1.cpp \
	        src/algebra/curves/edwards/edwards_g2.cpp \
	        src/algebra/curves/edwards/edwards_init.cpp \
	        src/algebra/curves/edwards/edwards_pairing.cpp \
	        src/algebra/curves/edwards/edwards_pp.cpp
endif

OBJS=$(patsubst %.cpp,%.o,$(SRCS))

ifeq ($(strip $(COMPILE_GTEST)),1)
all: libgtest.a $(EXECUTABLES) doc
else
all: $(EXECUTABLES) doc
endif

doc: $(DOCS)

# In order to detect changes to #include dependencies. -MMD below generates a .d file for .cpp file. Include the .d file.
-include $(SRCS:.cpp=.d)

$(OBJS): %.o: %.cpp
	$(CXX) -o $@ $< -c -MMD $(CXXFLAGS)

libgtest.a: $(GTESTDIR)/src/gtest-all.cc
	$(CXX) -I $(GTESTDIR) -c -isystem $(GTESTDIR)/include $< $(CXXFLAGS) -o $(DEPINST)/lib/gtest-all.o
	$(AR) -rv $(DEPINST)/lib/libgtest.a $(DEPINST)/lib/gtest-all.o

src/gadgetlib2/tests/gadgetlib2_test: src/gadgetlib2/tests/adapters_UTEST.cpp src/gadgetlib2/tests/constraint_UTEST.cpp src/gadgetlib2/tests/gadget_UTEST.cpp src/gadgetlib2/tests/protoboard_UTEST.cpp src/gadgetlib2/tests/variable_UTEST.cpp

$(EXECUTABLES): %: %.o $(OBJS)
	$(CXX) -o $@ $^ $(CXXFLAGS) $(LDFLAGS) $(LDLIBS)

ifeq ($(STATIC),1)
libsnark.a: $(OBJS)
	$(AR) cr $@ $^
LIBOBJ=libsnark.a
else
libsnark.so: $(OBJS)
	$(CXX) -o $@ $^ -shared $(CXXFLAGS) $(LDFLAGS) $(LDLIBS)
LIBOBJ=libsnark.so
endif

lib:	$(LIBOBJ)


$(DOCS): %.html: %.md
ifneq ($(NO_DOCS),1)
	markdown_py -f $@ $^ -x toc -x extra --noisy
#	TODO: Would be nice to enable "-x smartypants" but Ubuntu 12.04 doesn't support that.
#	TODO: switch to redcarpet, to produce same output as GitHub's processing of README.md. But what about TOC?
endif

ifeq ($(PREFIX),)
install:
	$(error Please provide PREFIX. E.g. make install PREFIX=/usr)
else
HEADERS_SRC=$(shell find src -name '*.hpp' -o -name '*.tcc')
HEADERS_DEST=$(patsubst src/%,$(PREFIX)/include/libsnark/%,$(HEADERS_SRC))

$(HEADERS_DEST): $(PREFIX)/include/libsnark/%: src/%
	mkdir -p $(shell dirname $@)
	cp $< $@

install: lib $(HEADERS_DEST)
	mkdir -p $(PREFIX)/lib
	cp $(LIBOBJ) $(PREFIX)/lib/$(LIBOBJ)
	cp -rv $(DEPINST)/lib $(PREFIX)
	cp -rv $(DEPINST)/include $(PREFIX)
endif

doxy:
	doxygen doxygen.conf

# Clean generated files, except locally-compiled dependencies
clean:
	$(RM) \
		$(OBJS) \
		$(EXECUTABLES) \
		$(DOCS) \
		${patsubst %,%.o,${EXECUTABLES}} \
		${patsubst %.cpp,%.d,${SRCS}} \
		libsnark.so libsnark.a \
	$(RM) -fr doxygen/ \
	$(RM) $(DEPINST)/lib/libgtest.a $(DEPINST)/lib/gtest-all.o

# Clean all, including locally-compiled dependencies
clean-all: clean
	rm -fr $(DEPSRC) $(DEPINST)

.PHONY: all clean clean-all doc doxy lib
