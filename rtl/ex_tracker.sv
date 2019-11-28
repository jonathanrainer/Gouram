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
    input integer dec_stage_end,
    input trace_format if_data_i,
    
    // Inputs from Memory Phase
    input logic data_mem_req,
    input logic [DATA_ADDR_WIDTH-1:0] data_mem_addr,
    input logic data_mem_rvalid,
//    input logic branch_decision,
    
    // Outputs to EX Tracker
   (* dont_touch = "yes" *) output trace_format ex_data_o,
   output bit trace_ready,
   output bit repeat_detected
);

    trace_format trace_element;
    
    // State Machine to Control Unit
    enum bit [2:0] {
            EXECUTION_START =       3'b000,
            GET_DATA_FROM_BUFFER =  3'b001,
            CHECK_JUMP_DONE =       3'b010,
            CHECK_MEMORY_REQS =     3'b011,
            SCAN_MEMORY_REQ =       3'b100,
            CHECK_MEMORY_RVALID =   3'b101,
            SCAN_MEMORY_RVALID =    3'b110,
            OUTPUT_RESULT =         3'b111
         } state;
         
    integer previous_end = 0;
    integer dec_stage_end_buffer_output;
    bit addr_found;
    bit rvalid_time_found;
    bit rvalid_scan_necessary;
    
    signal_tracker_if #(1) data_mem_req_port (clk, rst_n, counter, data_mem_req);
    signal_tracker_if #(1) data_mem_rvalid_port (clk, rst_n, counter, data_mem_rvalid);
    signal_tracker_if #(DATA_ADDR_WIDTH) data_mem_addr_port (clk, rst_n, counter, data_mem_addr);
    
    signal_tracker_time_test  #(SIGNAL_BUFFER_SIZE) data_mem_req_buffer (
        data_mem_req_port.TimeTest
    );
    integer data_mem_req_present;
    signal_tracker_time_test  #(SIGNAL_BUFFER_SIZE) data_mem_rvalid_buffer (
        data_mem_rvalid_port.TimeTest
    );
    integer data_mem_rvalid_present;

    signal_tracker_value_find  #(SIGNAL_BUFFER_SIZE) data_mem_addr_buffer (
        data_mem_addr_port.ValueFind
    );
    
    // Trace Buffer
     bit data_request;
     bit data_present;
     bit data_valid; 
     trace_format buffer_output;
     trace_buffer #(TRACE_BUFFER_SIZE, trace_format) t_buffer (
        .clk(clk), .rst_n(rst_n), .ready_signal(if_data_ready), .trace_element_in(if_data_i), 
        .data_request(data_request), .data_present(data_present), .trace_element_out(buffer_output),
        .data_valid(data_valid), .dec_stage_end_in(dec_stage_end), .dec_stage_end_out(dec_stage_end_buffer_output)
     );
  
            
    initial
    begin
        initialise_module();
    end
         
    always_ff @(posedge clk)
    begin
        if (!rst_n) initialise_module();
        unique case(state)
            EXECUTION_START:
            begin
                trace_ready <= 1'b0;
                if (data_present)
                begin
                    data_request <= 1'b1;
                    state <= GET_DATA_FROM_BUFFER;
                end
            end
            GET_DATA_FROM_BUFFER:
            begin
                if (data_valid)
                begin
                    data_request <= 1'b0;
                    // If the repeat marker is found then it needs to be communicated to the outside world.
                    if (buffer_output.instruction == 32'h00002083) 
                    begin
                        repeat_detected <= 1'b1;
                        state <= EXECUTION_START;
                    end
                    else
                    begin 
                        // Copy in data to the internal trace buffer
                        trace_element <= buffer_output;
                        // Set ex_ready queue input values to read back in next cycle.
                        check_past_data_mem_req_values(counter - dec_stage_end_buffer_output);
                        state <= CHECK_MEMORY_REQS;
                    end
                end
            end
            CHECK_MEMORY_REQS:
            begin
                if (data_mem_req_port.data_valid)
                begin
                    data_mem_req_port.recalculate_time <= 0;
                    state <= CHECK_MEMORY_RVALID;
                    // Check if the memory occured in the tracked past
                    if (data_mem_req_port.time_out[0] != -1) 
                    begin
                        trace_element.mem_trans_time_start <= data_mem_req_port.time_out[0];
                        check_past_data_mem_rvalid_values(counter - data_mem_req_port.time_out[0]);
                        check_past_data_mem_addr_values(counter - data_mem_req_port.time_out[0]);
                    end
                    else if (data_mem_req_present != -1) 
                    begin
                        trace_element.mem_trans_time_start <= data_mem_req_present;
                        check_past_data_mem_rvalid_values(data_mem_req_present);
                        check_past_data_mem_addr_values(counter-data_mem_req_present);
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
                if (data_mem_req_present == -1 && data_mem_req) data_mem_req_present = counter;
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
                if (!addr_found && data_mem_addr_port.data_valid)
                begin
                    trace_element.mem_addr <= data_mem_addr_port.signal_recall;
                    data_mem_addr_port.recalculate_back_cycle <= 0;
                    addr_found <= 1'b1;
                end
                if (!rvalid_time_found && data_mem_rvalid_port.data_valid)
                begin
                    rvalid_time_found  <= 1'b1;
                    data_mem_rvalid_port.recalculate_time <= 0;
                    // Check if the memory occured in the tracked past
                    if (data_mem_rvalid_port.time_out[0] != -1) 
                    begin
                        trace_element.mem_trans_time_end <= data_mem_rvalid_port.time_out[0];
                        previous_end <= data_mem_rvalid_port.time_out[0];
                        data_mem_req_port.previous_end_update <= 1'b1;
                        data_mem_req_port.new_previous_end <= data_mem_rvalid_port.time_out[0];
                    end
                    else if (data_mem_rvalid_present != -1) 
                    begin
                        trace_element.mem_trans_time_end <= data_mem_rvalid_present;
                        previous_end <= data_mem_rvalid_present;
                        data_mem_req_port.previous_end_update <= 1'b1;
                        data_mem_req_port.new_previous_end <= data_mem_rvalid_present;
                    end
                    else if (data_mem_rvalid) 
                    begin
                        trace_element.mem_trans_time_end <= counter;
                        previous_end <= counter;
                        data_mem_req_port.previous_end_update <= 1'b1;
                        data_mem_req_port.new_previous_end <= counter;
                    end
                    // If all these fail then the memory rvalid hasn't yet been asserted and
                    // it just needs to be polled every cycle until it does.
                    else rvalid_scan_necessary <= 1'b1;
                end
                if ((data_mem_rvalid_present == -1) && data_mem_rvalid)  data_mem_rvalid_present = counter;
                // Make a decision as to which state to go to next
                if (rvalid_time_found && addr_found)
                begin
                    rvalid_time_found <= 1'b0;
                    addr_found <= 1'b0;
                    if (rvalid_scan_necessary && data_mem_rvalid)
                    begin
                        trace_element.mem_trans_time_end <= counter;
                        previous_end <= counter;
                        rvalid_scan_necessary <= 1'b0;
                        state <= OUTPUT_RESULT;
                    end
                    else if (rvalid_scan_necessary) 
                    begin
                        state <= SCAN_MEMORY_RVALID;
                        rvalid_scan_necessary <= 1'b0;
                    end
                    else state <= OUTPUT_RESULT;
                end
            end
            SCAN_MEMORY_RVALID:
            begin
                if (data_mem_rvalid) 
                begin 
                    trace_element.mem_trans_time_end <= counter;
                    previous_end <= counter;
                    data_mem_req_port.previous_end_update <= 1'b1;
                    data_mem_req_port.new_previous_end <= counter;
                    state <= OUTPUT_RESULT;
                end 
            end
            OUTPUT_RESULT:
            begin
                trace_ready <= 1'b1;
                ex_data_o <= trace_element;
                data_mem_req_port.previous_end_update <= 1'b0;
                state <= EXECUTION_START;
            end
        endcase
    end
        
    task initialise_module();
        state <= EXECUTION_START;
        trace_element <= '{default:0};
        data_request <= 1'b0;
        previous_end <= 0;
        addr_found <= 1'b0;
        rvalid_time_found <= 1'b0;
        rvalid_scan_necessary <= 1'b0;
        repeat_detected <= 0;
    endtask
    
    task check_past_data_mem_req_values(input integer queue_input);
            data_mem_req_port.value_in <= queue_input;
            if (data_mem_req) data_mem_req_present <= counter;
            else data_mem_req_present <= -1;
            data_mem_req_port.recalculate_time <= 1'b1;
        endtask
    
    task check_past_data_mem_rvalid_values(input integer queue_input);
            data_mem_rvalid_port.value_in <= queue_input;
            if (data_mem_rvalid) data_mem_rvalid_present <= counter;
            else data_mem_rvalid_present <= -1;
            data_mem_rvalid_port.recalculate_time <= 1'b1;
        endtask
    
    task check_past_data_mem_addr_values(input integer queue_input);
        data_mem_addr_port.cycles_back_to_recall <= queue_input;
        data_mem_addr_port.recalculate_back_cycle <= 1'b1;
    endtask
    
        
endmodule
