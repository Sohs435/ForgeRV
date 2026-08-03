module rv32_load_store_unit (
    input logic [31:0] address,
    input logic [31:0] store_data,
    input logic memory_read_enable, 
    input logic memory_write_enable,
    input rv32_pkg::memory_size_t memory_size,
    input logic load_unsigned,
    input logic [31:0] memory_read_data,
    
    output logic [31:0] memory_address,
    output logic [31:0] memory_write_data,
    output logic [3:0] memory_write_strobe,
    output logic memory_read_request,
    output logic memory_write_request,
    output logic [31:0] load_data,
    output logic memory_access_misaligned  
    );
    
    import rv32_pkg::*; 
    logic [31:0] shifted_read_data; 
    assign memory_address = {address[31:2], 2'b00}; 
    
    always_comb begin 
        memory_access_misaligned = 1'b0; 
        memory_write_data = store_data;
        memory_write_strobe = 4'b1111;
        
        if (memory_read_enable || memory_write_enable) begin 
            case (memory_size)
                MEMORY_BYTE: memory_access_misaligned = 1'b0;
                MEMORY_HALF: memory_access_misaligned = address[0]; 
                MEMORY_WORD: memory_access_misaligned = (address[1:0] != 2'b00); 
                default: memory_access_misaligned = 1'b0; 
            endcase
        end 
        
        case(memory_size) 
            MEMORY_BYTE: memory_write_data = {4{store_data[7:0]}};
            MEMORY_HALF: memory_write_data = {2{store_data[15:0]}};
            MEMORY_WORD: memory_write_data = store_data; 
            default: memory_write_data = 32'b0;
        endcase
        
        case(memory_size) 
            MEMORY_BYTE: memory_write_strobe = 4'b0001 << address[1:0]; //can be anything 
            MEMORY_HALF: memory_write_strobe = 4'b0011 << address[1:0]; // can be only 00 -> 0000xxxx or 10 -> xxxx00000
            MEMORY_WORD: memory_write_strobe = 4'b1111; // can only be 00 -> xxxxxxxx
            default: memory_write_strobe = 4'b0000; 
        endcase 
        
        if (!memory_write_enable || memory_access_misaligned) //disable strobe if write function is disabled or the 
        // memory access is misaligned or the strobe value is bogus 
            memory_write_strobe = 4'b0000; 
        
        memory_read_request = memory_read_enable && (memory_size != MEMORY_NONE) && !memory_access_misaligned;
        memory_write_request = memory_write_enable && (memory_size != MEMORY_NONE) && !memory_access_misaligned; 
        
        load_data = 32'b0;
        shifted_read_data = memory_read_data >> {address[1:0], 3'b000}; // 0 -> 00000
        // 8-> 010000, 16 -> 10000, 24 -> 11000
        
        if (memory_read_request) begin 
            case(memory_size)
                MEMORY_BYTE: begin
                    if (load_unsigned) load_data = {24'b0, shifted_read_data[7:0]};
                    else load_data = {{24{shifted_read_data[7]}}, shifted_read_data[7:0]};
                end 
                MEMORY_HALF: begin
                    if (load_unsigned) load_data = {16'b0, shifted_read_data[15:0]};
                    else load_data = {{16{shifted_read_data[15]}}, shifted_read_data[15:0]};
                end 
                MEMORY_WORD: load_data = shifted_read_data; 
                default: load_data = 32'b0;
            endcase 
        end 

        
    end 
endmodule 