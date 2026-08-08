create_clock -name core_clk -period 20.000 [get_ports clk]

set_input_delay -clock core_clk -min 0.000 \
    [get_ports {resetn core_enable instruction[*]}]

set_input_delay -clock core_clk -max 0.000 \
    [get_ports {resetn core_enable instruction[*]}]

set_false_path -to \
    [get_ports {debug_data[*] debug_status[*]}]