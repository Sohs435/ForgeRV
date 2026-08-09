from pathlib import Path # open and read binary python file
from time import sleep # allow the programmable logic clock and reset network to settle
from pynq import Overlay # programs the fpga and reads the hardware handoff file
from pynq import MMIO # Memory Mapped IO

#define bitstream and program file locations
BITSTREAM_PATH = "/home/xilinx/ForgeRV/forgerv.bit"
PROGRAM_PATH = "/home/xilinx/ForgeRV/programs/program.bin"

# addresses assigned in the verified Vivado Address Editor
INSTRUCTION_MEMORY_BASE_ADDRESS = 0x40000000
INSTRUCTION_MEMORY_ADDRESS_RANGE = 0x1000

CORE_CONTROL_STATUS_NAME = "core_control_status"
CORE_CONTROL_STATUS_BASE_ADDRESS = 0x41200000
CORE_CONTROL_STATUS_ADDRESS_RANGE = 0x1000

# AXI GPIO register offsets
GPIO_CHANNEL_1_DATA_OFFSET = 0x00
GPIO_CHANNEL_1_TRI_STATE_OFFSET = 0x04
GPIO_CHANNEL_2_DATA_OFFSET = 0x08
GPIO_CHANNEL_2_TRI_STATE_OFFSET = 0x0C

print("ForgeRV Block RAM Safety Probe", flush=True)
print("--------------------------------", flush=True)

if not Path(BITSTREAM_PATH).is_file():
    raise FileNotFoundError(
        f"FPGA bitstream does not exist: {BITSTREAM_PATH}"
    )

if not Path(PROGRAM_PATH).is_file():
    raise FileNotFoundError(
        f"Program binary does not exist: {PROGRAM_PATH}"
    )

program_data = Path(PROGRAM_PATH).read_bytes() # read the assembled ForgeRV program

if len(program_data) < 4:
    raise RuntimeError(
        "Program binary does not contain a complete first instruction"
    )

first_instruction = int.from_bytes(
    program_data[0:4],
    byteorder="little"
) # convert the first four program bytes into one 32-bit instruction

print(f"Bitstream: {BITSTREAM_PATH}", flush=True)
print(f"Program: {PROGRAM_PATH}", flush=True)
print(f"First instruction: 0x{first_instruction:08X}", flush=True)

print("\nProgramming FPGA...", flush=True)
print("Do not interrupt this operation", flush=True)

overlay = Overlay(
    BITSTREAM_PATH,
    download=True
) # always program the FPGA because its configuration is erased after every restart

print("FPGA programming completed", flush=True)

# allow the 50 MHz programmable logic clock and Processor System Reset block to settle
sleep(0.25)

fpga_manager_state_path = Path(
    "/sys/class/fpga_manager/fpga0/state"
)

if fpga_manager_state_path.is_file():
    fpga_manager_state = fpga_manager_state_path.read_text().strip()

    print(
        f"FPGA manager state: {fpga_manager_state}",
        flush=True
    )

    if fpga_manager_state != "operating":
        raise RuntimeError(
            f"FPGA manager is not operating: {fpga_manager_state}"
        )
else:
    print(
        "FPGA manager state file is unavailable, continuing with hardware handoff checks",
        flush=True
    )

print("\nChecking AXI GPIO hardware information...", flush=True)

if CORE_CONTROL_STATUS_NAME not in overlay.ip_dict:
    raise RuntimeError(
        f"Could not find {CORE_CONTROL_STATUS_NAME} in the hardware handoff file. "
        f"Available hardware: {list(overlay.ip_dict.keys())}"
    )

core_control_information = overlay.ip_dict[
    CORE_CONTROL_STATUS_NAME
]

observed_control_base_address = core_control_information[
    "phys_addr"
]

observed_control_address_range = core_control_information[
    "addr_range"
]

print(
    f"AXI GPIO base address: 0x{observed_control_base_address:08X}",
    flush=True
)
print(
    f"AXI GPIO address range: 0x{observed_control_address_range:X}",
    flush=True
)

if observed_control_base_address != CORE_CONTROL_STATUS_BASE_ADDRESS:
    raise RuntimeError(
        f"AXI GPIO base-address mismatch: expected "
        f"0x{CORE_CONTROL_STATUS_BASE_ADDRESS:08X}, observed "
        f"0x{observed_control_base_address:08X}"
    )

if observed_control_address_range < CORE_CONTROL_STATUS_ADDRESS_RANGE:
    raise RuntimeError(
        "AXI GPIO address range is smaller than the Vivado configuration"
    )

print("AXI GPIO hardware information passed", flush=True)

core_control_status = MMIO(
    observed_control_base_address,
    observed_control_address_range
) # access the AXI GPIO through the address parsed from the hardware handoff file

print("\nHolding ForgeRV in reset...", flush=True)

core_control_status.write(
    GPIO_CHANNEL_1_TRI_STATE_OFFSET,
    0x00000000
) # configure all five channel 1 control bits as outputs

core_control_status.write(
    GPIO_CHANNEL_2_TRI_STATE_OFFSET,
    0xFFFFFFFF
) # configure all thirty-two channel 2 status bits as inputs

core_control_status.write(
    GPIO_CHANNEL_1_DATA_OFFSET,
    0x00000000
) # bit 0 = 0 asserts software reset and bit 1 = 0 disables the processor

control_readback = core_control_status.read(
    GPIO_CHANNEL_1_DATA_OFFSET
)

print(
    f"AXI GPIO control readback: 0x{control_readback:08X}",
    flush=True
)

if control_readback != 0x00000000:
    raise RuntimeError(
        f"Could not hold ForgeRV in reset: control readback was "
        f"0x{control_readback:08X}"
    )

print("ForgeRV is disabled and held in reset", flush=True)

print("\nCreating instruction-memory MMIO mapping...", flush=True)

instruction_memory = MMIO(
    INSTRUCTION_MEMORY_BASE_ADDRESS,
    INSTRUCTION_MEMORY_ADDRESS_RANGE
) # access the instruction Block RAM through the AXI Block RAM Controller

print(
    f"Instruction memory base address: 0x{INSTRUCTION_MEMORY_BASE_ADDRESS:08X}",
    flush=True
)

print("\nWriting only the first instruction word...", flush=True)

instruction_memory.write(
    0x00000000,
    first_instruction
) # write only BRAM word zero during the safety test

print("First instruction write completed", flush=True)

# ensure the AXI write has completed before performing the readback
sleep(0.01)

print("Reading only the first instruction word...", flush=True)

observed_instruction = instruction_memory.read(
    0x00000000
)

print(
    f"Expected instruction: 0x{first_instruction:08X}",
    flush=True
)
print(
    f"Observed instruction: 0x{observed_instruction:08X}",
    flush=True
)

if observed_instruction != first_instruction:
    raise RuntimeError(
        f"Block RAM safety probe failed: expected "
        f"0x{first_instruction:08X}, observed "
        f"0x{observed_instruction:08X}"
    )

print("\nBlock RAM safety probe passed", flush=True)
print("AXI GPIO access passed", flush=True)
print("Single-word instruction memory write passed", flush=True)
print("Single-word instruction memory read passed", flush=True)
print("ForgeRV remains disabled and held in reset", flush=True)
print("The full program has not been loaded", flush=True)