import gouram_datatypes::*;

module gouram
(   
    input logic clk,
    input logic rst,

    // IF Register ports

    input logic if_busy,
    input logic if_ready,
    input logic branch_decision,

    // Instruction Memory Ports
    input logic                     instr_req,
    input logic [INSTR_ADDR_WIDTH-1:0]    instr_addr,
    input logic                     instr_grant,
    input logic                     instr_rvalid,
    input logic [INSTR_DATA_WIDTH-1:0]    instr_rdata,

    // ID Register Ports

    input logic id_ready,
    input logic jump_done,
    input logic is_decoding,
    input logic illegal_instruction,
    input logic branch_req,

    // EX Register Ports

    input logic ex_ready,
    input logic data_mem_req,
    input logic data_mem_grant,
    input logic data_mem_rvalid,
    
    // Data Memory Ports
   
    input logic [DATA_ADDR_WIDTH-1:0] data_mem_addr,

    // WB Register ports

    input logic wb_ready,
    
    // Trace output port
    output trace_format trace_data_o
);

    // Monotonic Counter to Track Timing for Each Component
    integer counter;

    logic if_data_valid;
    trace_format if_data_o;
    logic id_data_ready;
    trace_format id_data_o;
    logic ex_data_ready;
    trace_format ex_data_o;
    logic wb_data_ready;

    integer previous_end_o;
    
    if_tracker #(INSTR_ADDR_WIDTH, INSTR_DATA_WIDTH, trace_format) if_tr (.*);
    id_tracker #(INSTR_DATA_WIDTH, DATA_ADDR_WIDTH, TRACE_BUFFER_SIZE, trace_format) id_tr(.if_data_i(if_data_o), .*);
    ex_tracker #(DATA_ADDR_WIDTH, 256, TRACE_BUFFER_SIZE, trace_format) ex_tr(.id_data_i(id_data_o), .wb_previous_end_i(previous_end_o), .*);
    wb_tracker #(TRACE_BUFFER_SIZE, trace_format) wb_tr(.ex_data_i(ex_data_o), .wb_data_o(trace_data_o), .*);
    initial
    begin
        initialise_device();
    end

    // Reset Behaviour

    always @(posedge rst)
    begin
        if (rst == 1)
        begin
            initialise_device();
        end
    end

    // Monotonic Counter (Counts clock cycles)

    always @(posedge clk)
    begin
//        if (counter == 32'h4548) $stop;
        counter <= counter + 1;
    end
    
    

    // Initialise the whole trace unit

    task initialise_device();
        begin
            counter <= -1;
        end
    endtask


endmodule
