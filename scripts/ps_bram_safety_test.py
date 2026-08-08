from pathlib import Path # read FPGA manager state
from pynq import MMIO # Memory Mapped Input/Output access

GPIO_BASE_ADDRESS = 0x41200000
GPIO_ADDRESS_RANGE = 0x1000

INSTRUCTION_MEMORY_BASE_ADDRESS = 0x40000000
INSTRUCTION_MEMORY_ADDRESS_RANGE = 0x1000

GPIO_CHANNEL_1_DATA_OFFSET = 0x00
GPIO_CHANNEL_1_DIRECTION_OFFSET = 0x04
GPIO_CHANNEL_2_DIRECTION_OFFSET = 0x0C

FPGA_MANAGER_STATE_PATH = Path(
    "/sys/class/fpga_manager/fpga0/state"
)

# These offsets reveal adjacent-address, 256-byte and 1,024-byte aliasing.
TEST_LOCATIONS = [
    (0x000, 0xA5000000),
    (0x004, 0xA5000001),
    (0x008, 0xA5000002),
    (0x00C, 0xA5000003),

    (0x07C, 0xA500001F),
    (0x0FC, 0xA500003F),

    (0x100, 0xA5000040),
    (0x17C, 0xA500005F),
    (0x1FC, 0xA500007F),

    (0x200, 0xA5000080),
    (0x27C, 0xA500009F),
    (0x2FC, 0xA50000BF),

    (0x300, 0xA50000C0),
    (0x37C, 0xA50000DF),
    (0x3FC, 0xA50000FF)
]

print("ForgeRV Block RAM Address Independence Test")
print("--------------------------------------------")

fpga_manager_state = FPGA_MANAGER_STATE_PATH.read_text().strip()

print(f"FPGA manager state: {fpga_manager_state}")

if fpga_manager_state != "operating":
    raise RuntimeError(
        f"FPGA manager is not operating: {fpga_manager_state}"
    )

print("Creating AXI GPIO MMIO mapping...")

gpio = MMIO(
    GPIO_BASE_ADDRESS,
    GPIO_ADDRESS_RANGE
)

gpio.write(
    GPIO_CHANNEL_1_DATA_OFFSET,
    0x00000000
)

gpio.write(
    GPIO_CHANNEL_1_DIRECTION_OFFSET,
    0x00000000
)

gpio.write(
    GPIO_CHANNEL_2_DIRECTION_OFFSET,
    0xFFFFFFFF
)

control_value = gpio.read(
    GPIO_CHANNEL_1_DATA_OFFSET
)

print(f"Processor control value: 0x{control_value:08X}")

if control_value != 0:
    raise RuntimeError(
        "Processor is not held in reset and disabled"
    )

print("PASS: processor is held in reset and disabled")
print("Creating instruction Block RAM MMIO mapping...")

instruction_memory = MMIO(
    INSTRUCTION_MEMORY_BASE_ADDRESS,
    INSTRUCTION_MEMORY_ADDRESS_RANGE
)

print("Instruction Block RAM MMIO mapping created")
print("Saving original values...")

original_values = {}

for byte_offset, test_value in TEST_LOCATIONS:
    original_values[byte_offset] = instruction_memory.read(
        byte_offset
    )

print("Writing every diagnostic value before reading any value...")

for byte_offset, test_value in TEST_LOCATIONS:
    absolute_address = (
        INSTRUCTION_MEMORY_BASE_ADDRESS + byte_offset
    )

    instruction_memory.write(
        byte_offset,
        test_value
    )

    print(
        f"Wrote 0x{test_value:08X} to "
        f"0x{absolute_address:08X}"
    )

print("All diagnostic writes completed")
print("Reading every diagnostic address...")

failure_count = 0

try:
    for byte_offset, expected_value in TEST_LOCATIONS:
        absolute_address = (
            INSTRUCTION_MEMORY_BASE_ADDRESS + byte_offset
        )

        observed_value = instruction_memory.read(
            byte_offset
        )

        if observed_value == expected_value:
            print(
                f"PASS: 0x{absolute_address:08X} = "
                f"0x{observed_value:08X}"
            )
        else:
            failure_count += 1

            print(
                f"FAIL: 0x{absolute_address:08X}: "
                f"expected 0x{expected_value:08X}, "
                f"observed 0x{observed_value:08X}"
            )

finally:
    print("Restoring original values...")

    for byte_offset, original_value in original_values.items():
        instruction_memory.write(
            byte_offset,
            original_value
        )

    print("Original values restored")

if failure_count != 0:
    raise RuntimeError(
        f"Block RAM address independence test found "
        f"{failure_count} aliased addresses"
    )

print("PASS: all selected Block RAM addresses remain independent")
print("PASS: no address aliasing was detected")
print("Block RAM address independence test completed")