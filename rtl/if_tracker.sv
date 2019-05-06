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
    input logic branch_decision,
    input logic pc_set,
    input logic branch_req,

    // Instruction Memory Ports
    input logic                             instr_req,
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
    enum bit [2:0] {
            TRACK_REQ,
            TRACK_GRANT,
            TRACK_RVALID,
            WAIT_BRANCH
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
            TRACK_REQ:
            begin
                if_data_ready <= 1'b0;
                if_stage_end <= 1'b0;
                if (instr_req) state <= TRACK_GRANT;
            end
            TRACK_GRANT:
            begin
                if_data_ready <= 1'b0;
                if_stage_end <= 1'b0;
                if (instr_gnt) 
                begin
                    cached_addr <= instr_addr;
                    state <= TRACK_RVALID;
                end
            end
            TRACK_RVALID:
            begin
                if (instr_rvalid)  
                begin
                    if (instr_req) state <= TRACK_GRANT;
                    else state <= TRACK_REQ;
                    if (check_jump_branch(instr_rdata)) state <= WAIT_BRANCH;
                    else if (check_load_store(instr_rdata))
                    begin
                        if_data_o.instruction <= instr_rdata;
                        if_data_o.instr_addr <= cached_addr;
                        if_stage_end <= counter;
                        if_data_ready <= 1'b1;
                    end
                end
            end
            WAIT_BRANCH:
            begin
                // Effectively this acts as a timeout state, if you're still waiting on a branch and the next rvalid occurs then you need to take action and stop waiting.
                if (instr_rvalid)
                begin
                    if (check_load_store(instr_rdata) && !((jump_done || branch_decision)))
                    begin
                        if_data_o.instruction <= instr_rdata;
                        if_data_o.instr_addr <= cached_addr;
                        if_stage_end <= counter;
                        if_data_ready <= 1'b1;
                    end
                    if (instr_req) state <= TRACK_GRANT;
                    else state <= TRACK_REQ;
                end
                else if (jump_done || (branch_req && !branch_decision)) 
                begin
                    if (instr_gnt) 
                    begin
                        cached_addr <= instr_addr;
                        state <= TRACK_RVALID;
                    end
                    else if (instr_req) state <= TRACK_GRANT;
                    else state <= TRACK_REQ;
                end
                else if (pc_set) state <= TRACK_REQ;
                else if (instr_gnt) cached_addr <= instr_addr;
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
            state <= TRACK_REQ;
        end
    endtask
    
    function bit check_load_store(input bit[INSTR_DATA_WIDTH-1:0] instruction);
    return instruction ==? 32'h??????83 || instruction ==? 32'h??????03 || 
           instruction ==? 32'h??????23 || instruction ==? 32'h??????a3;
    endfunction
    
    function bit check_jump_branch(input bit[INSTR_DATA_WIDTH-1:0] instruction);
    return  instruction ==? 32'h??????EF || instruction ==? 32'h??????6F ||
            instruction ==? 32'h??????E7 || instruction ==? 32'h??????67 ||
            instruction ==? 32'h??????E3 || instruction ==? 32'h??????63;
    endfunction

endmodule
