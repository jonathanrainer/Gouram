//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/18/2017 11:38:02 AM
// Design Name: 
// Module Name: riscv_testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import gouram_datatypes::*;

include "../../include/gouram_config.sv";

module gouram_testbench;

    logic clk;
    logic rst_n;
    
    // Instruction memory interface
    logic instr_req_o;
    logic instr_gnt_i;
    logic instr_rvalid_i;
    logic [31:0] instr_addr_o;
    logic [31:0] instr_rdata_i;
    
    // Instruction Memory
    instruction_memory #(`INSTR_ADDR_WIDTH, `INSTR_DATA_WIDTH) i_mem  (clk, instr_req_o, instr_addr_o, 
                                instr_gnt_i, instr_rvalid_i, instr_rdata_i);
    
    // Data memory interface
    logic        data_req_o;
    logic        data_gnt_i;
    logic        data_rvalid_i;
    logic        data_we_o;
    logic [3:0]  data_be_o;
    logic [31:0] data_addr_o;
    logic [31:0] data_wdata_o;
    logic [31:0] data_rdata_i;
    logic        data_err_i;
    
    data_memory  #(`DATA_ADDR_WIDTH, 32) d_mem (clk, data_req_o, data_addr_o, data_we_o, data_be_o,
                        data_wdata_o, data_gnt_i,  data_rvalid_i, data_rdata_i,
                        data_err_i);
    
    // Interrupt inputs
    logic [31:0] irq_i;                 // level sensitive IR line
    
    logic        core_busy_o;
    
    logic  ext_perf_counters_i;
    
    // Tracing Signals
    logic if_busy_o;
    logic if_ready_o;
    logic id_ready_o;
    logic is_decoding_o;
    logic jump_done_o;
    logic data_req_id_o;
    logic ex_ready_o;
    logic wb_ready_o;
    logic illegal_instr_o;
    logic branch_decision_o;
    logic branch_req_o;
    
    riscv_core 
        #(
            0, `INSTR_DATA_WIDTH
        )
        core
        (
            .clk_i(clk),
            .rst_ni(rst_n),
            .clock_en_i(1'b1),
            .test_en_i(1'b0),
            .boot_addr_i(32'h20),
            .core_id_i(4'b0),
            .cluster_id_i(6'b0),
            .instr_req_o(instr_req_o),
            .instr_gnt_i(instr_gnt_i),
            .instr_rvalid_i(instr_rvalid_i),
            .instr_addr_o(instr_addr_o),
            .instr_rdata_i(instr_rdata_i),
            .data_req_o(data_req_o),
            .data_gnt_i(data_gnt_i),
            .data_rvalid_i(data_rvalid_i),
            .data_we_o(data_we_o),
            .data_be_o(data_be_o),
            .data_addr_o(data_addr_o),
            .data_wdata_o(data_wdata_o),
            .data_rdata_i(data_rdata_i),
            .irq_i(irq_i),
            .fetch_enable_i(1'b1),
            .core_busy_o(core_busy_o),
            .if_busy_o(if_busy_o),
            .if_ready_o(if_ready_o),
            .id_ready_o(id_ready_o),
            .is_decoding_o(is_decoding_o),
            .jump_done_o(jump_done_o),
            .data_req_id_o(data_req_id_o),
            .ex_ready_o(ex_ready_o),
            .wb_ready_o(wb_ready_o),
            .illegal_instr_o(illegal_instr_o)
        );
    
    trace_format trace_o;
    
    gouram #(`INSTR_ADDR_WIDTH, `INSTR_DATA_WIDTH, `DATA_ADDR_WIDTH, `TRACE_BUFFER_SIZE) tracer (
        clk, rst_n, if_busy_o, if_ready_o, branch_decision_o,
         instr_req_o, instr_addr_o, instr_gnt_i,  instr_rvalid_i, instr_rdata_i,
         id_ready_o, jump_done_o, is_decoding_o,illegal_instr_o, branch_req_o, ex_ready_o,
         data_req_o, data_gnt_i, data_rvalid_i, data_addr_o, wb_ready_o, trace_o);
    
    initial
        begin
            // Set up initial signals
            clk = 0;
            rst_n = 0;
            #50 rst_n = 1;
        end
    
    always
        begin
            #5 clk = ~clk;      
            if (trace_o != null && trace_o.addr == 32'h54) $finish;
        end

endmodule