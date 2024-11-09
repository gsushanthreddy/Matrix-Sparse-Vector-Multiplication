module input_mems_datapath #(
    parameter INW = 12,
    parameter M = 8,
    parameter N = 11,
    parameter MAXK = 9,
    localparam K_BITS = $clog2(MAXK+1),
    localparam A_ADDR_BITS = $clog2(M*MAXK),
    localparam B_ADDR_BITS = $clog2(MAXK*N)
) (
    input clk,
    input reset,
    input [INW-1:0] AXIS_TDATA,
    input AXIS_TVALID,
    
    input [A_ADDR_BITS-1:0] A_read_addr,
    output logic signed [INW-1:0] A_data,
    input [B_ADDR_BITS-1:0] B_read_addr,
    output logic signed [INW-1:0] B_data,
    
    input [K_BITS-1:0] K,
    
    // Control signals
    input wr_en_A,
    input wr_en_B,
    
    input matrices_loaded,
    
    // Status Signals
    output logic matrix_A_loaded,
    output logic matrix_B_loaded
);

    logic [A_ADDR_BITS-1:0] A_write_address;
    logic [B_ADDR_BITS-1:0] B_write_address;

    logic [A_ADDR_BITS-1:0] A_address;
    logic [B_ADDR_BITS-1:0] B_address;

    logic signed [INW-1:0] A_data_out;
    logic signed [INW-1:0] B_data_out;

    
    // Logic for address counter for 'A'
    always_ff @(posedge clk) begin
        if((reset == 1) || (matrix_A_loaded == 1)) begin
            A_write_address <= 0;
        end
        else begin
            if (wr_en_A) begin
                A_write_address <= A_write_address + 1; 
            end 
        end
    end

    always_comb begin
        if (A_write_address == (M*K)) begin 
            matrix_A_loaded = 1;
        end 
        else begin
            matrix_A_loaded = 0;
        end
    end

    // Logic for address counter for 'B'
    always_ff @(posedge clk) begin
        if((reset == 1) || (matrix_B_loaded == 1)) begin
            B_write_address <= 0;
        end
        else begin
            if (wr_en_B) begin
                B_write_address <= B_write_address + 1; 
            end 
        end
    end

    always_comb begin
        if (B_write_address == (K*N)) begin
            matrix_B_loaded = 1;
        end 
        else begin
            matrix_B_loaded = 0;
        end
    end

    // Determing which address to give to memory A
    always_comb begin
        if (matrices_loaded == 1) begin
            A_address = A_read_addr;
        end
        else begin
            A_address = A_write_address;
        end
    end

    // Determing which address to give to memory B
    always_comb begin
        if (matrices_loaded == 1) begin
            B_address = B_read_addr;
        end
        else begin
            B_address = B_write_address;
        end
    end

    //instantiating Memory A
    memory #(.WIDTH(INW),.SIZE(M*MAXK)) inst_memory_A ( 
        .data_in(AXIS_TDATA),
        .data_out(A_data_out),
        .addr(A_address),
        .clk(clk),
        .wr_en(wr_en_A)
    );
    
    //instantiating Memory B
    memory #(.WIDTH(INW),.SIZE(MAXK*N)) inst_memory_B ( 
        .data_in(AXIS_TDATA),
        .data_out(B_data_out),
        .addr(B_address),
        .clk(clk),
        .wr_en(wr_en_B)
    ); 

    // MUX logic for A_data_out
    always_comb begin
        if (matrices_loaded == 1) begin
            A_data = A_data_out;
        end 
        else begin
            A_data = 0;
        end
    end

    // MUX logic for B_data_out
    always_comb begin
        if (matrices_loaded == 1) begin
            B_data = B_data_out;
        end 
        else begin
            B_data = 0;
        end
    end

endmodule

// Memory logic
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