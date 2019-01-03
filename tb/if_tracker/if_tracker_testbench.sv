import ryuki_datatypes::trace_output;
`include "../../include/ryuki_defines.sv"

module if_tracker_testbench;
    
    logic clk;
    logic rst;

    // IF Register ports

    logic if_busy;
    logic if_ready;

    // Instruction Memory Ports
    logic                     instr_req;
    logic [`ADDR_WIDTH-1:0]    instr_addr;
    logic                     instr_grant;
    logic                     instr_rvalid;
    logic [`DATA_WIDTH-1:0]    instr_rdata;

    // Tracing Management
    integer counter;

    // Outputs
    logic if_data_ready;
    trace_output if_data_o;
    
    // Instruction Memory
    instruction_memory #(`ADDR_WIDTH, `DATA_WIDTH, `NUM_WORDS) i_mem  (clk, instr_req, instr_addr, 
                           instr_grant, instr_rvalid, instr_rdata);
    
    // Requests to process
    bit [`ADDR_WIDTH-1:0] requests [0:12] = {
        32'h80, 32'h0, 32'h4, 32'h8, 32'hc, 32'h10, 32'h14, 32'h18, 
        32'h1c, 32'h48, 32'h4c, 32'h50, 32'h54
    };
    integer request_pointer;
    
    enum logic {
        REQUEST = 1'b0,
        WAIT_RVALID = 1'b1
    } state, next;
    
    initial                                                                                                                                                                                                             
    begin
        // Set up initial state of signals
        clk = 0;
        rst = 0;
        if_busy = 0;
        if_ready = 1;
        counter = -1;
        request_pointer <= 0;
        state <= REQUEST;
        next <= REQUEST;
        instr_req = 0;
        // Reset all the modules
        #100 rst = 1;
        if_busy = 1;
    end
    
    // Main test state machine
    always@(posedge clk)
    begin
        if (rst == 1)
        begin
            unique case (state)
            REQUEST:
            begin
                if (request_pointer == $size(requests)) $finish;
                else
                begin
                    instr_addr = requests[request_pointer];
                    instr_req = 1'b1;
                    if (instr_grant) 
                    begin
                        next = WAIT_RVALID;
                        instr_req = 1'b0;
                        if (request_pointer + 1 < $size(requests)) instr_addr = requests[request_pointer];
                    end
                end
            end
            WAIT_RVALID:
            begin
                if (instr_rvalid)
                begin
                    instr_req = 1'b1;
                    next = REQUEST;
                    request_pointer++;
                end      
            end
            endcase
            state = next;
        end
    end
    
    // Clock Generator
    
    always 
    begin
        clk = #10 ~clk;
    end

endmodule
