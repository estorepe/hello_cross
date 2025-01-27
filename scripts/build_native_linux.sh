# scripts/build_native_linux.sh
#!/bin/bash

ARCH=${1:-x64}
mkdir -p assets/native/linux/$ARCH

if [ "$ARCH" = "arm64" ]; then
    # Install cross-compilation dependencies
    sudo apt-get update
    sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

    # ARM64 cross-compilation
    aarch64-linux-gnu-gcc native/c/hello.c -o assets/native/linux/$ARCH/hello_c
    aarch64-linux-gnu-g++ native/cpp/hello.cpp -o assets/native/linux/$ARCH/hello_cpp
    
    # Install rustup as regular user
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
    source "$HOME/.cargo/env"
    
    # Create a more detailed cargo config
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << EOF
[build]
target = "aarch64-unknown-linux-gnu"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
rustflags = [
    "-C", "link-arg=-mlinker-version=lld",
    "-C", "target-feature=+crt-static"
]
EOF

    # Clean and set up Rust target
    cargo clean
    cd native/rust
    rustup target add aarch64-unknown-linux-gnu
    
    # Build with explicit target specification
    cargo build --release --target aarch64-unknown-linux-gnu && \
    cp target/aarch64-unknown-linux-gnu/release/hello_rust ../../assets/native/linux/arm64/
    
    cd ../go && GOOS=linux GOARCH=arm64 go build -o ../../assets/native/linux/$ARCH/hello_go hello.go
else
    # x64 native compilation (unchanged)
    gcc native/c/hello.c -o assets/native/linux/$ARCH/hello_c
    g++ native/cpp/hello.cpp -o assets/native/linux/$ARCH/hello_cpp
    cd native/rust && cargo build --release && cp target/release/hello_rust ../../assets/native/linux/$ARCH/
    cd ../go && GOOS=linux GOARCH=amd64 go build -o ../../assets/native/linux/$ARCH/hello_go hello.go
fi
