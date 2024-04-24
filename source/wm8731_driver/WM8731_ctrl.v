module WM8731_ctrl (
  input      clk,
  input      rst_n,

  input 	        DACLRC      ,
  input 	        BCLK        ,
  output 	        DACDAT      ,
  input           ADCLRC      ,                   
  input           ADCDAT      ,					      

  
  output   	      I2C_SCLK    ,
  inout 	        I2C_SDAT
    
);

wire        wav_out_data     ;
wire        wav_rden         ;
wire        play_en          ;
wire [15:0] wav_in_data      ;
wire        wav_wren         ;
wire        record_en        ;

//		input  [15:0]	wav_out_data,
		//output     	    wav_rden    ,
    //input           play_en     , 
        
        
		//output [15:0] 	wav_in_data ,
		//output 	        wav_wren    ,		
    //input           record_en   ,

//def lms(x, d, N = 4, mu = 0.1):
  //nIters = min(len(x),len(d)) - N
  //u = np.zeros(N)
  //w = np.zeros(N)
  //e = np.zeros(nIters)
  //for n in range(nIters):
    //u[1:] = u[:-1]
    //u[0] = x[n]
    //e_n = d[n] - np.dot(u, w)
    //w = w + mu * e_n * u
    //e[n] = e_n
  //return e


mywav u_my_wav(
  .clk50M(clk),
  .wav_out_data(wav_out_data),//input [15:0]
  .wav_rden(wav_rden),//output
  .play_en(play_en),//input
  .wav_in_data(wav_in_data),//output [15:0]
  .wav_wren(wav_wren),//output
  .record_en(record_en),//input

  .DACLRC(DACLRC),//input
  .BCLK(BCLK),//input
  .DACDAT(DACDAT),//output
  .ADCLRC(ADCLRC),//input
  .ADCDAT(ADCDAT),//input

  .I2C_SCLK(I2C_SCLK),//output
  .I2C_SDAT(I2C_SDAT)//inout
); 

Adaptive_filter u_adaptive_filter (
  .clk(clk), 
  .rst(!rst_n),
  .filter_in(wav_in_data), 
  .filter_en(wav_wren), 
  .desired_in(),
  .filter_out()
);


endmodule //WM8731_ctrl

