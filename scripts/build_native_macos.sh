# scripts/build_native_macos.sh
#!/bin/bash

mkdir -p assets/native/macos/x64

clang native/c/hello.c -o assets/native/macos/x64/hello_c
clang++ native/cpp/hello.cpp -o assets/native/macos/x64/hello_cpp
cd native/rust && cargo build --release && cp target/release/hello_rust ../../assets/native/macos/x64/
cd ../go && GOOS=darwin GOARCH=amd64 go build -o ../../assets/native/macos/x64/hello_go hello.go
