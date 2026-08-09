from pathlib import Path # open and read binary python file
from pynq import Overlay # loads fpga bitstream and reads corresponding hardware handoff file
from pynq import MMIO # Memory Mapped IO

#define bitstream and program file locations
BITSTREAM_PATH = "/home/xilinx/ForgeRV/forgerv.bit"
PROGRAM_PATH = "/home/xilinx/ForgeRV/programs/program.bin"

# the previous loader attempt already programmed the FPGA
# change this to True after restarting or powering off the PYNQ
DOWNLOAD_BITSTREAM = False

# physical address assigned to the instruction AXI BRAM Controller in the Vivado Address Editor
INSTRUCTION_MEMORY_BASE_ADDRESS = 0x40000000
INSTRUCTION_MEMORY_ADDRESS_RANGE = 0x1000 # Vivado assigned a 4 KiB address region

INSTRUCTION_MEMORY_DEPTH_WORDS = 256 # 256 words means 256 instruction capacity
INSTRUCTION_MEMORY_SIZE_BYTES = INSTRUCTION_MEMORY_DEPTH_WORDS * 4 # total memory used by instructions
# = 32 bits * 256 = 8192 bits = 1024 bytes

print("ForgeRV Program Loader", flush=True)
print("----------------------", flush=True)

if not Path(BITSTREAM_PATH).is_file():
    raise FileNotFoundError(
        f"FPGA bitstream does not exist: {BITSTREAM_PATH}"
    )

if not Path(PROGRAM_PATH).is_file():
    raise FileNotFoundError(
        f"Program binary does not exist: {PROGRAM_PATH}"
    )

program_data = Path(PROGRAM_PATH).read_bytes() # reads machine code of all instructions in program.bin

if len(program_data) == 0:
    raise RuntimeError("Program binary is empty") # no data in program.bin

if len(program_data) % 4 != 0:
    raise RuntimeError(
        "Program size is not a multiple of four bytes"
    ) # each instruction is 4 bytes we cannot have an instruction be incomplete hence the requirement that
# the total number of bytes is a multiple of 4

if len(program_data) > INSTRUCTION_MEMORY_SIZE_BYTES:
    raise RuntimeError(
        "Program is larger than the instruction memory"
    ) # cannot process a file that is greater than 1024 bytes given that 1024 is the maximum processible data

print(f"Bitstream: {BITSTREAM_PATH}", flush=True)
print(f"Program: {PROGRAM_PATH}", flush=True)
print(f"Program size: {len(program_data)} bytes", flush=True)
print(f"Instruction count: {len(program_data) // 4}", flush=True)

if DOWNLOAD_BITSTREAM:
    print("\nProgramming FPGA with ForgeRV bitstream...", flush=True)

    overlay = Overlay(
        BITSTREAM_PATH,
        download=True
    ) # programs fpga with forgerv.bit

    print("FPGA programming complete", flush=True)

else:
    print("\nSkipping FPGA programming because ForgeRV is already loaded", flush=True)

    overlay = Overlay(
        BITSTREAM_PATH,
        download=False
    ) # read the hardware handoff file without programming the FPGA again

    print("ForgeRV hardware description loaded", flush=True)

# create memory access object directly from the physical address assigned in Vivado
# the instruction AXI BRAM Controller does not appear in overlay.ip_dict on this PYNQ image
instruction_memory = MMIO(
    INSTRUCTION_MEMORY_BASE_ADDRESS,
    INSTRUCTION_MEMORY_ADDRESS_RANGE
) # create memory access object -> represents the memory region assigned to instruction BRAM controller

# we can now write to physical addresses and the AXI BRAM controller will translate that into a write into
# memory

print(
    f"Instruction memory base address: 0x{INSTRUCTION_MEMORY_BASE_ADDRESS:08X}",
    flush=True
)
print(
    f"Instruction memory address range: {INSTRUCTION_MEMORY_ADDRESS_RANGE} bytes",
    flush=True
)
print("\nWriting instructions into instruction memory...", flush=True)

for byte_address in range(0, len(program_data), 4): # byte_address reaches at most 1020
    # the final instruction occupies byte addresses 1020 to 1023
    instruction_bytes = program_data[
        byte_address:byte_address + 4 # byte address = 0, 4, 8, ...
    ] # separate each instruction -> bytes 0 to 3, 4 to 7 and so on

    instruction_word = int.from_bytes(
        instruction_bytes,
        byteorder="little"
    ) # little endian -> B7 10 00 00 becomes 0x000010B7 because the least significant byte is stored first

    instruction_memory.write(
        byte_address,
        instruction_word
    ) # write each instruction

print("Instruction writing complete", flush=True)
print("\nReading instructions back for verification...", flush=True)

for byte_address in range(0, len(program_data), 4):
    expected_instruction = int.from_bytes(
        program_data[byte_address:byte_address + 4],
        byteorder="little"
    )

    observed_instruction = instruction_memory.read(
        byte_address
    )

    if observed_instruction != expected_instruction:
        raise RuntimeError(
            f"Instruction verification failed at byte address 0x{byte_address:08X}: "
            f"expected 0x{expected_instruction:08X}, "
            f"observed 0x{observed_instruction:08X}"
        )

print("Instruction memory verification passed", flush=True)
print(
    f"Loaded {len(program_data) // 4} instructions",
    flush=True
) # total number of instructions
print("Processor start control is not implemented by this loader yet", flush=True)