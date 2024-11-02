module input_mems #(
    parameter INW = 12,
    parameter M = 7,
    parameter N = 9,
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1),
    localparam A_ADDR_BITS = $clog2(M*MAXK),
    localparam B_ADDR_BITS = $clog2(MAXK*N)
    )(
    input clk, reset,
    input [INW-1:0] AXIS_TDATA,
    input AXIS_TVALID,
    input [K_BITS:0] AXIS_TUSER,
    output logic AXIS_TREADY,
    output logic matrices_loaded,
    input compute_finished,
    output logic [K_BITS-1:0] K,
    input [A_ADDR_BITS-1:0] A_read_addr,
    output logic signed [INW-1:0] A_data,
    input [B_ADDR_BITS-1:0] B_read_addr,
    output logic signed [INW-1:0] B_data
); 

endmodle

module address_counter()
    always_ff @(posedge clk) begin
        if(clear) begin
            address <= 0;
        end
        else begin
            if(address <= MATRIX_SIZE-1) begin
                address <= address + 1;
            end
        end
    end
endmodule

module memory #(
    parameter WIDTH=16, SIZE=64,
    localparam LOGSIZE=$clog2(SIZE)
    )(
        input [WIDTH-1:0] data_in,
        output logic [WIDTH-1:0] data_out,
        input [LOGSIZE-1:0] addr,
        input clk, wr_en
    );
    logic [SIZE-1:0][WIDTH-1:0] mem;
    always_ff @(posedge clk) begin
        data_out <= mem[addr];
        if (wr_en) begin
            mem[addr] <= data_in;
        end
    end
endmodule