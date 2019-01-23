

interface signal_tracker_if 
#(
    parameter TRACKED_SIGNAL_WIDTH = 1
) 
(
    input logic clk, 
    input logic rst_n, 
    input integer counter,
    logic [TRACKED_SIGNAL_WIDTH-1:0] tracked_signal
);
    integer value_in;
    logic recalculate_time;
    integer cycles_back_to_recall;
    bit recalculate_back_cycle;
    integer signed time_out [1:0];
    bit [TRACKED_SIGNAL_WIDTH-1:0] signal_recall;
    bit data_valid;
    
    modport TimeTest 
    (
        input clk,
        input rst_n,
        input counter,
        input tracked_signal,
        input value_in,
        input recalculate_time,
        output time_out,
        output data_valid
    );
    
    modport ValueFind
    (
        input clk,
        input rst_n,
        input tracked_signal,
        input cycles_back_to_recall,
        input recalculate_back_cycle,
        output signal_recall,
        output data_valid
    );
        
    
endinterface
