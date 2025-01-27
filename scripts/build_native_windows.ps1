# scripts/build_native_windows.ps1

# Create output directory
New-Item -ItemType Directory -Force -Path "assets/native/windows/x64"

# Set up Visual Studio environment variables
$vsPath = &"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
if ($vsPath) {
    $batchPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
    $configCmd = "`"$batchPath`" && set"
    cmd /c $configCmd | ForEach-Object {
        if ($_ -match '=') {
            $v = $_.split('=', 2)
            Set-Item -Force "env:\$($v[0])" -Value "$($v[1])"
        }
    }
}

# Build C program
cl.exe /nologo native\c\hello.c /Fe:"assets\native\windows\x64\hello_c.exe"
if ($LASTEXITCODE -ne 0) {
    Write-Error "C compilation failed"
    exit 1
}

# Build C++ program
cl.exe /nologo native\cpp\hello.cpp /Fe:"assets\native\windows\x64\hello_cpp.exe"
if ($LASTEXITCODE -ne 0) {
    Write-Error "C++ compilation failed"
    exit 1
}

# Build Rust program
Push-Location native\rust
cargo build --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Rust compilation failed"
    exit 1
}
Copy-Item "target\release\hello_rust.exe" "..\..\assets\native\windows\x64\hello_rust.exe"
Pop-Location

# Build Go program
Push-Location native\go
$env:GOOS = "windows"
$env:GOARCH = "amd64"
go build -o "..\..\assets\native\windows\x64\hello_go.exe" hello.go
if ($LASTEXITCODE -ne 0) {
    Write-Error "Go compilation failed"
    exit 1
}
Pop-Location

Write-Host "All binaries built successfully" -ForegroundColor Green
