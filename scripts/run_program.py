import time
from pynq import MMIO # Memory Mapped Input Output

# this script does not program the FPGA or rewrite instruction memory
# run load_program.py successfully before running this file

AXI_GPIO_BASE_ADDRESS = 0x41200000
AXI_GPIO_ADDRESS_RANGE = 0x1000

# standard AXI GPIO register offsets
GPIO_CHANNEL_1_DATA = 0x00
GPIO_CHANNEL_1_DIRECTION = 0x04
GPIO_CHANNEL_2_DATA = 0x08
GPIO_CHANNEL_2_DIRECTION = 0x0C

# GPIO channel 1 control-bit assignments
RESET_RELEASE_BIT = 0
CORE_ENABLE_BIT = 1
STATUS_SELECT_SHIFT = 2

# status words selected through channel 1 bits [4:2]
STATUS_PROGRAM = 0
STATUS_FAILURE_CODE = 1
STATUS_OBSERVED_VALUE = 2
STATUS_EXPECTED_VALUE = 3
STATUS_COMPLETION_AND_FAULT = 4
STATUS_PROGRAM_COUNTER = 5
STATUS_WRITEBACK_DATA = 6
STATUS_PIPELINE_ACTIVITY = 7

PROGRAM_COMPLETE_MASK = 1 << 0
CORE_FAULT_MASK = 1 << 1

PROGRAM_PASS_VALUE = 0x00000001
PROGRAM_FAIL_VALUE = 0xFFFFFFFF

EXECUTION_TIMEOUT_SECONDS = 2.0
STATUS_SETTLE_SECONDS = 0.001
DIAGNOSTIC_COMPLETION_SECONDS = 0.001
POLL_INTERVAL_SECONDS = 0.001


def create_control_value(
    status_select,
    reset_released,
    core_enabled
):
    control_value = (status_select & 0x7) << STATUS_SELECT_SHIFT

    if reset_released:
        control_value |= 1 << RESET_RELEASE_BIT

    if core_enabled:
        control_value |= 1 << CORE_ENABLE_BIT

    return control_value


def write_control(
    gpio,
    status_select,
    reset_released,
    core_enabled
):
    gpio.write(
        GPIO_CHANNEL_1_DATA,
        create_control_value(
            status_select,
            reset_released,
            core_enabled
        )
    )


def read_status(
    gpio,
    status_select,
    reset_released,
    core_enabled
):
    write_control(
        gpio,
        status_select,
        reset_released,
        core_enabled
    )

    time.sleep(STATUS_SETTLE_SECONDS) # allow the status-select multiplexer and AXI GPIO input to settle

    return gpio.read(GPIO_CHANNEL_2_DATA)


print("ForgeRV Assembly Program Execution Test", flush=True)
print("----------------------------------------", flush=True)
print("This test assumes that load_program.py has already passed", flush=True)

fpga_manager_state_path = "/sys/class/fpga_manager/fpga0/state"

with open(fpga_manager_state_path, "r", encoding="ascii") as state_file:
    fpga_manager_state = state_file.read().strip()

print(f"FPGA manager state: {fpga_manager_state}", flush=True)

if fpga_manager_state != "operating":
    raise RuntimeError(
        f"FPGA manager is not operating: {fpga_manager_state}"
    )

print("Creating AXI GPIO MMIO mapping...", flush=True)

gpio = MMIO(
    AXI_GPIO_BASE_ADDRESS,
    AXI_GPIO_ADDRESS_RANGE
)

print("AXI GPIO MMIO mapping created", flush=True)

# channel 1 drives reset release, core enable and status select
gpio.write(GPIO_CHANNEL_1_DIRECTION, 0x00000000)

# channel 2 receives the selected 32-bit processor status word
gpio.write(GPIO_CHANNEL_2_DIRECTION, 0xFFFFFFFF)

program_status = 0
failure_code = 0
observed_value = 0
expected_value = 0
completion_and_fault = 0
program_counter = 0
writeback_data = 0
pipeline_activity = 0
fault_detected = False
fault_status_snapshot = 0
fault_program_counter = 0
fault_writeback_data = 0
fault_pipeline_activity = 0

