include "../include/gouram_config.sv";

module gouram_wrapper
(   
    input clk,
    input rst_n,
    
    // Processor Tracing Signals
    input jump_done,
    
    // Instruction Memory Ports
    input                      		instr_rvalid,
    input [`INSTR_DATA_WIDTH-1:0]   instr_rdata,

    // EX Register Ports

    input                           data_mem_req,
    input [`DATA_ADDR_WIDTH-1:0]    data_mem_addr,
    input                           data_mem_rvalid, 
    
    output [127:0] trace_data_o
);

 gouram
#(
    `INSTR_DATA_WIDTH, `DATA_ADDR_WIDTH, 8
)
gouram
(
	.clk(clk),
	.rst_n(rst_n),
	.jump_done(jump_done),
	.instr_rvalid(instr_rvalid),
	.instr_rdata(instr_rdata),
	.data_mem_req(data_mem_req),
	.data_mem_rvalid(data_mem_rvalid),
	.data_mem_addr(data_mem_addr),
	.trace_data_o(trace_data_o)
);

endmodule
