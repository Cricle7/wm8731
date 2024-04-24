`timescale  1ns/1ns
module resample_tb;

localparam src_image_width  = 200000;
localparam src_image_height = 1;
localparam dst_image_width  = 300;
localparam dst_image_height = 1;
localparam x_ratio          = 109227;    //  floor(src_image_width/dst_image_width*2^16)
localparam y_ratio          = 65536;    //  floor(src_image_height/dst_image_height*2^16)

//----------------------------------------------------------------------
//  clk & rst_n

reg                             clk_in1;
reg                             clk_in2;
reg                             clk_in3;
reg                             clk_in4;
reg                             rst_n;

reg filter_en;


initial begin
    clk_in1 = 1'b0;
    forever #10870 clk_in1 = ~clk_in1;
end

initial begin
    clk_in2 = 1'b0;
    forever #10 clk_in2 = ~clk_in2;
end

initial begin
    clk_in3 = 1'b0;
    forever #5 clk_in3 = ~clk_in3;
end

initial begin
    clk_in4 = 1'b0;
    forever #2 clk_in4 = ~clk_in4;
end

initial begin
$fsdbDumpfile("adaptive.fsdb");
$fsdbDumpvars(0);
end

initial
begin
    rst_n = 1'b0;
    repeat(50) @(posedge clk_in1);
    rst_n = 1'b1;
end

reg [15:1] clk_cnt;
always @(posedge clk_in2) begin
    if(rst_n == 1'b0) begin
        clk_cnt <= 0;
        filter_en <= 0;
    end
    else if (clk_cnt == 1087) begin
        filter_en <= 1'b1;
        clk_cnt <= 0;
    end
    else begin
        clk_cnt <= clk_cnt + 1;
        filter_en <= 1'b0;
    end
end


//----------------------------------------------------------------------
//  Image data prepred to be processed
reg                             per_img_vsync;
reg                             per_img_href;
reg             [15:0]           per_img_gray;

//  Image data has been processed
wire                            post_img_vsync;
wire                            post_img_href;
wire            [15:0]           post_img_gray;

//----------------------------------------------------------------------
//  task and function
task image_input;
    bit             [31:0]      row_cnt;
    bit             [31:0]      col_cnt;
    bit             [15:0]       mem     [src_image_width*src_image_height-1:0];
    $readmemh("Xdata.dat",mem);
    
    @(posedge filter_en);
    per_img_vsync = 1'b1;
    for(row_cnt = 0;row_cnt < src_image_height;row_cnt++)
    begin
        repeat(0) @(posedge filter_en);
        for(col_cnt = 0;col_cnt < src_image_width;col_cnt++)
        begin
            per_img_href  = 1'b1;
            per_img_gray  = mem[row_cnt*src_image_width+col_cnt];
            @(posedge filter_en); 
        end
        per_img_href  = 1'b0;
    end
    repeat(0) @(posedge filter_en);
    per_img_vsync = 1'b0;
    @(posedge filter_en);
    
endtask : image_input

task desired_data;
    bit             [31:0]      row_cnt;
    bit             [31:0]      col_cnt;
    bit             [15:0]       mem     [src_image_width*src_image_height-1:0];
    $readmemh("Xdata.dat",mem); 
    @(posedge filter_en);
    per_img_vsync = 1'b1;
    for(row_cnt = 0;row_cnt < src_image_height;row_cnt++)
    begin
        repeat(0) @(posedge filter_en);
        for(col_cnt = 0;col_cnt < src_image_width;col_cnt++)
        begin
            per_img_href  = 1'b1;
            per_img_gray  = mem[row_cnt*src_image_width+col_cnt];
            @(posedge filter_en); 
        end
        per_img_href  = 1'b0;
    end
    repeat(0) @(posedge filter_en);
    per_img_vsync = 1'b0;
    @(posedge filter_en);
    
endtask : desired_data

reg                             post_img_vsync_r;

always @(posedge clk_in2)
begin
    if(rst_n == 1'b0)
        post_img_vsync_r <= 1'b0;
    else
        post_img_vsync_r <= post_img_vsync;
end

wire                            post_img_vsync_pos;
wire                            post_img_vsync_neg;

assign post_img_vsync_pos = ~post_img_vsync_r &  post_img_vsync;
assign post_img_vsync_neg =  post_img_vsync_r & ~post_img_vsync;

task image_result_check;
    bit                         frame_flag;
    bit         [31:0]          row_cnt;
    bit         [31:0]          col_cnt;
    bit         [ 7:0]          mem     [dst_image_width*dst_image_height-1:0];
    
    frame_flag = 0;
    $readmemh("../../../../1_Matlab_Project/7.2_Bilinear_Interpolation/img_Gray2.dat",mem);
    
    while(1)
    begin
        @(posedge clk_in2);
        if(post_img_vsync_pos == 1'b1)
        begin
            frame_flag = 1;
            row_cnt = 0;
            col_cnt = 0;
            $display("##############image result check begin##############");
        end
        
        if(frame_flag == 1'b1)
        begin
            if(post_img_href == 1'b1)
            begin
                if(post_img_gray != mem[row_cnt*dst_image_width+col_cnt])
                begin
                    $display("result error ---> row_num : %0d;col_num : %0d;pixel data : %h;reference data : %h",row_cnt+1,col_cnt+1,post_img_gray,mem[row_cnt*dst_image_width+col_cnt]);
                end
                col_cnt = col_cnt + 1;
            end
            
            if(col_cnt == dst_image_width)
            begin
                col_cnt = 0;
                row_cnt = row_cnt + 1;
            end
        end
        
        if(post_img_vsync_neg == 1'b1)
        begin
            frame_flag = 0;
            $display("##############image result check end##############");
        end
    end
endtask : image_result_check

//----------------------------------------------------------------------

wire   Yout_de;
wire   [15:0]   Yout_data;
wire   [15:0]   err_out;

GTP_GRS GRS_INST(
    .GRS_N(1'b1)
    ) ;

// 实例化Adaptive_filter模块
Adaptive_filter adapt_filter_inst (
    .clk(clk_in2),
    .rst(!rst_n),
    .filter_in(per_img_gray),
    .filter_en(filter_en),
    .desired_in(per_img_gray),
    .desired_en(filter_en),
    .filter_out(Yout_data)
);

//top 
//#(
//.C_SRC_IMG_WIDTH   (500    )     ,
//.C_SRC_IMG_HEIGHT  (1      )    ,
//.C_DST_IMG_WIDTH   (300    )    ,  
//.C_DST_IMG_HEIGHT  (1      )    ,
//.C_X_RATIO         (109227 )    ,        //  floor(C_SRC_IMG_WIDTH/C_DST_IMG_WIDTH*2^16)
//.Y_pos             (12'd500)    ,
//.X_pos             (12'd300)        //  Y_pos * F 
//) 
//top_inst
//(
    //.clk_50M          (clk_in1),
    //.clk_100M         (clk_in2),   
    //.clk_250M         (clk_in3),

    //.sys_rst_n        (rst_n),


    //.per_audio_dat    (per_img_gray),
    //.per_audio_dat_de (per_img_href),   
    
    //.Yout_de          (Yout_de     ),
    //.Yout_data        (Yout_data   )
//);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// wire   [15:0]    post_voc_data;
// wire   post_audio_de;
// wire   post_audio_vsync;
// wire   cal_flag;
// reg    Y_finish;

// sequential_source 
// #(
//     .CNT_MAX  (11'd502-11'd1)    //数据长度+2-1
// )
// sequential_source_inst
// (
// .per_audio_dat(per_img_gray),
// .per_audio_dat_de(per_img_href),
// .audio_bclk   (clk_in1),
// .sys_clk      (clk_in2),
// .sys_rst_n    (rst_n),


// .post_voc_data     (post_voc_data) ,
// .post_audio_de     (post_audio_de) ,
// .post_audio_vsync  (post_audio_vsync)          
// );


// resample_nearest_interpolation
// #(
//     .C_SRC_IMG_WIDTH (500),
//     .C_SRC_IMG_HEIGHT(1),
//     .C_DST_IMG_WIDTH (300),
//     .C_DST_IMG_HEIGHT(1),
//     .C_X_RATIO       (109227),        //  floor(C_SRC_IMG_WIDTH/C_DST_IMG_WIDTH*2^16)
//     .C_Y_RATIO       (65536)         //  floor(C_SRC_IMG_HEIGHT/C_DST_IMG_HEIGHT*2^16)
// )
// u_resample_nearest_interpolation
// (
//     .clk_in1        (clk_in2        ),
//     .clk_in2        (clk_in3        ),
//     .rst_n          (rst_n          ),
    
//     //  Image data prepared to be processed
//     .per_img_vsync  (post_audio_vsync  ),          //  Prepared Image data vsync valid signal
//     .per_img_href   (post_audio_de   ),          //  Prepared Image data href vaild  signal
//     .per_img_gray   (post_voc_data   ),          //  Prepared Image brightness input
    
//     //  Image data has been processed
//     .post_img_vsync (post_img_vsync ),          //  processed Image data vsync valid signal
//     .post_img_href  (post_img_href  ),          //  processed Image data href vaild  signal
//     .post_img_gray  (post_img_gray  )           //  processed Image brightness output
// );


// reg    [11:0]    cache_ram_rd_addr;
// reg    cache_ram_rd_en;
// wire    [11:0]    xpos;
// wire    cache_ram_data_de;
// wire    [15:0]   cache_ram_data;

// GTP_GRS GRS_INST(
//     .GRS_N(1'b1)
//     ) ;

// Cache Cache_inst(
// .clk_in2         (clk_in3)  ,
// .sys_clk         (clk_in4)  ,    
// .rst_n           (rst_n)  ,

// .Y_finish          (Y_finish)  ,
// .xpos              (xpos)  ,

// .rsp_de          (post_img_href)  ,
// .rsp_data        (post_img_gray)  ,

// .ram_rd_en       (cache_ram_rd_en)  ,
// .ram_rd_addr     (cache_ram_rd_addr)  ,

// .cal_flag        (cal_flag)  ,

// .data_de         (cache_ram_data_de)  , 
// .data_out        (cache_ram_data)    
// );


// reg    [11:0]    Km_complex ;
// reg              Yout_flag_complex;

// wire    [11:0]    Km_simple;
// wire              yout_flag_simple;
// wire              Find_km_flag;
// reg    tb_yold_rd_en;
// reg    [11:0]    tb_yold_rd_cnt;

// wov_ctrl 
// #(
// .Y_pos  (12'd500)     ,
// .X_pos  (12'd300)       //  Y_pos * F    
// )
// wov_ctrl_inst
// (
// .sys_clk                  (clk_in4)       ,    
// .sys_rst_n                (rst_n)       ,

// .cal_flag                 (cal_flag)       ,
// .Km_complex               (Km_complex)       ,
// .Yout_flag_complex        (Yout_flag_complex)       ,


// .xpos                     (xpos)       ,
// .yout_flag_simple         (yout_flag_simple)       ,
// .Km_simple                (Km_simple)       ,
// .Find_km_flag             (Find_km_flag)
// );


// Find_km  Find_km_inst(
// .sys_clk                       (clk_in4)     , //100M    
// .rst_n                         (rst_n)     ,

// .Find_km_flag                  (Find_km_flag)         , 

// .Yout_flag_complex             (Yout_flag_complex)              , //50M      
// .Km_complex                    (Km_complex)          
// );



// reg    Yout_de;
// reg    [15:0]  Yout_data;

// Yout_Cal Yout_Cal_inst(
// .sys_clk                      (clk_in4),    
// .rst_n                        (rst_n),


// .Ycal_Flag_simple             (yout_flag_simple),
// .Km_simple                    (Km_simple),
// .Ycal_flag_complex            (Yout_flag_complex),
// .Km_complex                   (Km_complex),


// .Yold_req_de                  (tb_yold_rd_en),
// .Yold_req_addr                (tb_yold_rd_cnt),
// .Yold_back_de                 (),
// .Yold_data                    (),

// .data_in_de                   (cache_ram_data_de), 
// .data_in                      (cache_ram_data ),

// .ycal_rd_de                   (cache_ram_rd_en),
// .ycal_rd_addr                 (cache_ram_rd_addr),
  
// .Yout_de                      (Yout_de),
// .Yout_data                    (Yout_data),
 
// .Yout_finish                  (Y_finish)
  
// );


// reg    [15:0]    Out_dat;

// buffer  buffer_inst(
// .sys_clk                     (clk_in4)       , //100M
// .sys_clk2                    (clk_in1)       , //50M      
// .rst_n                       (rst_n)       ,

// .Yout_de                     (Yout_de)       ,
// .Yout_data                   (Yout_data)      ,

// .Out_dat                     (Out_dat)   
// );


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////








// localparam MAX = 12'd15;

// always@(posedge clk_in4 or negedge rst_n)begin
//     if(~rst_n)
//         tb_yold_rd_cnt <= 12'd0;
//     else    if(Y_finish)
//         tb_yold_rd_cnt <= 12'd1;
//     else    if(tb_yold_rd_cnt > 12'd0)
//     begin
//         if(tb_yold_rd_cnt == MAX)
//             tb_yold_rd_cnt <= 12'd0;
//         else
//             tb_yold_rd_cnt <= tb_yold_rd_cnt + 12'b1;
//     end
//     else
//         tb_yold_rd_cnt <= 12'd0;
// end


// always @(posedge clk_in4)
// begin
//     if(rst_n == 1'b0)
//         tb_yold_rd_en <= 1'b0;    
//     else if( Y_finish == 1'b1)//haha
//         tb_yold_rd_en <= 1'b1;
//     else if((tb_yold_rd_en == 1'b1) && (tb_yold_rd_cnt <= 12'd15-12'd1))
//         tb_yold_rd_en <= 1'b1;                     
//     else
//         tb_yold_rd_en <= 1'b0;            
// end





// always @(posedge clk_in4)
// begin
//     if(cal_flag == 1'b1)
//         begin
//         repeat(100) @(posedge clk_in4);
//         Y_finish = 1'b1;        
//         end
//     else
//         Y_finish <= 1'b0;
// end





initial
begin
    per_img_vsync = 0;
    per_img_href  = 0;
    per_img_gray  = 0;
end

initial 
begin
    wait(rst_n);
    fork
        begin 
            repeat(5) @(posedge clk_in1); 
            image_input;
            image_input;
            image_input;
            image_input;  
            image_input;
            image_input;              
        end 
        // image_result_check;
    join
end 

endmodule