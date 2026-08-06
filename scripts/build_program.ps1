param (
    [string]$ToolchainPrefix = ""
)

$ErrorActionPreference = "Stop"

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

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

if ($ToolchainPrefix -eq "") {
    $candidatePrefixes = @(
        "riscv-none-elf-",
        "riscv64-unknown-elf-",
        "riscv32-unknown-elf-"
    )

    foreach ($candidatePrefix in $candidatePrefixes) {
        if (Get-Command "${candidatePrefix}gcc" -ErrorAction SilentlyContinue) {
            $ToolchainPrefix = $candidatePrefix
            break
        }
    }
}

if ($ToolchainPrefix -eq "") {
    throw "GNU RISC-V compiler not found. Add its bin folder to PATH or pass -ToolchainPrefix."
}

$compiler = Get-Command "${ToolchainPrefix}gcc" -ErrorAction Stop
$objectCopy = Get-Command "${ToolchainPrefix}objcopy" -ErrorAction Stop
$objectDump = Get-Command "${ToolchainPrefix}objdump" -ErrorAction Stop

Write-Host "Building program.S for ForgeRV with $ToolchainPrefix"

& $compiler.Source `
    -march=rv32i `
    -mabi=ilp32 `
    -mno-relax `
    -nostdlib `
    -nostartfiles `
    -static `
    "-Wl,-T,$linkerPath" `
    -Wl,--no-relax `
    -Wl,--build-id=none `
    "-Wl,-Map,$mapPath" `
    -o $elfPath `
    $sourcePath

if ($LASTEXITCODE -ne 0) {
    throw "Assembly or linking failed"
}

& $objectCopy.Source -O binary -j .text $elfPath $binaryPath

if ($LASTEXITCODE -ne 0) {
    throw "Binary conversion failed"
}

& $objectDump.Source -d -M no-aliases,numeric $elfPath |
    Out-File -FilePath $dumpPath -Encoding ascii

if ($LASTEXITCODE -ne 0) {
    throw "Disassembly failed"
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

Write-Host "Build completed successfully"
Write-Host "Instructions: $instructionCount / $instructionMemoryDepthWords"
Write-Host "Program size: $programSizeBytes / $instructionMemorySizeBytes bytes"
Write-Host "Unused instruction words: $remainingInstructions"
Write-Host "ELF file: $elfPath"
Write-Host "Binary file: $binaryPath"
Write-Host "Disassembly: $dumpPath"
Write-Host "Linker map: $mapPath"
