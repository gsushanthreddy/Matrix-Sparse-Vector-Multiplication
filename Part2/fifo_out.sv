module memory_dual_port #(
    parameter WIDTH=48,
    parameter SIZE=16,
    localparam LOGSIZE= $clog2(SIZE)
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
        if (read_addr == write_addr) begin
            data_out <= data_in;
        end
    end
 end
endmodule

module head_block #(
    parameter DEPTH=17,
    localparam LOGDEPTH=$clog2(DEPTH)
)(
    input clk,
    input reset,
    input wr_en,
    output logic [LOGDEPTH-1:0] write_addr
);

always_ff @(posedge clk) begin
    if (reset == 1) begin
        write_addr <= 0;
    end
    else begin 
        if (wr_en == 1) begin
            if(write_addr == DEPTH-1) begin
                write_addr <=0;
            end
            else begin
                write_addr <= write_addr+1;
            end
        end
    end
end   
endmodule

module tail_block #(
    parameter DEPTH =17,
    localparam LOGDEPTH=$clog2(DEPTH)
)(
    input clk,
    input reset,
    input rd_en,
    output logic [LOGDEPTH-1:0] read_addr
);

logic [LOGDEPTH-1 :0] tail;

always_ff @(posedge clk) begin
    if (reset) begin
        tail <= 0;
    end
    else begin
        if (rd_en == 1) begin
            if (tail == DEPTH-1) begin
                tail <= 0;
            end
            else begin
                tail <= tail + 1; 
            end
        end
    end
end

always_comb begin
    if (rd_en == 0) begin
        read_addr = tail;
    end
    
    else begin
        if(tail == DEPTH-1) begin
            read_addr = 0;
        end
        else begin
            read_addr = tail + 1;
        end
    end   
end
endmodule

module capacity_block #(
    parameter DEPTH = 17
) (
    input clk,
    input reset,
    input rd_en,
    input wr_en,
    output logic [($clog2(DEPTH+1))-1:0] capacity
);

always_ff @(posedge clk) begin
    if (reset) begin
        capacity <= DEPTH;
    end
    else begin
        if (~wr_en && rd_en) begin
            capacity <= capacity + 1;
        end 
        else if (wr_en && ~rd_en) begin
            capacity <= capacity - 1;
        end
        else begin
            capacity <= capacity;
        end
    end
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
    if(capacity != DEPTH) begin
        AXIS_TVALID = 1;
    end
    else begin
        AXIS_TVALID = 0;
    end
end

// control logic for read enable signal:
always_comb begin
    if(AXIS_TREADY && AXIS_TVALID) begin
        rd_en = 1;
    end
    else begin 
        rd_en = 0;
    end
end

// intantiating Head block:
head_block #(.DEPTH(DEPTH)) head_block_inst (
    .clk(clk),
    .reset(reset),
    .wr_en(wr_en),
    .write_addr(wr_addr)
);

 // instantiating Tail block:
 tail_block #(.DEPTH(DEPTH)) tail_block_inst (
    .clk(clk),
    .reset(reset),
    .rd_en(rd_en),
    .read_addr(rd_addr)
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
    .read_addr(rd_addr),
    .clk(clk),
    .wr_en(wr_en)
);

endmodule