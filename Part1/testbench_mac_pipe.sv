`timescale  1ns/1ns

module testbench_mac_pipe();

    // For MAC unit's input signals. 
    logic signed [15:0] testInput0, testInput1;
    logic clk, reset, clear_acc, valid_input;

    // For MAC unit's output signal. 
    logic signed [47:0] testOutput;

    // Instantiate the device under test.
    mac_pipe mac_unit_inst(.in0(testInput0), .in1(testInput1), .out(testOutput), .clk(clk), .reset(reset), .clear_acc(clear_acc), .valid_input(valid_input));

    // Initialize the clock to zero.
    initial clk = 0;
    initial valid_input = 0;

    // Make the clock oscillate: every 5 time units, it changes its value.
    always #5 clk = ~clk;
    always #5 valid_input= ~valid_input;


    // Now, use an initial block to tell testbench what to do.
    initial begin

        clear_acc = 0;
        reset = 0;
        #5 reset = ~reset;
        #5 reset = ~reset;

        #2
        testInput0 = 2; 
        testInput1 = 4;
        
        #6
        testInput0 = 100;
        testInput1 = 20;

        #6
        testInput0 = 32;
        testInput1 = 16;

        #6
        testInput0 = 5;
        testInput1 = 10;

        #6
        testInput0 = 15;
        testInput1 = 25;

        #6
        testInput0 = 50;
        testInput1 = 30;

        #6
        testInput0 = 40;
        testInput1 = 55;

        #6
        testInput0 = 2;
        testInput1 = 3;

        $stop; // End simulation
    end

    endmodule