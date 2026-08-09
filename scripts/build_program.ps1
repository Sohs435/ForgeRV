$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $scriptDirectory = (Get-Location).Path
}
else {
    $scriptDirectory = $PSScriptRoot
}

$sourcePath = Join-Path $scriptDirectory "program.S"
$linkerPath = Join-Path $scriptDirectory "linker.ld"
$elfPath = Join-Path $scriptDirectory "program.elf"
$binaryPath = Join-Path $scriptDirectory "program.bin"
$dumpPath = Join-Path $scriptDirectory "program.dump"
$mapPath = Join-Path $scriptDirectory "program.map"

$instructionMemoryDepthWords = 256
$instructionMemorySizeBytes = $instructionMemoryDepthWords * 4

if (-not (Test-Path $sourcePath)) {
    throw "Cannot find $sourcePath"
}

if (-not (Test-Path $linkerPath)) {
    throw "Cannot find $linkerPath"
}

if (-not (Get-Command "wsl.exe" -ErrorAction SilentlyContinue)) {
    throw "WSL is not installed"
}

& wsl.exe bash -lc "command -v riscv64-unknown-elf-gcc >/dev/null"

if ($LASTEXITCODE -ne 0) {
    throw "The RISC-V compiler is not installed inside WSL"
}

$wslDirectory = "/mnt/c/root_pqnq/RISC-V/streamcore-rv/scripts"

$buildCommands = @"
set -e

cd '$wslDirectory'

rm -f program.elf
rm -f program.bin
rm -f program.dump
rm -f program.map

riscv64-unknown-elf-gcc \
    -march=rv32i \
    -mabi=ilp32 \
    -mno-relax \
    -nostdlib \
    -nostartfiles \
    -static \
    -Wl,-T,linker.ld \
    -Wl,--no-relax \
    -Wl,--build-id=none \
    -Wl,-Map,program.map \
    -o program.elf \
    program.S

riscv64-unknown-elf-objcopy \
    -O binary \
    -j .text \
    program.elf \
    program.bin

riscv64-unknown-elf-objdump \
    -d \
    -M no-aliases,numeric \
    program.elf \
    > program.dump
"@

Write-Host ""
Write-Host "Building program.S for ForgeRV through WSL"
Write-Host "------------------------------------------------"

& wsl.exe bash -lc $buildCommands

if ($LASTEXITCODE -ne 0) {
    throw "ForgeRV program build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $elfPath)) {
    throw "Build completed without generating program.elf"
}

if (-not (Test-Path $binaryPath)) {
    throw "Build completed without generating program.bin"
}

if (-not (Test-Path $dumpPath)) {
    throw "Build completed without generating program.dump"
}

if (-not (Test-Path $mapPath)) {
    throw "Build completed without generating program.map"
}

$programSizeBytes = (Get-Item $binaryPath).Length

if ($programSizeBytes -eq 0) {
    throw "Generated program.bin is empty"
}

if (($programSizeBytes % 4) -ne 0) {
    throw "Generated program size is not a multiple of four bytes"
}

if ($programSizeBytes -gt $instructionMemorySizeBytes) {
    throw "Generated program exceeds the 1,024-byte instruction memory"
}

$instructionCount = $programSizeBytes / 4
$remainingInstructions = $instructionMemoryDepthWords - $instructionCount

Write-Host ""
Write-Host "Build completed successfully"
Write-Host "----------------------------"
Write-Host "Instructions: $instructionCount / $instructionMemoryDepthWords"
Write-Host "Program size: $programSizeBytes / $instructionMemorySizeBytes bytes"
Write-Host "Unused instruction words: $remainingInstructions"
Write-Host "ELF file: $elfPath"
Write-Host "Binary file: $binaryPath"
Write-Host "Disassembly: $dumpPath"
Write-Host "Linker map: $mapPath"