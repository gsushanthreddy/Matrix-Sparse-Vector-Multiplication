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

module fifo_out #(
    parameter OUTW = 48,
    parameter DEPTH = 17,
    localparam LOGDEPTH = $clog2(DEPTH)
 )(
    input clk, 
    input reset,
    input [OUTW-1:0] data_in,
    input wr_en,
    output logic [$clog2(DEPTH+1)-1:0] capacity,
    output logic [OUTW-1:0] AXIS_TDATA,
    output logic AXIS_TVALID,
    input AXIS_TREADY 
 );

// internal logics fot head block
logic [LOGDEPTH-1 : 0] wr_addr;

// interal logics for tail block
logic rd_en;
logic [LOGDEPTH-1 : 0] rd_addr;

// control logic FOR AXIS_TVALID:
always_comb begin
    if(capacity != 0)
        AXIS_TVALID = 1;
    else 
        AXIS_TVALID = 0;
end

// control logic for read enable signal:
always_comb begin
    if( AXIS_TREADY && AXIS_TVALID)
        rd_en = 1;
    else 
        rd_en = 0;
end

// intantiating Head block:
head_block #(.DEPTH(DEPTH)) head_block_inst (
    .clk(clk),
    .reset(reset),
    .wr_en(wr_en),
    .wr_addr(wr_addr)
);

 // instantiating Tail block:
 tail_block #(.DEPTH(DEPTH)) tail_block_inst (
    .clk(clk),
    .reset(reset),
    .rd_en(rd_en),
    .rd_addr(rd_addr)
 );

 // instantiating capacity block:
 capacity_block #(.DEPTH(DEPTH)) capacity_block_inst(
    .clk(clk),
    .reset(reset),
    .rd_en(rd_en),
    .wr_en(wr_en),
    .capacity(capacity)
 );

 // Instatiating Memory block:
 memory_dual_port #(.WIDTH(OUTW),.SIZE(DEPTH)) memory_dual_port_inst (
    .data_in(data_in),
    .data_out(AXIS_TDATA),// this will be wrong check before finalising
    .write_addr(wr_addr),
    .read_addr(read_addr),
    .clk(clk),
    .wr_en(wr_en)
);

endmodule