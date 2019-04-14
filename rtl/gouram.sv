import gouram_datatypes::*;

module gouram
#(
    parameter INSTR_DATA_WIDTH = 32,
    parameter INSTR_ADDR_WIDTH = 16,
    parameter DATA_ADDR_WIDTH = 32,
    parameter TRACE_BUFFER_SIZE = 8,
    parameter SIGNALS_TO_BUFFER = 64
)
(   
    input logic clk,
    input logic rst_n,
    
    // Processor Signals for Tracing
    input logic jump_done,
    input logic branch_decision,
    input logic is_decoding,
    input logic pc_set,
    input logic branch_req,

    // Instruction Memory Ports
    input logic                             instr_req,
    input logic                             instr_rvalid,
    input logic [INSTR_DATA_WIDTH-1:0]      instr_rdata,
    input logic [INSTR_ADDR_WIDTH-1:0]      instr_addr,
    input logic                             instr_gnt,

    // Data Memory Ports
    input logic                         data_mem_req,
    input logic [DATA_ADDR_WIDTH-1:0]   data_mem_addr,
    input logic                         data_mem_rvalid,

    // Trace output port
    output trace_format trace_data_o,
    output bit trace_capture_enable,
    output bit lock,
    output integer signed counter_o
);

    // Monotonic Counter to Track Timing for Each Component
    (* dont_touch = "yes" *) integer signed counter;
    assign counter_o = counter;

    logic if_data_ready;
    logic filtered_data_ready;
    trace_format if_data_o;
    trace_format filtered_data;
    integer if_stage_end_vf;
    integer if_stage_end_trans;
    bit repeat_detected;
    
    if_tracker #(INSTR_ADDR_WIDTH, INSTR_DATA_WIDTH, trace_format) if_tr (
        .if_stage_end(if_stage_end_vf), .*
    );
    validity_filter #(TRACE_BUFFER_SIZE, trace_format, SIGNALS_TO_BUFFER, INSTR_DATA_WIDTH) v_f (
        .if_data_i(if_data_o), .if_stage_end_i(if_stage_end_vf), .if_stage_end_o(if_stage_end_trans), 
        .*
    );
    ex_tracker #(DATA_ADDR_WIDTH, SIGNALS_TO_BUFFER, TRACE_BUFFER_SIZE, trace_format) ex_tr (
        .clk(clk),
        .rst_n(rst_n),
        .counter(counter),
        .filtered_data_ready(filtered_data_ready),
        .if_stage_end(if_stage_end_trans),
        .filtered_data_i(filtered_data),
        .data_mem_req(data_mem_req),
        .data_mem_addr(data_mem_addr),
        .data_mem_rvalid(data_mem_rvalid),
        .ex_data_o(trace_data_o),
        .*
    );
    
    initial
    begin
        initialise_device();
    end

    // Monotonic Counter (Counts clock cycles)

    always_ff @(posedge clk)
    begin
        if (!rst_n) initialise_device();
        else 
        begin   
            counter <= counter + 1;
            if (repeat_detected) 
            begin
                assign trace_capture_enable = 1'b0;
                lock <= 1'b1;
            end
            else assign trace_capture_enable = 1'b1;
        end
    end
    
    initial
    begin
        initialise_device();
    end
    
    // Initialise the whole trace unit

    task initialise_device();
        begin
            counter <= -1;
            lock <= 0;
            trace_capture_enable <= 1;
        end
    endtask


endmodule