try:
    print("Holding ForgeRV in reset with the core disabled...", flush=True)

    write_control(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=False,
        core_enabled=False
    )

    time.sleep(STATUS_SETTLE_SECONDS)

    reset_status = gpio.read(GPIO_CHANNEL_2_DATA)

    if reset_status != 0:
        raise RuntimeError(
            f"Expected cleared completion and fault status during reset, "
            f"observed 0x{reset_status:08X}"
        )

    print("PASS: processor status is clear during reset", flush=True)
    print("Releasing processor reset while keeping the core disabled...", flush=True)

    write_control(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=True,
        core_enabled=False
    )

    time.sleep(STATUS_SETTLE_SECONDS)

    print("Starting ForgeRV...", flush=True)

    write_control(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=True,
        core_enabled=True
    )

    start_time = time.monotonic()

    while True:
        completion_and_fault = gpio.read(GPIO_CHANNEL_2_DATA)

        program_complete = (
            completion_and_fault & PROGRAM_COMPLETE_MASK
        ) != 0

        core_fault = (
            completion_and_fault & CORE_FAULT_MASK
        ) != 0

        if core_fault:
            fault_detected = True
            fault_status_snapshot = completion_and_fault

            # capture the visible processor state before disabling or resetting the core
            fault_program_counter = read_status(
                gpio,
                STATUS_PROGRAM_COUNTER,
                reset_released=True,
                core_enabled=True
            )

            fault_writeback_data = read_status(
                gpio,
                STATUS_WRITEBACK_DATA,
                reset_released=True,
                core_enabled=True
            )

            fault_pipeline_activity = read_status(
                gpio,
                STATUS_PIPELINE_ACTIVITY,
                reset_released=True,
                core_enabled=True
            )

            break

        if program_complete:
            break

        if time.monotonic() - start_time > EXECUTION_TIMEOUT_SECONDS:
            program_counter = read_status(
                gpio,
                STATUS_PROGRAM_COUNTER,
                reset_released=True,
                core_enabled=True
            )

            raise RuntimeError(
                f"Processor execution timed out after "
                f"{EXECUTION_TIMEOUT_SECONDS:.3f} seconds; "
                f"Program Counter = 0x{program_counter:08X}"
            )

        time.sleep(POLL_INTERVAL_SECONDS)

    elapsed_time = time.monotonic() - start_time

    if fault_detected:
        print(
            f"Core fault detected after {elapsed_time:.6f} seconds",
            flush=True
        )
    else:
        print(
            f"Program completion detected after {elapsed_time:.6f} seconds",
            flush=True
        )

        # the failure path writes three more diagnostic words after program_status
        # keep the core running briefly so failure_code, observed_value and expected_value can commit
        time.sleep(DIAGNOSTIC_COMPLETION_SECONDS)

    print("Disabling the core while leaving reset released...", flush=True)

    write_control(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=True,
        core_enabled=False
    )

    time.sleep(STATUS_SETTLE_SECONDS)

    program_status = read_status(
        gpio,
        STATUS_PROGRAM,
        reset_released=True,
        core_enabled=False
    )

    failure_code = read_status(
        gpio,
        STATUS_FAILURE_CODE,
        reset_released=True,
        core_enabled=False
    )

    observed_value = read_status(
        gpio,
        STATUS_OBSERVED_VALUE,
        reset_released=True,
        core_enabled=False
    )

    expected_value = read_status(
        gpio,
        STATUS_EXPECTED_VALUE,
        reset_released=True,
        core_enabled=False
    )

    completion_and_fault = read_status(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=True,
        core_enabled=False
    )

    program_counter = read_status(
        gpio,
        STATUS_PROGRAM_COUNTER,
        reset_released=True,
        core_enabled=False
    )

    writeback_data = read_status(
        gpio,
        STATUS_WRITEBACK_DATA,
        reset_released=True,
        core_enabled=False
    )

    pipeline_activity = read_status(
        gpio,
        STATUS_PIPELINE_ACTIVITY,
        reset_released=True,
        core_enabled=False
    )

    program_complete = (
        completion_and_fault & PROGRAM_COMPLETE_MASK
    ) != 0

    current_core_fault = (
        completion_and_fault & CORE_FAULT_MASK
    ) != 0

    core_fault = fault_detected or current_core_fault

    print("", flush=True)
    print("ForgeRV execution results", flush=True)
    print("-------------------------", flush=True)
    print(f"Program complete: {int(program_complete)}", flush=True)
    print(f"Core fault: {int(core_fault)}", flush=True)
    print(f"Program status: 0x{program_status:08X}", flush=True)
    print(f"Failure code: 0x{failure_code:08X}", flush=True)
    print(f"Observed value: 0x{observed_value:08X}", flush=True)
    print(f"Expected value: 0x{expected_value:08X}", flush=True)
    print(f"Program Counter: 0x{program_counter:08X}", flush=True)
    print(f"Writeback data: 0x{writeback_data:08X}", flush=True)
    print(f"Pipeline activity: 0x{pipeline_activity:08X}", flush=True)

    if fault_detected:
        print("", flush=True)
        print("State captured at the fault", flush=True)
        print("---------------------------", flush=True)
        print(f"Fault status: 0x{fault_status_snapshot:08X}", flush=True)
        print(f"Fault Program Counter: 0x{fault_program_counter:08X}", flush=True)
        print(f"Fault writeback data: 0x{fault_writeback_data:08X}", flush=True)
        print(f"Fault pipeline activity: 0x{fault_pipeline_activity:08X}", flush=True)

    if core_fault:
        raise RuntimeError(
            f"ForgeRV asserted core_fault at Program Counter "
            f"0x{fault_program_counter:08X}; "
            f"writeback data 0x{fault_writeback_data:08X}; "
            f"pipeline activity 0x{fault_pipeline_activity:08X}"
        )

    if not program_complete:
        raise RuntimeError("Program completion was not retained")

    if program_status == PROGRAM_FAIL_VALUE:
        raise RuntimeError(
            f"Assembly self-test failed at CHECK {failure_code}: "
            f"observed 0x{observed_value:08X}, "
            f"expected 0x{expected_value:08X}"
        )

    if program_status != PROGRAM_PASS_VALUE:
        raise RuntimeError(
            f"Unexpected program status 0x{program_status:08X}"
        )

    if failure_code != 0:
        raise RuntimeError(
            f"Program reported pass status with nonzero failure code "
            f"0x{failure_code:08X}"
        )

    print("", flush=True)
    print("PASS: all ForgeRV assembly self-tests passed", flush=True)

finally:
    # stop execution before asserting reset so the processor is always left in a known safe state
    write_control(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=True,
        core_enabled=False
    )

    time.sleep(STATUS_SETTLE_SECONDS)

    write_control(
        gpio,
        STATUS_COMPLETION_AND_FAULT,
        reset_released=False,
        core_enabled=False
    )

    print("Processor returned to reset and disabled", flush=True)