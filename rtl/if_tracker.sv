module if_tracker
#(
    parameter INSTR_ADDR_WIDTH = 16,
    parameter INSTR_DATA_WIDTH = 32,
    parameter type trace_format = int
)
(
    input logic clk,
    input logic rst_n,
    input integer counter,
    
    // Processor signals for tracing
    input logic jump_done,

    // Instruction Memory Ports
    input logic                             instr_rvalid,
    input logic [INSTR_DATA_WIDTH-1:0]      instr_rdata,
    input logic                             instr_gnt,
    input logic [INSTR_ADDR_WIDTH-1:0]      instr_addr,

    // Outputs
    output logic if_data_ready,
    output integer if_stage_end,
    (* dont_touch = "yes" *) trace_format if_data_o
);

    // State Machine to Control Unit
    enum bit {
            IF_START =          1'b0,
            CHECK_JUMP_DONE =   1'b1
         } state;

    bit jump_done_buffer = 0;
    bit [INSTR_DATA_WIDTH-1:0] cached_instruction = 0;
    bit [INSTR_ADDR_WIDTH-1:0] cached_addr = 0;

    // Initial behaviour

    initial
    begin
        initialise_device();
    end

    // Data Acquistion

    always_ff @(posedge clk)
    begin
        if (!rst_n) initialise_device();
        unique case(state)
            IF_START:
            begin
                if (if_data_ready) 
                begin
                    if_data_ready <= 1'b0;
                    if_stage_end <= 1'b0;
                end
                if (instr_gnt) cached_addr <= instr_addr;
                // If you detected a load or store that is just reaching the end of its fetch cycle
                // then store it 
                if (instr_rvalid && check_load_store(instr_rdata)) 
                begin
                    if_data_o.instruction <= instr_rdata;
                    if_data_o.instr_addr <= cached_addr;
                    if_stage_end <= counter;
                    if_data_ready <= 1'b1;
                end
            end
        endcase
        
        // If it isn't then don't do anything, if it is then send the data out to the next process.
    end

    // Initialise the whole trace unit

    task initialise_device();
        begin
            if_data_ready <= 0;
            if_data_o <= '{default:0};
            if_stage_end <= 0;
            state <= IF_START;
        end
    endtask
    
    function bit check_load_store(input bit[INSTR_DATA_WIDTH-1:0] instruction);
    return instruction ==? 32'h??????83 || instruction ==? 32'h??????03 || 
           instruction ==? 32'h??????23 || instruction ==? 32'h??????a3;
    endfunction
    

endmodule
