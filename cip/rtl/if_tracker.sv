module if_tracker
#(
    parameter DATA_WIDTH = 32,
    parameter type trace_format = int
)
(
    input logic clk,
    input logic rst_n,
    
    // Processor signals for tracing
    input logic jump_done,

    // Instruction Memory Ports
    input logic                     instr_rvalid,
    input logic [DATA_WIDTH-1:0]    instr_rdata,

    // Outputs
    output logic if_data_ready,
    trace_format if_data_o
);

    // State Machine to Control Unit
    enum bit {
            IF_START =          1'b0,
            CHECK_JUMP_DONE =   1'b1
         } state;

    bit jump_done_buffer = 0;
    bit [DATA_WIDTH-1:0] cached_instruction = 0;

    // Initial behaviour

    initial
    begin
        initialise_device();
    end

    // Reset Behaviour

    always @(posedge rst_n)
    begin
        if (rst_n == 1)
        begin
            initialise_device();
        end
    end

    // Data Acquistion

    always_ff @(posedge clk)
    begin
        unique case(state)
            IF_START:
            begin
                if (if_data_ready) if_data_ready <= 0;
                // If you detected a load or store that is just reaching the end of its fetch cycle
                // then store it 
                if (instr_rvalid && check_load_store(instr_rdata)) 
                begin
                    if_data_o.instruction <= instr_rdata;
                    jump_done_buffer <= jump_done;
                    state <= CHECK_JUMP_DONE;
                end
            end
            CHECK_JUMP_DONE:
            begin
                // If at any point, jump done is detected before the next rvalid signal then 
                // this fetch is invalid so should be ignored.
                if (cached_instruction != 0)
                begin
                    if_data_o.instruction <= cached_instruction;
                    cached_instruction <= 32'h0;
                end
                if (if_data_ready) if_data_ready <= 0;
                if(jump_done_buffer || jump_done) 
                begin
                    if_data_o <= '{default:0};
                    jump_done_buffer <= 1'b0;
                    state <= IF_START;
                end
                else if (instr_rvalid)
                begin
                    if (check_load_store(instr_rdata))
                    begin
                        cached_instruction <= instr_rdata;
                        state <= CHECK_JUMP_DONE;
                    end
                    else 
                    begin
                        jump_done_buffer <= 1'b0;
                        state <= IF_START;
                    end
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
            state <= IF_START;
        end
    endtask
    
    function bit check_load_store(input bit[DATA_WIDTH-1:0] instruction);
        return instruction ==? 32'h??????83 || instruction ==? 32'h??????03 || 
               instruction ==? 32'h??????23 || instruction ==? 32'h??????a3;
    endfunction

endmodule
