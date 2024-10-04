module memory_dual_port #(
    parameter WIDTH=16,
    parameter SIZE=64,
    localparam LOGSIZE=$clog2(SIZE)
 )(
    input [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out,
    input [LOGSIZE-1:0] write_addr, read_addr,
    input clk, wr_en
 );
 
 logic [SIZE-1:0][WIDTH-1:0] mem;
 
 always_ff @(posedge clk) begin
    data_out <= mem[read_addr];
    if (wr_en) begin 
        mem[write_addr] <= data_in; 
        if (read_addr == write_addr)
            data_out <= data_in;
    end
 end
endmodule

module head_block #(
    parameter DEPTH=64,
    localparam LOGDEPTH=$clog2(DEPTH)
)(
    input clk,
    input reset,
    input wr_en,
    output [LOGDEPTH-1:0] write_addr
);

always_ff @(posedge clk) begin
    if (reset == 1)
        wr_addr <= 0;
    else if (wr_en == 1)
        if(wr_addr == DEPTH-1)
            write_addr <=0
        else
        wr_addr <= wr_addr+1;
end   
endmodule

module tail_block #(
    parameter DEPTH =64,
    localparam LOGDEPTH=$clog2(DEPTH)
)(
    input clk,
    input reset,
    input rd_en,
    output [LOGDEPTH-1:0] read_addr
);

always_ff @(posedge clk) begin
    if (rd_en == 0)
        rd_addr <= tail;
    else
        if (rd_addr == DEPTH-1)
            rd_addr <= 0;
        else
            rd_addr <= tail+1;
end
endmodule

module capacity_block #(
    parameter DEPTH = 64
) (
    input clk,
    input reset,
    input rd_en,
    input wr_en,
    output [($clog2(DEPTH-1))-1:0] capacity
);

always_ff @(posedge clk) begin
    if (reset)
        capacity <= DEPTH;

    else if (~wr_en && rd_en)
        capacity <= capacity + 1;

    else if (wr_en && ~rd_en)
        capacity <= capacity - 1;
end
endmodule