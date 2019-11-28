include "../include/gouram_config.sv";

module gouram_wrapper
#(
    parameter TRACE_BUFFER_SIZE = 8,
    parameter SIGNALS_TO_BUFFER = 64,
    parameter IF_TRACKER_BUFFER_SIZE = 8
)
(   
    input clk,
    input rst_n,
    
    // Processor Tracing Signals
    input jump_done,
    input branch_decision,
    input is_decoding,
    input pc_set,
    input branch_req,
    input id_ready,
    
    // Instruction Memory Ports
    input                               instr_req,
    input                               instr_rvalid,
    input [`INSTR_DATA_WIDTH-1:0]       instr_rdata,
    input [`INSTR_ADDR_WIDTH-1:0]       instr_addr,
    input                               instr_gnt,

    // EX Register Ports

    input                           data_mem_req,
    input [`DATA_ADDR_WIDTH-1:0]    data_mem_addr,
    input                           data_mem_rvalid, 
    
    output [159:0] trace_data_o,
    output trace_capture_enable,
    output lock,
    output trace_ready,
    
    output [31:0] counter,
    output [31:0] mem_req_count
);
   

 gouram
#(
    `INSTR_DATA_WIDTH, `INSTR_ADDR_WIDTH, `DATA_ADDR_WIDTH, TRACE_BUFFER_SIZE, SIGNALS_TO_BUFFER, IF_TRACKER_BUFFER_SIZE
)
gouram
(
	.clk(clk),
	.rst_n(rst_n),
	.jump_done(jump_done),
	.branch_decision(branch_decision),
	.is_decoding(is_decoding),
	.branch_req(branch_req),
	.pc_set(pc_set),
	.id_ready(id_ready),
	.instr_req(instr_req),
	.instr_rvalid(instr_rvalid),
	.instr_rdata(instr_rdata),
	.instr_addr(instr_addr),
	.instr_gnt(instr_gnt),
	.data_mem_req(data_mem_req),
	.data_mem_rvalid(data_mem_rvalid),
	.data_mem_addr(data_mem_addr),
	.trace_data_o(trace_data_o),
	.trace_capture_enable(trace_capture_enable),
	.lock(lock),
	.counter_o(counter),
	.mem_req_count(mem_req_count),
	.trace_ready(trace_ready)
);

endmodule
