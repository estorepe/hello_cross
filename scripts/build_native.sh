#!/bin/bash
# Build to assets instead of native/bin
mkdir -p assets/native/linux

# C
gcc native/c/hello.c -o assets/native/linux/hello_c

# C++
g++ native/cpp/hello.cpp -o assets/native/linux/hello_cpp

# Rust
cd native/rust && cargo build --release && cp target/release/hello_rust ../../assets/native/linux/

# Go
cd ../go && GOOS=linux GOARCH=amd64 go build -o ../../assets/native/linux/hello_go hello.go

# Set permissions
chmod +x ../../assets/native/linux/*
