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
    
    logic [7:0] selected_byte;
    logic [15:0] selected_half;
    
    assign memory_address = {address[31:2], 2'b00}; 
    
    always_comb begin 
        memory_access_misaligned = 1'b0; 
        memory_write_data = store_data;
        memory_write_strobe = 4'b0000;
        selected_byte = 8'b0;
        selected_half = 16'b0;
        
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
            MEMORY_BYTE: begin 
                case(address[1:0])
                    2'b00: memory_write_strobe = 4'b0001;
                    2'b01: memory_write_strobe = 4'b0010;
                    2'b10: memory_write_strobe = 4'b0100;
                    2'b11: memory_write_strobe = 4'b1000;
                    default: memory_write_strobe = 4'b0000;
                endcase
            end 
            
            MEMORY_HALF: begin 
                case(address[1:0])
                    2'b00: memory_write_strobe = 4'b0011;
                    2'b10: memory_write_strobe = 4'b1100;
                    default: memory_write_strobe = 4'b0000;
                endcase
            end 
            
            MEMORY_WORD: begin 
                if (address[1:0] == 2'b00) memory_write_strobe = 4'b1111;
                else memory_write_strobe = 4'b0000;
            end 
            
            default: memory_write_strobe = 4'b0000; 
        endcase 
        
        if (!memory_write_enable || memory_access_misaligned)
            memory_write_strobe = 4'b0000; 
        
        memory_read_request = memory_read_enable && (memory_size != MEMORY_NONE) && !memory_access_misaligned;
        memory_write_request = memory_write_enable && (memory_size != MEMORY_NONE) && !memory_access_misaligned; 
        
        case(address[1:0])
            2'b00: selected_byte = memory_read_data[7:0];
            2'b01: selected_byte = memory_read_data[15:8];
            2'b10: selected_byte = memory_read_data[23:16];
            2'b11: selected_byte = memory_read_data[31:24];
            default: selected_byte = 8'b0;
        endcase
        
        if (address[1]) selected_half = memory_read_data[31:16];
        else selected_half = memory_read_data[15:0];
        
        load_data = 32'b0;
        
        if (memory_read_request) begin 
            case(memory_size)
                MEMORY_BYTE: begin
                    if (load_unsigned) load_data = {24'b0, selected_byte};
                    else load_data = {{24{selected_byte[7]}}, selected_byte};
                end 
                
                MEMORY_HALF: begin
                    if (load_unsigned) load_data = {16'b0, selected_half};
                    else load_data = {{16{selected_half[15]}}, selected_half};
                end 
                
                MEMORY_WORD: load_data = memory_read_data; 
                default: load_data = 32'b0;
            endcase 
        end 
    end 
    
endmodule