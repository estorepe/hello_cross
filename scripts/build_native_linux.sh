# scripts/build_native_linux.sh
#!/bin/bash

ARCH=${1:-x64}
mkdir -p assets/native/linux/$ARCH

if [ "$ARCH" = "arm64" ]; then
    # ARM64 cross-compilation
    aarch64-linux-gnu-gcc native/c/hello.c -o assets/native/linux/$ARCH/hello_c
    aarch64-linux-gnu-g++ native/cpp/hello.cpp -o assets/native/linux/$ARCH/hello_cpp
    cd native/rust && 
    rustup target add aarch64-unknown-linux-gnu
    cargo build --release --target aarch64-unknown-linux-gnu && 
    cp target/aarch64-unknown-linux-gnu/release/hello_rust ../../assets/native/linux/$ARCH/
    cd ../go && 
    GOOS=linux GOARCH=arm64 go build -o ../../assets/native/linux/$ARCH/hello_go hello.go
else
    # x64 native compilation
    gcc native/c/hello.c -o assets/native/linux/$ARCH/hello_c
    g++ native/cpp/hello.cpp -o assets/native/linux/$ARCH/hello_cpp
    cd native/rust && cargo build --release && 
    cp target/release/hello_rust ../../assets/native/linux/$ARCH/
    cd ../go && 
    GOOS=linux GOARCH=amd64 go build -o ../../assets/native/linux/$ARCH/hello_go hello.go
fi

