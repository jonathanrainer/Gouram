module ex_tracker
#(
    parameter DATA_ADDR_WIDTH = 32,
    parameter SIGNAL_BUFFER_SIZE = 256,
    parameter TRACE_BUFFER_SIZE = 32,
    parameter type trace_format = int
)
(
    input logic clk,
    input logic rst_n,
    
    // Inputs from Counter
    input integer counter,

    // Inputs from ID Tracker
    input logic if_data_ready,
    trace_format if_data_i,
    
    // Inputs from Memory Phase
    input logic data_mem_req,
    input logic [DATA_ADDR_WIDTH-1:0] data_mem_addr,
    input logic data_mem_grant,
    input logic data_mem_rvalid,
    
    // Outputs to EX Tracker
    trace_format ex_data_o
);

    trace_format trace_element;
    
    // State Machine to Control Unit
    enum logic [2:0] {
            EXECUTION_START =       3'b000,
            GET_DATA_FROM_BUFFER =  3'b001,
            CHECK_MEMORY_REQS =     3'b010,
            SCAN_MEMORY_REQ =       3'b011,
            CHECK_MEMORY_RVALID =   3'b100,
            SCAN_MEMORY_RVALID =    3'b101,
            OUTPUT_RESULT =         3'b110
         } state;
         
    integer previous_end = 0;
    bit update_end = 0;
    
    // Buffer to track the start of memory transactions
    integer data_mem_req_value_in = 0;
    integer data_mem_req_time_out [1:0] = {0,0};
    bit data_mem_req_recalculate_time = 1'b0;
    signal_tracker  #(1, SIGNAL_BUFFER_SIZE) data_mem_req_buffer (
        .clk(clk), .rst_n(rst_n), .counter(counter), .tracked_signal(data_mem_req), .value_in(data_mem_req_value_in),
        .time_out(data_mem_req_time_out), .recalculate_time(data_mem_req_recalculate_time), .previous_end_i(previous_end)
        );
    logic data_mem_req_present = 0;
    
    // Buffer to track the rvalid or the end of memory transactions
    integer data_mem_rvalid_value_in = 0;
    integer data_mem_rvalid_time_out [1:0] = {0,0};
    bit data_mem_rvalid_recalculate_time = 1'b0;
    signal_tracker  #(1, SIGNAL_BUFFER_SIZE) data_mem_rvalid_buffer (
        .clk(clk), .rst_n(rst_n), .counter(counter), .tracked_signal(data_mem_rvalid), .value_in(data_mem_rvalid_value_in),
        .time_out(data_mem_rvalid_time_out), .recalculate_time(data_mem_rvalid_recalculate_time), .previous_end_i(previous_end)
        );
    logic data_mem_rvalid_present = 0;
    
    // Buffer to track Memory Addresses
    integer data_mem_addr_cycles_back = 0;
    bit data_mem_addr_recalculate_back_cycle = 1'b0;
    bit [DATA_ADDR_WIDTH-1:0] recalled_addr = 0;
    signal_tracker  #(DATA_ADDR_WIDTH, SIGNAL_BUFFER_SIZE) data_mem_addr_buffer (
        .clk(clk), .rst_n(rst_n), .counter(counter), .tracked_signal(data_mem_addr), 
        .cycles_back_to_recall(data_mem_addr_cycles_back), 
        .recalculate_back_cycle(data_mem_addr_recalculate_back_cycle),
        .signal_recall(recalled_addr));
    
    // Trace Buffer
     bit data_request = 1'b0;
     bit data_present;
     trace_format buffer_output;
     trace_buffer #(TRACE_BUFFER_SIZE, trace_format) t_buffer (
        .clk(clk), .rst_n(rst_n), .ready_signal(if_data_ready), .trace_element_in(if_data_i), 
        .data_request(data_request), .data_present(data_present), .trace_element_out(buffer_output)
     );
    
    always @(posedge rst_n)
    begin
        initialise_module();
    end
            
    initial
    begin
        initialise_module();
    end
         
    always_ff @(posedge clk)
    begin
        unique case(state)
            EXECUTION_START:
            begin
                if (data_present)
                begin
                    data_request <= 1'b1;
                    state <= GET_DATA_FROM_BUFFER;
                end
            end
            GET_DATA_FROM_BUFFER:
            begin
                data_request <= 1'b0;
                // Copy in data to the internal trace buffer
                trace_element <= buffer_output;
                // Set ex_ready queue input values to read back in next cycle.
                check_past_data_mem_req_values(counter - previous_end + 1);
                state <= CHECK_MEMORY_REQS;
            end
            CHECK_MEMORY_REQS:
            begin
                data_mem_req_recalculate_time <= 0;
                state <= CHECK_MEMORY_RVALID;
                // Check if the memory occured in the tracked past
                if (data_mem_req_time_out[0] != -1) 
                begin
                    trace_element.mem_trans_time_start <= data_mem_req_time_out[0];
                    check_past_data_mem_rvalid_values(counter - data_mem_req_time_out[0]);
                    check_past_data_mem_addr_values(counter - data_mem_req_time_out[0]);
                end
                else if (data_mem_req_present) 
                begin
                    trace_element.mem_trans_time_start <= counter - 1;
                    check_past_data_mem_rvalid_values(counter - 1);
                    check_past_data_mem_addr_values(1);
                end
                else if (data_mem_req) 
                begin
                    trace_element.mem_trans_time_start <= counter;
                    check_past_data_mem_rvalid_values(counter);
                    check_past_data_mem_addr_values(0);
                end
                // If all these fail then the memory req hasn't yet been asserted and
                // it just needs to be polled every cycle until it does.
                else state <= SCAN_MEMORY_REQ;
            end
            SCAN_MEMORY_REQ:
            begin
                if (data_mem_req) 
                begin 
                    trace_element.mem_trans_time_start <= counter;
                    check_past_data_mem_addr_values(0);
                    state <= CHECK_MEMORY_RVALID;
                end
            end
            CHECK_MEMORY_RVALID:
            begin
                data_mem_rvalid_recalculate_time <= 0;
                data_mem_addr_recalculate_back_cycle <=0;
                trace_element.mem_addr <= recalled_addr;
                state <= OUTPUT_RESULT;
                // Check if the memory occured in the tracked past
                if (data_mem_rvalid_time_out[0] != -1) 
                begin
                    trace_element.mem_trans_time_end <= data_mem_rvalid_time_out[0];
                    previous_end <= data_mem_rvalid_time_out[0];
                    update_end <= 1'b1;
                end
                else if (data_mem_rvalid_present) 
                begin
                    trace_element.mem_trans_time_end <= counter - 1;
                    previous_end <= counter - 1;
                    update_end <= 1'b1;
                end
                else if (data_mem_rvalid) 
                begin
                    trace_element.mem_trans_time_end <= counter;
                    previous_end <= counter;
                    update_end <= 1'b1;
                end
                // If all these fail then the memory rvalid hasn't yet been asserted and
                // it just needs to be polled every cycle until it does.
                else state <= SCAN_MEMORY_RVALID;
            end
            SCAN_MEMORY_RVALID:
            begin
                if (data_mem_rvalid) 
                begin 
                    trace_element.mem_trans_time_end <= counter;
                    previous_end <= counter;
                    update_end <= 1'b1;
                    state <= OUTPUT_RESULT;
                end 
            end
            OUTPUT_RESULT:
            begin
                ex_data_o <= trace_element;
                state <= EXECUTION_START;
            end
        endcase
    end
        
    task initialise_module();
        state <= EXECUTION_START;
        trace_element <= '{default:0};
    endtask
        
    task check_past_data_mem_req_values(input integer queue_input);
        data_mem_req_value_in <= queue_input;
        data_mem_req_present <= data_mem_req;
        data_mem_req_recalculate_time <= 1'b1;
    endtask
    
    task check_past_data_mem_rvalid_values(input integer queue_input);
            data_mem_rvalid_value_in <= queue_input;
            data_mem_rvalid_present <= data_mem_rvalid;
            data_mem_rvalid_recalculate_time <= 1'b1;
        endtask
    
    task check_past_data_mem_addr_values(input integer queue_input);
        data_mem_addr_cycles_back <= queue_input;
        data_mem_addr_recalculate_back_cycle <= 1'b1;
    endtask
    
        
endmodule
