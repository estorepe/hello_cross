#!/bin/bash
go mod init
GOOS=linux GOARCH=amd64 go build -o ../bin/linux/hello_go hello.go
