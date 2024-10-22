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
    logic [$clog2(MAXK+1)-1:0] TUSER_K;
    logic new_A;
    logic [A_ADDR_BITS-1:0] A_write_ADDR;
    logic [B_ADDR_BITS-1:0] B_write_ADDR;
    logic wr_en_a;
    logic wr_en_b;
    // How to instantiate memory modules
    memory memory_a(AXIS_TDATA, A_data, A_read_addr, clk, wr_en_a); // wr_en signal to write values in memory? 
    memory memory_b(AXIS_TDATA, B_data, B_read_addr, clk, wr_en_b); 
    
    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1]; // K value from AXI input stream protocol 
    assign new_A = AXIS_TUSER[0];

    always_ff @(posedge clk) begin
        if(reset) begin
            AXIS_TREADY <= 0;
            matrices_loaded <= 0;
            K <= 0;
            A_data <= 0;
            B_data <= 0;
        end
        else begin
            if(AXIS_TVALID && AXIS_TREADY) begin
                if(new_A) begin
                    a_addr <= 0;
                    memo
                end
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