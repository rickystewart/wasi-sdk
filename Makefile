# Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/

ROOT_DIR=${CURDIR}
LLVM_PROJ_DIR?=$(ROOT_DIR)/src/llvm-project
PREFIX?=$(ROOT_DIR)/opt/wasi-sdk

CLANG_VERSION=$(shell $(MOZ_FETCHES_DIR)/clang/bin/llvm-config --version)

default: build ;

clean:
	rm -rf build $(PREFIX)

build/wasi-libc.BUILT:
	$(MAKE) -C $(ROOT_DIR)/src/wasi-libc \
		WASM_CC=$(PREFIX)/bin/clang \
		SYSROOT=$(PREFIX)/share/wasi-sysroot
	touch build/wasi-libc.BUILT

build/compiler-rt.BUILT:
	mkdir -p build/compiler-rt
	cd build/compiler-rt; cmake -G Ninja \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_HAS_FPIC_FLAG=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DWASI_SDK_PREFIX=$(PREFIX) \
                -DWASI_CLANG=$(MOZ_FETCHES_DIR)/clang \
		-DCMAKE_C_FLAGS="-O1" \
		-DLLVM_CONFIG_PATH=$(MOZ_FETCHES_DIR)/clang/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=wasi \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX)/lib/clang/$(CLANG_VERSION)/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(LLVM_PROJ_DIR)/compiler-rt/lib/builtins
	ninja -v -C build/compiler-rt install
	cp -R $(MOZ_FETCHES_DIR)/clang/lib/clang $(PREFIX)/lib/
	touch build/compiler-rt.BUILT

build/libcxx.BUILT: build/compiler-rt.BUILT build/wasi-libc.BUILT
	mkdir -p build/libcxx
	cd build/libcxx; cmake -G Ninja \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DLLVM_CONFIG_PATH=$(MOZ_FETCHES_DIR)/clang/bin/llvm-config \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		-DLIBCXX_ENABLE_THREADS:BOOL=OFF \
		-DLIBCXX_HAS_PTHREAD_API:BOOL=OFF \
		-DLIBCXX_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
		-DLIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
		-DLIBCXX_HAS_WIN32_THREAD_API:BOOL=OFF \
		-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
		-DLIBCXX_ENABLE_SHARED:BOOL=OFF \
		-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
		-DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF \
		-DLIBCXX_ENABLE_FILESYSTEM:BOOL=OFF \
		-DLIBCXX_CXX_ABI=libcxxabi \
		-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$(LLVM_PROJ_DIR)/libcxxabi/include \
		-DLIBCXX_HAS_MUSL_LIBC:BOOL=ON \
		-DLIBCXX_ABI_VERSION=2 \
		-DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasi \
		-DWASI_SDK_PREFIX=$(PREFIX) \
                -DWASI_CLANG=$(MOZ_FETCHES_DIR)/clang \
		--debug-trycompile \
		$(LLVM_PROJ_DIR)/libcxx
	ninja -v -C build/libcxx install
	touch build/libcxx.BUILT

build/libcxxabi.BUILT: build/libcxx.BUILT
	mkdir -p build/libcxxabi
	cd build/libcxxabi; cmake -G Ninja \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		-DCMAKE_CXX_COMPILER_WORKS=ON \
		-DCMAKE_C_COMPILER_WORKS=ON \
		-DLIBCXXABI_ENABLE_EXCEPTIONS:BOOL=OFF \
		-DLIBCXXABI_ENABLE_SHARED:BOOL=OFF \
		-DLIBCXXABI_SILENT_TERMINATE:BOOL=ON \
		-DLIBCXXABI_ENABLE_THREADS:BOOL=OFF \
		-DLIBCXXABI_HAS_PTHREAD_API:BOOL=OFF \
		-DLIBCXXABI_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
		-DLIBCXXABI_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
		-DLIBCXXABI_HAS_WIN32_THREAD_API:BOOL=OFF \
		$(if $(patsubst 8.%,,$(CLANG_VERSION)),-DLIBCXXABI_ENABLE_PIC:BOOL=OFF,) \
		-DCXX_SUPPORTS_CXX11=ON \
		-DLLVM_COMPILER_CHECKED=ON \
		-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
		-DLIBCXXABI_LIBCXX_PATH=$(LLVM_PROJ_DIR)/libcxx \
		-DLIBCXXABI_LIBCXX_INCLUDES=$(PREFIX)/share/wasi-sysroot/include/c++/v1 \
		-DLLVM_CONFIG_PATH=$(MOZ_FETCHES_DIR)/clang/bin/llvm-config \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasi-sdk.cmake \
		-DLIBCXXABI_LIBDIR_SUFFIX=/wasm32-wasi \
		-DWASI_SDK_PREFIX=$(PREFIX) \
                -DWASI_CLANG=$(MOZ_FETCHES_DIR)/clang \
		-DUNIX:BOOL=ON \
		--debug-trycompile \
		$(LLVM_PROJ_DIR)/libcxxabi
	ninja -v -C build/libcxxabi install
	touch build/libcxxabi.BUILT

build/config.BUILT:
	mkdir -p $(PREFIX)/share/misc
	cp src/config/config.sub src/config/config.guess $(PREFIX)/share/misc
	mkdir -p $(PREFIX)/share/cmake
	cp wasi-sdk.cmake $(PREFIX)/share/cmake
	touch build/config.BUILT

build: build/wasi-libc.BUILT build/compiler-rt.BUILT build/libcxxabi.BUILT build/libcxx.BUILT build/config.BUILT

.PHONY: default clean build
