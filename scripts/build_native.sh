#!/bin/bash

ARCH=${1:-x64}

mkdir -p assets/native/linux

case $ARCH in
  x64)
    gcc native/c/hello.c -o assets/native/linux/hello_c
    g++ native/cpp/hello.cpp -o assets/native/linux/hello_cpp
    cd native/rust && cargo build --release && cp target/release/hello_rust ../../assets/native/linux/
    cd ../go && GOOS=linux GOARCH=amd64 go build -o ../../assets/native/linux/hello_go hello.go
    ;;

  arm64)
    # Native compilation on ARM runner
    gcc native/c/hello.c -o assets/native/linux/hello_c
    g++ native/cpp/hello.cpp -o assets/native/linux/hello_cpp
    cd native/rust && cargo build --release && cp target/release/hello_rust ../../assets/native/linux/
    cd ../go && GOOS=linux GOARCH=arm64 go build -o ../../assets/native/linux/hello_go hello.go
    ;;
esac
