module instruction_memory
  #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_WORDS  = 256
  )(
    // Clock and Reset
    input  logic                    clk,
    
    input  logic                    req_i,
    input  logic [ADDR_WIDTH-1:0]   addr_i,
    
    output logic                    gnt_o,
    output logic                    rvalid_o,
    output logic [DATA_WIDTH-1:0]   rdata_o
  );

  localparam words = NUM_WORDS/(DATA_WIDTH/8);

  logic [DATA_WIDTH/8-1:0][7:0] mem[words];
  logic [ADDR_WIDTH-1-$clog2(DATA_WIDTH/8):0] addr;
  
  enum logic [1:0] {
    SLEEP = 2'b00,
    WAITG = 2'b01,
    GRANT = 2'b10,
    WAITR = 2'b11
    } State, Next;
    
    int delay_counter = 0;
    int delay_limit = 1;

  initial
    begin
        mem     = '{default:32'h0};
        mem[0]  = 32'h10000113; // ADDI R0, 0x100, R2
        mem[1]  = 32'h00100093; // ADDI R0, 0x1, R1
        mem[2]  = 32'h401101B3; // SUB R2, R1, R3 (R3 := R2 - R1)
        mem[3]  = 32'h00002283; // LW R0, 0x0, R5
        mem[4]  = 32'h00402303; // LW R0, 0x4, R6
        mem[5]  = 32'h06302823; // SW R0, 0x70, R3
        mem[6]  = 32'h07002E03; // LW R0, 0x70, R28
        mem[7]  = 32'hF4918067; // JALR R3, -0x48, R0 
        mem[18] = 32'h026283B3; // MUL R5 R6 R7
        mem[19] = 32'h0253B433; // Divide R6 R7 R8 (R8 := R7/R6)
        mem[20] = 32'h006386B3; // ADD R6 R7 R13
        mem[21] = 32'h0000006F; // Loop on this address
        mem[32] = 32'hF81FF06F; // Jump to Address 0
        mem[33] = 32'h0000006F; // Trap Address
        gnt_o = 1'b0;
        rvalid_o = 1'b0;
        rdata_o = 32'bx;
        State = SLEEP;
        Next = SLEEP;       
    end

  always @(posedge clk)
  begin
    State = Next;
    unique case(State)
        SLEEP: 
        begin
            rvalid_o = 0;
            if (req_i == 1)
            begin
                Next = WAITG;
            end    
        end
        WAITG:
        begin
            if (delay_counter < delay_limit) delay_counter++;
            else 
            begin
                delay_counter = 0;
                Next = GRANT;
                gnt_o = 1;
            end
         end
         GRANT: 
         begin
            gnt_o = 0;
            addr = addr_i[ADDR_WIDTH-1:$clog2(DATA_WIDTH/8)];
            Next = WAITR;
         end
         WAITR:
         begin
            if (delay_counter < delay_limit) delay_counter++;
            else 
            begin
                delay_counter = 0;
                Next = SLEEP;
                rvalid_o = 1;
                rdata_o = mem[addr];
            end
         end
      endcase 
  end
  
  
  
endmodule
