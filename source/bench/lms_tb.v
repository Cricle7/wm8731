`timescale   1ns / 1ps

module  lms_tb.v;
wire               clk      ; 
wire               rst_n    ;
reg signed  [15:0] mic_in   ; 
wire        [15:0] spk_out  ;
wire        [15:0] err_out  ;

// 定义时钟信号
reg clk;
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 时钟周期为10ns
end

// 引入包含数组数据的 Verilog 文件
`include "../../user/sim/input_waveforms_echo.v"
`include "../../user/sim/input_waveforms_no_echo.v"

// 义测试台信号
reg signed [15:0] test_signal_echo;
reg signed [15:0] test_signal_no_echo;
integer index;

// 时钟驱动测试台行为
always @(posedge clk) begin
    // 读取数组数据，每个时钟周期逐个取值
    if (index < 73113) begin
        test_signal_no_echo <= no_echo_input[index];
        test_signal_echo <= echo_input[index];
        index <= index + 1;
    end
end

// 在仿真结束时显示测试台信号的值
initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    // 等待仿真运行完毕
    #731120;
    $finish;
end
//// 将初始化数组作为输入信号
//always @(posedge clk) begin
    //audio_in <= echo_input;
//end

//// 实例化你的设计
//your_design uut (
    //.clk(clk),
    //.rst(rst),
    //.audio_in(audio_in),
    //.audio_out(audio_out)
//);

//// 在仿真中添加时钟
//initial begin
    //clk = 0;
    //forever #5 clk = ~clk;
//end



//Adaptive_filter u_Adaptive_filter(
//.clk      (clk), 
//.rst_n    (rst_n),
//.mic_in   (mic_in), 
//.spk_out  (spk_out),
//.err_out  (err_out)
//);



endmodule