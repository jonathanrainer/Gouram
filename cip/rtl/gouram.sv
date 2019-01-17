import gouram_datatypes::*;

module gouram
#(
    parameter INSTR_DATA_WIDTH = 32,
    parameter DATA_ADDR_WIDTH = 32,
    parameter TRACE_BUFFER_SIZE = 8
)
(   
    input logic clk,
    input logic rst_n,
    
    // Processor Signsls for Tracing
    input logic jump_done,

    // Instruction Memory Ports
    input logic                             instr_rvalid,
    input logic [INSTR_DATA_WIDTH-1:0]      instr_rdata,

    // Data Memory Ports
    input logic                         data_mem_req,
    input logic [DATA_ADDR_WIDTH-1:0]   data_mem_addr,
    input logic                         data_mem_grant,
    input logic                         data_mem_rvalid,

    // Trace output port
    output trace_format trace_data_o
);

    // Monotonic Counter to Track Timing for Each Component
    integer counter;

    logic if_data_ready;
    trace_format if_data_o;
    
    if_tracker #(INSTR_DATA_WIDTH, trace_format) if_tr (.*);
    ex_tracker #(DATA_ADDR_WIDTH, 64, TRACE_BUFFER_SIZE, trace_format) ex_tr(.if_data_i(if_data_o), 
                    .ex_data_o(trace_data_o), .*);
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

    // Monotonic Counter (Counts clock cycles)

    always @(posedge clk)
    begin
        counter <= counter + 1;
    end
    
    // Initialise the whole trace unit

    task initialise_device();
        begin
            counter <= -1;
        end
    endtask


endmodule
