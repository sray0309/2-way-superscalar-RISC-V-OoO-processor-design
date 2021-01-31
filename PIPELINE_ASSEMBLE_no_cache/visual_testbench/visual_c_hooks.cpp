/////////////////////////////////////////////
//
// Last update by Liran Xiao, 09/2019
//
/////////////////////////////////////////////
#include "DirectC.h"
#include <curses.h>
#include <stdio.h>
#include <signal.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/signal.h>
#include <unistd.h> 
#include <fcntl.h> 
#include <time.h>
#include <string.h>

#include "riscv_inst.h"

#define PARENT_READ     readpipe[0]
#define CHILD_WRITE     readpipe[1]
#define CHILD_READ      writepipe[0]
#define PARENT_WRITE    writepipe[1]
#define NUM_HISTORY     8000
#define NUM_ROB         32
#define NUM_RAT         32
// #define NUM_FL          64
#define NUM_FL_BANK     32
#define NUM_STAGES      7
#define NOOP_INST       0x00000013
#define NUM_REG_GROUPS  4
// #define REG_SIZE_IN_HEX 8
#define REG_SIZE_IN_HEX 16
#define RAT_SIZE_IN_HEX 8

#define NUM_RS          8
#define RS_SIZE_IN_HEX  27

#define NUM_PRF         16
// #define NUM_PRF         65

#define ROB_SIZE_IN_HEX 49

#define NUM_CDB         2
#define CDB_SIZE_IN_HEX 13

#define NUM_LQ          8
#define NUM_SQ          8
#define LQ_SIZE_IN_HEX  16
#define SQ_SIZE_IN_HEX  22


#define NUM_LQB         8
#define NUM_RSB         8
#define LQB_SIZE_IN_HEX 21
#define RSB_SIZE_IN_HEX 18


// random variables/stuff
int fd[2], writepipe[2], readpipe[2];
int stdout_save;
int stdout_open;
void signal_handler_IO (int status);
int wait_flag=0;
char done_state;
char echo_data;
FILE *fp;
FILE *fp2;
int setup_registers = 0;
int stop_time;
int done_time = -1;
char time_wrapped = 0;

// Structs to hold information about each register/signal group
typedef struct win_info {
  int height;
  int width;
  int starty;
  int startx;
  int color;
} win_info_t;

typedef struct reg_group {
  WINDOW *reg_win;
  char ***reg_contents;
  char **reg_names;
  int num_regs;
  win_info_t reg_win_info;
} reg_group_t;

// Window pointers for ncurses windows
WINDOW *title_win;
WINDOW *comment_win;
WINDOW *time_win;
WINDOW *sim_time_win;
WINDOW *instr_win;
WINDOW *clock_win;
WINDOW *pipe1_win;
WINDOW *pipe2_win;
WINDOW *if_win;
WINDOW *if_id_win;
WINDOW *id_rn_win;
WINDOW *rn_dp_win;
WINDOW *is_ex_win;
WINDOW *ex_cm_win;
WINDOW *rob_win;
WINDOW *prf_win;
WINDOW *rs1_win;
WINDOW *rs2_win;
WINDOW *rat_win;
WINDOW *rrat_win;
WINDOW *flb1_win;
WINDOW *flb2_win;
WINDOW *cdb_win;
WINDOW *brpred_win;
WINDOW *lq_win;
WINDOW *sq_win;
WINDOW *lqb_win;
WINDOW *rsb_win;




// arrays for register contents and names
int history_num=0;
int num_if_regs = 0;
int num_if_id_regs = 0;
int num_id_rn_regs = 0;
int num_rn_dp_regs = 0;
int num_is_ex_regs = 0;
int num_ex_cm_regs = 0;
// int num_ex_regs = 0;
// int num_cm_regs = 0;

char readbuffer[4096];
char **timebuffer;
char **cycles;
char *clocks;
char *resets;
char **inst1_contents;
char **inst2_contents;

char ***if_contents;
char ***if_id_contents;
char ***id_rn_contents;
char ***rn_dp_contents;
char ***is_ex_contents;
char ***ex_cm_contents;
// char ***ex_contents;
// char ***cm_contents;
char **rob_contents;
char **prf_contents;
char **rs1_contents;
char **rs2_contents;
char **rat_contents;
char **rrat_contents;
char **fl_contents;
char **cdb_contents;
char **brpred_contents;
char **lq_contents;
char **sq_contents;
char **lqb_contents;
char **rsb_contents;

char **if_reg_names;
char **if_id_reg_names;
char **id_rn_reg_names;
char **rn_dp_reg_names;
char **is_ex_reg_names;
char **ex_cm_reg_names;
// char **dp_reg_names;
// char **dp_is_reg_names;
// char **ex_reg_names;
// char **cm_reg_names;

char *get_opcode_str(int inst, int valid_inst);
void parse_register(char* readbuf, int reg_num, char*** contents, char** reg_names);
int get_time();


// Helper function for ncurses gui setup
WINDOW *create_newwin(int height, int width, int starty, int startx, int color){
  WINDOW *local_win;
  local_win = newwin(height, width, starty, startx);
  wbkgd(local_win,COLOR_PAIR(color));
  wattron(local_win,COLOR_PAIR(color));
  box(local_win,0,0);
  wrefresh(local_win);
  return local_win;
}

// Function to draw positive edge or negative edge in clock window
void update_clock(char clock_val){
  static char cur_clock_val = 0;
  // Adding extra check on cycles because:
  //  - if the user, right at the beginning of the simulation, jumps to a new
  //    time right after a negative clock edge, the clock won't be drawn
  if((clock_val != cur_clock_val) || strncmp(cycles[history_num],"      0",7) == 1){
    mvwaddch(clock_win,3,7,ACS_VLINE | A_BOLD);
    if(clock_val == 1){

      //we have a posedgeqqq
      mvwaddch(clock_win,2,1,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,ACS_ULCORNER | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      mvwaddch(clock_win,4,1,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_LRCORNER | A_BOLD);
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
    } else {

      //we have a negedge
      mvwaddch(clock_win,4,1,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,ACS_LLCORNER | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      mvwaddch(clock_win,2,1,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_URCORNER | A_BOLD);
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
    }
  }
  cur_clock_val = clock_val;
  wrefresh(clock_win);
}

// Function to create and initialize the gui
// Color pairs are (foreground color, background color)
// If you don't like the dark backgrounds, a safe bet is to have
//   COLOR_BLUE/BLACK foreground and COLOR_WHITE background
void setup_gui(FILE *fp){
  initscr();
  if(has_colors()){
    start_color();
    init_pair(1,COLOR_CYAN,COLOR_BLACK);    // shell background
    init_pair(2,COLOR_YELLOW,COLOR_RED);
    init_pair(3,COLOR_RED,COLOR_BLACK);
    init_pair(4,COLOR_YELLOW,COLOR_BLUE);   // title window
    init_pair(5,COLOR_YELLOW,COLOR_BLACK);  // register/signal windows
    init_pair(6,COLOR_RED,COLOR_BLACK);
    init_pair(7,COLOR_MAGENTA,COLOR_BLACK); // pipeline window
    init_pair(8,COLOR_BLUE, COLOR_BLACK);
  }
  curs_set(0);
  noecho();
  cbreak();
  keypad(stdscr,TRUE);
  wbkgd(stdscr,COLOR_PAIR(1));
  wrefresh(stdscr);
  int pipe_width=0;

  rob_win = create_newwin(36,152,36,128,5);
//   rob_win = create_newwin(36,162,28,0,5);
  mvwprintw(rob_win,0,13,"ROB");
  int i=0;
  char tmp_buf[120];
  sprintf(tmp_buf, "         rob_idx | T_new | T_old | Inst | valid | br | H | T | ret_tag | h0rdy | h1rdy |     PC     |   ex_tPC   | ex_tbr |   pred_tPC   | p_tbr | m");
  mvwprintw(rob_win,1,1,tmp_buf);
  for (; i < NUM_ROB; i++) {
    sprintf(tmp_buf, "rob[%1d]: ", i);
    mvwprintw(rob_win,i+2,1,tmp_buf);

  }
  wrefresh(rob_win);


  //instantiate the title window at top of screen
  title_win = create_newwin(3,COLS,0,0,4);
  mvwprintw(title_win,1,1,"SIMULATION INTERFACE V1");
  wrefresh(title_win);

  //instantiate time window at right hand side of screen
  time_win = create_newwin(3,14,30,78,5);
//   time_win = create_newwin(3,20,25,80,5);
  mvwprintw(time_win,0,3,"TIME");
  wrefresh(time_win);

  //instantiate a sim time window which states the actual simlator time
  sim_time_win = create_newwin(3,14,33,78,5);
//   sim_time_win = create_newwin(4,20,28,80,5);
  mvwprintw(sim_time_win,0,1,"SIM TIME");
  wrefresh(sim_time_win);

  //instantiate a window to show which clock edge this is
  clock_win = create_newwin(6,18,30,60,5);
//   clock_win = create_newwin(7,30,25,100,5);
  mvwprintw(clock_win,0,5,"CLOCK");
  mvwprintw(clock_win,1,1,"cycle:");
  update_clock(0);
  wrefresh(clock_win);

  // //instantiate an instructional window to help out the user some
  // instr_win = create_newwin(7,32,60,94,5);
  // //   instr_win = create_newwin(7,30,13,300,5);
  // mvwprintw(instr_win,0,9,"INSTRUCTIONS");
  // wattron(instr_win,COLOR_PAIR(5));
  // mvwaddstr(instr_win,1,1,"'n'   -> Next clock edge");
  // mvwaddstr(instr_win,2,1,"'b'   -> Previous clock edge");
  // mvwaddstr(instr_win,3,1,"'c/g' -> Goto specified time");
  // mvwaddstr(instr_win,4,1,"'r'   -> Run to end of sim");
  // mvwaddstr(instr_win,5,1,"'q'   -> Quit Simulator");
  // wrefresh(instr_win);


  cdb_win = create_newwin(5,40,30,0,5);
//   cdb_win = create_newwin(5,40,40,0,5);
  mvwprintw(cdb_win,0,2,"CDB");
  sprintf(tmp_buf, "      tag | rob_idx |  value   | valid");
  mvwprintw(cdb_win,1,1,tmp_buf);
  for (i=0; i < NUM_CDB; i++) {
    sprintf(tmp_buf, "cdb%01x: ", i);
    mvwprintw(cdb_win,i+2,1,tmp_buf);
  }
  wrefresh(cdb_win);

  brpred_win = create_newwin(3,15,30,43,5);
//   brpred_win = create_newwin(3,15,40,43,5);
  mvwprintw(brpred_win,0,2,"GHT");
  sprintf(tmp_buf, "data: ");
  mvwprintw(brpred_win,1,1,tmp_buf);
  wrefresh(brpred_win);


  	// logic  cdb_valid;
	// logic [`PREG_IDX_WIDTH-1:0] cdb_tag;
	// logic [`ROB_IDX_WIDTH-1:0]  cdb_rob_idx;
	// logic [`XLEN-1:0]           cdb_value;

  // instantiate a window for the PRF on the right side
  prf_win = create_newwin(24,30,36,60,5);
  mvwprintw(prf_win,0,13,"DCache");
  for (i=0; i < NUM_PRF; i++) {
    sprintf(tmp_buf, "x%02x: ", i);
    int temp = i/4;
    mvwprintw(prf_win,i+2+temp,1,tmp_buf);
  }
  // for (i=32; i < NUM_PRF; i++) {
  //   sprintf(tmp_buf, "x%02x: ", i);
  //   mvwprintw(prf_win,i-30,16,tmp_buf);
  // }
  wrefresh(prf_win);

  // instantiate a window for the RAT on the left side
  rat_win = create_newwin(36,18,36,0,5);
//   rat_win = create_newwin(36,18,13,0,5);
  mvwprintw(rat_win,0,2,"Map");
  sprintf(tmp_buf, "      tag | rdy");
  mvwprintw(rat_win,1,1,tmp_buf);
  for (i=0; i < NUM_RAT; i++) {
    sprintf(tmp_buf, "x%02d: ", i);
    mvwprintw(rat_win,i+2,1,tmp_buf);
  }
  wrefresh(rat_win);

  // instantiate a window for the RRAT on the left side
  rrat_win = create_newwin(36,12,36,20,5);
//   rrat_win = create_newwin(36,12,13,20,5);
  mvwprintw(rrat_win,0,2,"Arch. Map");
  sprintf(tmp_buf, "      tag");
  mvwprintw(rrat_win,1,1,tmp_buf);
  for (i=0; i < NUM_RAT; i++) {
    sprintf(tmp_buf, "x%02d: ", i);
    mvwprintw(rrat_win,i+2,1,tmp_buf);
  }
  wrefresh(rrat_win);

  // instantiate a window for the Freelist bank1 on the left side
  flb1_win = create_newwin(36,24,36,34,5);
//   flb1_win = create_newwin(36,24,13,34,5);
  mvwprintw(flb1_win,0,2,"Freelist");
  sprintf(tmp_buf, "      T_idx | H | T");
  mvwprintw(flb1_win,1,1,tmp_buf);
  for (i=0; i < NUM_FL_BANK; i++) {
    sprintf(tmp_buf, "x%02d: ", i);
    mvwprintw(flb1_win,i+2,1,tmp_buf);
  }
  wrefresh(flb1_win);

  // // instantiate a window for the Freelist bank2 on the left side
  // flb2_win = create_newwin(36,24,36,54,5);
  // mvwprintw(flb2_win,0,2,"Freelist continue");
  // sprintf(tmp_buf, "      T_idx | H | T");
  // mvwprintw(flb2_win,1,1,tmp_buf);
  // for (i=NUM_FL_BANK; i < NUM_FL; i++) {
  //   sprintf(tmp_buf, "x%02d: ", i);
  //   mvwprintw(flb2_win,i+2-NUM_FL_BANK,1,tmp_buf);
  // }
  // wrefresh(flb2_win);

  // instantiate a window for the RS1 on the right side
  rs1_win = create_newwin(11,108,13,172,5);
//   rs1_win = create_newwin(12,80,13,200,5);
  mvwprintw(rs1_win,0,13,"RS1");
  sprintf(tmp_buf, "     Inst | busy | prega | pregb | pdest | ardy | brdy | ALU | LQidx | SQidx | LQrdy | SQrdy | MULT | BR");
  mvwprintw(rs1_win,1,1,tmp_buf);
  for (i=0; i < NUM_RS; i++) {
    sprintf(tmp_buf, "x%1d: ", i);
    mvwprintw(rs1_win,i+2,1,tmp_buf);
  }
  wrefresh(rs1_win);

  // instantiate a window for the RS2 on the right side
  rs2_win = create_newwin(11,108,24,172,5);
//   rs2_win = create_newwin(12,80,13,80,5);
  mvwprintw(rs2_win,0,13,"RS2");
  sprintf(tmp_buf, "     Inst | busy | prega | pregb | pdest | ardy | brdy | ALU | LQidx | SQidx | LQrdy | SQrdy | MULT | BR");
  mvwprintw(rs2_win,1,1,tmp_buf);
  for (i=0; i < NUM_RS; i++) {
    sprintf(tmp_buf, "x%1d: ", i);
    mvwprintw(rs2_win,i+2,1,tmp_buf);
  }
  wrefresh(rs2_win);


  // instantiate a window for the Load Queue on the right side
  lq_win = create_newwin(11,70,13,100,5);
  //   rs2_win = create_newwin(12,80,13,80,5);
  mvwprintw(lq_win,0,13,"Load Queue");
  sprintf(tmp_buf, "      addr   | valid | rob_idx | SQ_idx | head | tail | hit0 | hit1");
  mvwprintw(lq_win,1,1,tmp_buf);
  for (i=0; i < NUM_LQ; i++) {
    sprintf(tmp_buf, "x%1d: ", i);
    mvwprintw(lq_win,i+2,1,tmp_buf);
  }
  wrefresh(lq_win);

  // instantiate a window for the Store Queue on the right side
  sq_win = create_newwin(11,70,24,100,5);
  //   rs2_win = create_newwin(12,80,13,80,5);
  mvwprintw(sq_win,0,13,"Store Queue");
  sprintf(tmp_buf, "      addr   | valid |  value   | LQ_idx | head | tail | hit0 | hit1");
  mvwprintw(sq_win,1,1,tmp_buf);
  for (i=0; i < NUM_SQ; i++) {
    sprintf(tmp_buf, "x%1d: ", i);
    mvwprintw(sq_win,i+2,1,tmp_buf);
  }
  wrefresh(sq_win);


  lqb_win = create_newwin(11,58,60,60,5);
  mvwprintw(lqb_win,0,9,"Load Queue Buffer");
  sprintf(tmp_buf, "     value   | v | h | t |   addr   | rob_idx");
  mvwprintw(lqb_win,1,1,tmp_buf);
  for (i=0; i < NUM_LQB; i++) {
    sprintf(tmp_buf, "x%1d: ", i);
    mvwprintw(lqb_win,i+2,1,tmp_buf);
  }
  wrefresh(lqb_win);

  rsb_win = create_newwin(11,36,40,92,5);
  mvwprintw(rsb_win,0,9,"Retire Store Buffer");
  sprintf(tmp_buf, "     value   | v | ptr |   addr  ");
  mvwprintw(rsb_win,1,1,tmp_buf);
  for (i=0; i < NUM_RSB; i++) {
    sprintf(tmp_buf, "x%1d: ", i);
    mvwprintw(rsb_win,i+2,1,tmp_buf);
  }
  wrefresh(rsb_win);





//   // instantiate a window for the ROB on the right side
//   rob_win = create_newwin(34,25,14,COLS-25,5);
//   mvwprintw(rob_win,0,13,"ROB");
//   int i=0;
//   char tmp_buf[32];
//   for (; i < NUM_ROB; i++) {
//     sprintf(tmp_buf, "x%02d: ", i);
//     mvwprintw(rob_win,i+1,1,tmp_buf);
//   }
//   wrefresh(rob_win);

  //instantiate window to visualize instructions in pipeline below title
  pipe1_win = create_newwin(5,COLS,3,0,7);
  pipe_width = COLS/8;
  mvwprintw(pipe1_win,0,(COLS-8)/2,"PIPELINE");
  wattron(pipe1_win,A_UNDERLINE);
  mvwprintw(pipe1_win,1,1*pipe_width-2,"IF");
  mvwprintw(pipe1_win,1,2*pipe_width-2,"ID");
  mvwprintw(pipe1_win,1,3*pipe_width-2,"RN");
  mvwprintw(pipe1_win,1,4*pipe_width-2,"DP");
  mvwprintw(pipe1_win,1,5*pipe_width-2,"IS");
  mvwprintw(pipe1_win,1,6*pipe_width-2,"EX");
  mvwprintw(pipe1_win,1,7*pipe_width-2,"CM");
//   mvwprintw(pipe1_win,1,8*pipe_width-3,"RT");
  wattroff(pipe1_win,A_UNDERLINE);
  wrefresh(pipe1_win);

    //instantiate window to visualize instructions in pipeline below title
  pipe2_win = create_newwin(5,COLS,8,0,7);
  pipe_width = COLS/8;
  mvwprintw(pipe2_win,0,(COLS-8)/2,"PIPELINE");
  wattron(pipe2_win,A_UNDERLINE);
  mvwprintw(pipe2_win,1,1*pipe_width-2,"IF");
  mvwprintw(pipe2_win,1,2*pipe_width-2,"ID");
  mvwprintw(pipe2_win,1,3*pipe_width-2,"RN");
  mvwprintw(pipe2_win,1,4*pipe_width-2,"DP");
  mvwprintw(pipe2_win,1,5*pipe_width-2,"IS");
  mvwprintw(pipe2_win,1,6*pipe_width-2,"EX");
  mvwprintw(pipe2_win,1,7*pipe_width-3,"CM");
//   mvwprintw(pipe2_win,1,8*pipe_width-3,"RT");
  wattroff(pipe2_win,A_UNDERLINE);
  wrefresh(pipe2_win);

  //instantiate window to visualize IF stage (including IF/ID)
  if_win = create_newwin((num_if_regs+2),31,13,0,5);
//   if_win = create_newwin((num_if_regs+2),35,13,200,5);
  mvwprintw(if_win,0,10,"IF STAGE");
  wrefresh(if_win);

  //instantiate window to visualize IF/ID signals
  if_id_win = create_newwin((num_if_id_regs+2),31,13+(num_if_regs+2),0,5);
//   if_id_win = create_newwin((num_if_id_regs+2),35,13+(num_if_regs+2),200,5);
  mvwprintw(if_id_win,0,12,"IF/ID");
  wrefresh(if_id_win);

  //instantiate a window to visualize ID stage
  id_rn_win = create_newwin((num_id_rn_regs+2),31,13,31,5);
//   id_rn_win = create_newwin((num_id_rn_regs+2),35,13,235,5);
  mvwprintw(id_rn_win,0,10,"ID/RN");
  wrefresh(id_rn_win);

  //instantiate a window to visualize ID/EX signals
  rn_dp_win = create_newwin((num_rn_dp_regs+2),31,13+(num_id_rn_regs+2),31,5);
  //rn_dp_win = create_newwin((num_rn_dp_regs+2),35,13+(num_id_rn_regs+2),235,5);
  mvwprintw(rn_dp_win,0,12,"RN/DP");
  wrefresh(rn_dp_win);

  //instantiate a window to visualize IS/EX stage
  is_ex_win = create_newwin((num_is_ex_regs+2),31,13,62,5);
//   is_ex_win = create_newwin((num_is_ex_regs+2),35,13,270,5);
  mvwprintw(is_ex_win,0,10,"IS/EX");
  wrefresh(is_ex_win);

  //instantiate a window to visualize EX/CM
  ex_cm_win = create_newwin((num_ex_cm_regs+2),31,13+(num_is_ex_regs+2),62,5);
//   ex_cm_win = create_newwin((num_ex_cm_regs+2),35,13+(num_is_ex_regs+2),270,5);
  mvwprintw(ex_cm_win,0,12,"EX/CM");
  wrefresh(ex_cm_win);


  refresh();
}

// This function updates all of the signals being displayed with the values
// from time history_num_in (this is the index into all of the data arrays).
// If the value changed from what was previously display, the signal has its
// display color inverted to make it pop out.
void parsedata(int history_num_in){
  static int old_history_num_in=0;
  static int old_head_position=0;
  static int old_tail_position=0;
  int i=0;
  int data_counter=0;
  char *opcode;
  int tmp=0;
  int tmp_val=0;
  int bf=0;
  char tmp_buf[32];
  int pipe_width = COLS/8;
  int rs_op;

  // Handle updating resets
  if (resets[history_num_in]) {
    wattron(title_win,A_REVERSE);
    mvwprintw(title_win,1,(COLS/2)-3,"RESET");
    wattroff(title_win,A_REVERSE);
  }
  else if (done_time != 0 && (history_num_in == done_time)) {
    wattron(title_win,A_REVERSE);
    mvwprintw(title_win,1,(COLS/2)-3,"DONE ");
    wattroff(title_win,A_REVERSE);
  }
  else
    mvwprintw(title_win,1,(COLS/2)-3,"     ");
  wrefresh(title_win);

  // Handle updating the pipeline1 window
  for(i=0; i < NUM_STAGES; i++) {
    strncpy(tmp_buf,inst1_contents[history_num_in]+i*9,8);
    tmp_buf[9] = '\0';
    sscanf(tmp_buf,"%8x", &tmp_val);
    tmp = (int)inst1_contents[history_num_in][8+(i*9)] - (int)'0';
    opcode = get_opcode_str(tmp_val, tmp);

    // clear string and overwrite
    mvwprintw(pipe1_win,2,pipe_width*(i+1)-2-5,"          ");
    if (strncmp(tmp_buf,"xxxxxxxx",8) == 0)
      mvwaddnstr(pipe1_win,2,pipe_width*(i+1)-2-4,tmp_buf,8);
    else
      mvwaddstr(pipe1_win,2,pipe_width*(i+1)-2-(strlen(opcode)/2),opcode);
    if (tmp==0 || tmp==((int)'x'-(int)'0'))
      mvwprintw(pipe1_win,3,pipe_width*(i+1)-2,"I");
    else
      mvwprintw(pipe1_win,3,pipe_width*(i+1)-2,"V");
  }
  wrefresh(pipe1_win);

    // Handle updating the pipeline2 window
  for(i=0; i < NUM_STAGES; i++) {
    strncpy(tmp_buf,inst2_contents[history_num_in]+i*9,8);
    tmp_buf[9] = '\0';
    sscanf(tmp_buf,"%8x", &tmp_val);
    tmp = (int)inst2_contents[history_num_in][8+(i*9)] - (int)'0';
    opcode = get_opcode_str(tmp_val, tmp);

    // clear string and overwrite
    mvwprintw(pipe2_win,2,pipe_width*(i+1)-2-5,"          ");
    if (strncmp(tmp_buf,"xxxxxxxx",8) == 0)
      mvwaddnstr(pipe2_win,2,pipe_width*(i+1)-2-4,tmp_buf,8);
    else
      mvwaddstr(pipe2_win,2,pipe_width*(i+1)-2-(strlen(opcode)/2),opcode);
    if (tmp==0 || tmp==((int)'x'-(int)'0'))
      mvwprintw(pipe2_win,3,pipe_width*(i+1)-2,"I");
    else
      mvwprintw(pipe2_win,3,pipe_width*(i+1)-2,"V");

  }
  wrefresh(pipe2_win);


  int num_size = ROB_SIZE_IN_HEX;
  int opcode_size = 8;
  int mode = 0;
  int head_pos = 0;
  int tail_pos = 0;
  for (i=0; i < NUM_ROB; i++) {
    if (rob_contents[history_num_in][i*num_size+16] == '1')
      head_pos = i;

    if (rob_contents[history_num_in][i*num_size+17] == '1')
      tail_pos = i;
  }
  
  if (head_pos < tail_pos)
    mode = 1;
  else if (head_pos > tail_pos)
    mode = 2;
  else
    mode =  0;
  

  for (i=0; i < NUM_ROB; i++) {

    // if ((mode == 1 && i >= head_pos && i <= tail_pos) || ((mode == 2 && i >= head_pos) || (mode == 2 && i <= tail_pos)) || (mode == 0 && i == head_pos && history_num_in == 0)) { 

      // if (strncmp(rob_contents[history_num_in]+i*num_size,
      //             rob_contents[old_history_num_in]+i*num_size,num_size))
      //   wattron(rob_win, A_REVERSE);
      // else
      //   wattroff(rob_win, A_REVERSE);

      mvwaddnstr(rob_win,i+2,13,rob_contents[history_num_in]+i*num_size,2);
      mvwprintw(rob_win,i+2,18,"|");
      mvwaddnstr(rob_win,i+2,21,rob_contents[history_num_in]+i*num_size+2,2);
      mvwprintw(rob_win,i+2,26,"|");
      mvwaddnstr(rob_win,i+2,29,rob_contents[history_num_in]+i*num_size+4,2);
      mvwprintw(rob_win,i+2,34,"|");

      mvwprintw(rob_win,i+2,36,"          ");
      strncpy(tmp_buf,rob_contents[history_num_in]+i*num_size+6,8);
      tmp_buf[9] = '\0';
      sscanf(tmp_buf,"%8x", &tmp_val);
      tmp = (int)rob_contents[history_num_in][i*num_size+6+8] - (int)'0';
      opcode = get_opcode_str(tmp_val, tmp);
      mvwaddnstr(rob_win,i+2,36,opcode,opcode_size);

      mvwprintw(rob_win,i+2,41,"|");

      mvwaddnstr(rob_win,i+2,45,rob_contents[history_num_in]+i*num_size+14,1);
      mvwprintw(rob_win,i+2,49,"|");


      // if (rob_contents[history_num_in][i*num_size+15] == '1') {
      //     // mvwaddnstr(rob_win,i+2,51,rob_contents[history_num_in]+i*num_size+15,1);
      //     mvwprintw(rob_win,i+2,51,"1");
      //     mvwprintw(rob_win,i+2,54,"|");
      // } else {
      //     mvwprintw(rob_win,i+2,51," ");
      //     mvwprintw(rob_win,i+2,54,"|");
      // }

      mvwaddnstr(rob_win,i+2,51,rob_contents[history_num_in]+i*num_size+15,1);
      mvwprintw(rob_win,i+2,54,"|");

      if (rob_contents[history_num_in][i*num_size+16] == '1') {
          // mvwaddnstr(rob_win,i+2,56,rob_contents[history_num_in]+i*num_size+16,1);
          mvwprintw(rob_win,i+2,56,"1");
          mvwprintw(rob_win,i+2,58,"|");
      } else {
          mvwprintw(rob_win,i+2,56," ");
          mvwprintw(rob_win,i+2,58,"|");
      }

      if (rob_contents[history_num_in][i*num_size+17] == '1') {
          // mvwaddnstr(rob_win,i+2,60,rob_contents[history_num_in]+i*num_size+17,1);
          mvwprintw(rob_win,i+2,60,"1");
          mvwprintw(rob_win,i+2,62,"|");
      } else {
          mvwprintw(rob_win,i+2,60," ");
          mvwprintw(rob_win,i+2,62,"|");
      }

      mvwaddnstr(rob_win,i+2,67,rob_contents[history_num_in]+i*num_size+46,1);
      mvwprintw(rob_win,i+2,72,"|");

      if (i==0) {
          mvwaddnstr(rob_win,i+2,76,rob_contents[history_num_in]+i*num_size+18,1);
          mvwprintw(rob_win,i+2,80,"|");
          mvwaddnstr(rob_win,i+2,84,rob_contents[history_num_in]+i*num_size+19,1);
          mvwprintw(rob_win,i+2,88,"|");
      } else {
          mvwprintw(rob_win,i+2,80,"|");
          mvwprintw(rob_win,i+2,88,"|");
      }

      mvwaddnstr(rob_win,i+2,91,rob_contents[history_num_in]+i*num_size+20,8);
      mvwprintw(rob_win,i+2,101,"|");
      mvwaddnstr(rob_win,i+2,104,rob_contents[history_num_in]+i*num_size+28,8);
      mvwprintw(rob_win,i+2,114,"|");
      mvwaddnstr(rob_win,i+2,118,rob_contents[history_num_in]+i*num_size+36,1);

      mvwprintw(rob_win,i+2,123,"|");
      mvwaddnstr(rob_win,i+2,127,rob_contents[history_num_in]+i*num_size+37,8);
      mvwprintw(rob_win,i+2,138,"|");
      mvwaddnstr(rob_win,i+2,143,rob_contents[history_num_in]+i*num_size+45,1);
      mvwprintw(rob_win,i+2,146,"|");
      mvwaddnstr(rob_win,i+2,148,rob_contents[history_num_in]+i*num_size+47,1);



      // mvwprintw(rob_win,i+2,86,"|");
      // mvwaddnstr(rob_win,i+2,89,rob_contents[history_num_in]+i*num_size+20,1);
      // mvwprintw(rob_win,i+2,93,"|");
      // mvwaddnstr(rob_win,i+2,98,rob_contents[history_num_in]+i*num_size+21,1);
    // } else {
    //   mvwprintw(rob_win,i+2,13,"     |       |       |      |       |    |   |   |         |       |       |            |            |        |              |       |  ");
    // }

  }
  wrefresh(rob_win);


//   Handle updating the RS1 window
  num_size = RS_SIZE_IN_HEX;
  int inst_size = 8;
  int tag_size = 2;
  char ready_buf[32];
  for (i=0; i < NUM_RS; i++) {
    if (strncmp(rs1_contents[history_num_in]+i*num_size,
                rs1_contents[old_history_num_in]+i*num_size,num_size))
      wattron(rs1_win, A_REVERSE);
    else
      wattroff(rs1_win, A_REVERSE);
    
    mvwprintw(rs1_win,i+2,6,"          ");
    strncpy(tmp_buf,rs1_contents[history_num_in]+i*num_size,8);
    tmp_buf[9] = '\0';
    sscanf(tmp_buf,"%8x", &tmp_val);
    tmp = (int)rs1_contents[history_num_in][i*num_size+8] - (int)'0';
    opcode = get_opcode_str(tmp_val, tmp);
    mvwaddnstr(rs1_win,i+2,6,opcode,8);
    mvwprintw(rs1_win,i+2,11,"|");

    mvwaddnstr(rs1_win,i+2,14,rs1_contents[history_num_in]+i*num_size+8,1);
    mvwprintw(rs1_win,i+2,18,"|");

    
    bf = (int)rs1_contents[history_num_in][i*num_size+8] - (int)'0';

    if (bf == 0)
        mvwprintw(rs1_win,i+2,21,"--");
    else {
        strncpy(tmp_buf,rs1_contents[history_num_in]+i*num_size+9,2);
        tmp_buf[2] = '\0';
        mvwaddnstr(rs1_win,i+2,21,tmp_buf,2);
    }

    mvwprintw(rs1_win,i+2,26,"|");

    // strncpy(tmp_buf,rs1_contents[history_num_in]+i*num_size+9,2);
    // tmp_buf[2] = '\0';
    // rs_op = (int)rs1_contents[history_num_in][i*num_size+15] - (int)'0';
    // if (rs_op == 1)
    //     mvwaddnstr(rs1_win,i+2,21,tmp_buf,2);
    // else
    //     mvwprintw(rs1_win,i+2,21,"--");
    // mvwprintw(rs1_win,i+2,26,"|");


    if (bf == 0)
        mvwprintw(rs1_win,i+2,29,"--");
    else {
        strncpy(tmp_buf,rs1_contents[history_num_in]+i*num_size+11,2);
        tmp_buf[2] = '\0';
        rs_op = (int)rs1_contents[history_num_in][i*num_size+16] - (int)'0';
        mvwaddnstr(rs1_win,i+2,29,tmp_buf,2);
        // if (rs_op == 1)
        //     mvwaddnstr(rs1_win,i+2,29,tmp_buf,2);
        // else
        //     mvwprintw(rs1_win,i+2,29,"--");
    }
    mvwprintw(rs1_win,i+2,34,"|");


    // if (i==0) {
    //   mvwaddnstr(rs1_win,i+2,66,rs1_contents[history_num_in]+i*num_size+20,1);
    //   mvwaddnstr(rs1_win,i+2,82,rs1_contents[history_num_in]+i*num_size+22,1);
    // }

    if (bf == 0) {
        mvwprintw(rs1_win,i+2,37,"--");
        mvwprintw(rs1_win,i+2,45,"-");
        mvwprintw(rs1_win,i+2,52,"-");
        mvwprintw(rs1_win,i+2,59,"-");
        mvwprintw(rs1_win,i+2,66,"-");
        mvwprintw(rs1_win,i+2,74,"-");
        mvwprintw(rs1_win,i+2,82,"-");
        mvwprintw(rs1_win,i+2,90,"-");
        mvwprintw(rs1_win,i+2,97,"-");
        mvwprintw(rs1_win,i+2,103,"-");
    } else {
        mvwaddnstr(rs1_win,i+2,37,rs1_contents[history_num_in]+i*num_size+13,2);
        mvwaddnstr(rs1_win,i+2,45,rs1_contents[history_num_in]+i*num_size+17,1);
        mvwaddnstr(rs1_win,i+2,52,rs1_contents[history_num_in]+i*num_size+18,1);
        mvwaddnstr(rs1_win,i+2,59,rs1_contents[history_num_in]+i*num_size+19,1);
        mvwaddnstr(rs1_win,i+2,66,rs1_contents[history_num_in]+i*num_size+20,1);
        mvwaddnstr(rs1_win,i+2,74,rs1_contents[history_num_in]+i*num_size+22,1);
        mvwaddnstr(rs1_win,i+2,82,rs1_contents[history_num_in]+i*num_size+21,1);
        mvwaddnstr(rs1_win,i+2,90,rs1_contents[history_num_in]+i*num_size+23,1);
        mvwaddnstr(rs1_win,i+2,97,rs1_contents[history_num_in]+i*num_size+24,1);
        mvwaddnstr(rs1_win,i+2,103,rs1_contents[history_num_in]+i*num_size+25,1);
    }
    
    mvwprintw(rs1_win,i+2,42,"|");
    mvwprintw(rs1_win,i+2,49,"|");
    mvwprintw(rs1_win,i+2,56,"|");
    mvwprintw(rs1_win,i+2,62,"|");
    mvwprintw(rs1_win,i+2,70,"|");
    mvwprintw(rs1_win,i+2,78,"|");
    mvwprintw(rs1_win,i+2,86,"|");
    mvwprintw(rs1_win,i+2,94,"|");
    mvwprintw(rs1_win,i+2,101,"|");


  }
  wrefresh(rs1_win);

  //   Handle updating the RS2 window
  for (i=0; i < NUM_RS; i++) {
    if (strncmp(rs2_contents[history_num_in]+i*num_size,
                rs2_contents[old_history_num_in]+i*num_size,num_size))
      wattron(rs2_win, A_REVERSE);
    else
      wattroff(rs2_win, A_REVERSE);

    mvwprintw(rs2_win,i+2,6,"          ");
    strncpy(tmp_buf,rs2_contents[history_num_in]+i*num_size,8);
    tmp_buf[9] = '\0';
    sscanf(tmp_buf,"%8x", &tmp_val);
    tmp = (int)rs2_contents[history_num_in][i*num_size+8] - (int)'0';
    opcode = get_opcode_str(tmp_val, tmp);
    mvwaddnstr(rs2_win,i+2,6,opcode,8);
    mvwprintw(rs2_win,i+2,11,"|");


    mvwaddnstr(rs2_win,i+2,14,rs2_contents[history_num_in]+i*num_size+8,1);
    mvwprintw(rs2_win,i+2,18,"|");

    bf = (int)rs2_contents[history_num_in][i*num_size+8] - (int)'0';

    if (bf == 0) {
        mvwprintw(rs2_win,i+2,21,"--");
    } else {
        strncpy(tmp_buf,rs2_contents[history_num_in]+i*num_size+9,2);
        tmp_buf[2] = '\0';
        mvwaddnstr(rs2_win,i+2,21,tmp_buf,2);
    }
    mvwprintw(rs2_win,i+2,26,"|");

    // strncpy(tmp_buf,rs2_contents[history_num_in]+i*num_size+9,2);
    // tmp_buf[2] = '\0';
    // rs_op = (int)rs2_contents[history_num_in][i*num_size+15] - (int)'0';
    // if (rs_op == 1)
    //     mvwaddnstr(rs2_win,i+2,21,tmp_buf,2);
    // else
    //     mvwprintw(rs2_win,i+2,21,"--");
    // mvwprintw(rs2_win,i+2,26,"|");

    if (bf == 0) {
        mvwprintw(rs2_win,i+2,29,"--");
    } else {
        strncpy(tmp_buf,rs2_contents[history_num_in]+i*num_size+11,2);
        tmp_buf[2] = '\0';
        rs_op = (int)rs2_contents[history_num_in][i*num_size+16] - (int)'0';
        mvwaddnstr(rs2_win,i+2,29,tmp_buf,2);
        // if (rs_op == 1)
        //     mvwaddnstr(rs2_win,i+2,29,tmp_buf,2);
        // else
        //     mvwprintw(rs2_win,i+2,29,"--");
    }
    mvwprintw(rs2_win,i+2,34,"|");


    // if (i==0) {
    //   mvwaddnstr(rs2_win,i+2,66,rs2_contents[history_num_in]+i*num_size+20,1);
    //   mvwaddnstr(rs2_win,i+2,82,rs2_contents[history_num_in]+i*num_size+22,1);
    // }





    if (bf == 0) {
        mvwprintw(rs2_win,i+2,37,"--");
        mvwprintw(rs2_win,i+2,45,"-");
        mvwprintw(rs2_win,i+2,52,"-");

        mvwprintw(rs2_win,i+2,59,"-");
        mvwprintw(rs2_win,i+2,66,"-");
        mvwprintw(rs2_win,i+2,74,"-");
        mvwprintw(rs2_win,i+2,82,"-");
        mvwprintw(rs2_win,i+2,90,"-");
        mvwprintw(rs2_win,i+2,97,"-");
        mvwprintw(rs2_win,i+2,103,"-");

        // strncpy(tmp_buf,rs2_contents[history_num_in]+i*num_size+11,2);
        // tmp_buf[2] = '\0';
        // rs_op = (int)rs2_contents[history_num_in][i*num_size+16] - (int)'0';
        // if (rs_op == 1)
        //     mvwaddnstr(rs2_win,i+2,29,tmp_buf,2);
        // else
        //     mvwprintw(rs2_win,i+2,29,"--");


    } else {
        mvwaddnstr(rs2_win,i+2,37,rs2_contents[history_num_in]+i*num_size+13,2);
        mvwaddnstr(rs2_win,i+2,45,rs2_contents[history_num_in]+i*num_size+17,1);
        mvwaddnstr(rs2_win,i+2,52,rs2_contents[history_num_in]+i*num_size+18,1);

        mvwaddnstr(rs2_win,i+2,59,rs2_contents[history_num_in]+i*num_size+19,1);
        mvwaddnstr(rs2_win,i+2,66,rs2_contents[history_num_in]+i*num_size+20,1);
        mvwaddnstr(rs2_win,i+2,74,rs2_contents[history_num_in]+i*num_size+22,1);
        mvwaddnstr(rs2_win,i+2,82,rs2_contents[history_num_in]+i*num_size+21,1);
        mvwaddnstr(rs2_win,i+2,90,rs2_contents[history_num_in]+i*num_size+23,1);
        mvwaddnstr(rs2_win,i+2,97,rs2_contents[history_num_in]+i*num_size+24,1);
        mvwaddnstr(rs2_win,i+2,103,rs2_contents[history_num_in]+i*num_size+25,1);
    }
    
    mvwprintw(rs2_win,i+2,42,"|");
    mvwprintw(rs2_win,i+2,49,"|");
    mvwprintw(rs2_win,i+2,56,"|");
    mvwprintw(rs2_win,i+2,62,"|");
    mvwprintw(rs2_win,i+2,70,"|");
    mvwprintw(rs2_win,i+2,78,"|");
    mvwprintw(rs2_win,i+2,86,"|");
    mvwprintw(rs2_win,i+2,94,"|");
    mvwprintw(rs2_win,i+2,101,"|");
  }
  wrefresh(rs2_win);


  // Handle updating the PRF window
  num_size = REG_SIZE_IN_HEX;
  // for (i=0; i < 32; i++) {
  //   if (strncmp(prf_contents[history_num_in]+i*num_size,
  //               prf_contents[old_history_num_in]+i*num_size,num_size))
  //     wattron(prf_win, A_REVERSE);
  //   else
  //     wattroff(prf_win, A_REVERSE);
  //   mvwaddnstr(prf_win,i+2,6,prf_contents[history_num_in]+i*num_size,num_size);
  // }
  // for (i=32; i < NUM_PRF; i++) {
  //   if (strncmp(prf_contents[history_num_in]+i*num_size,
  //               prf_contents[old_history_num_in]+i*num_size,num_size))
  //     wattron(prf_win, A_REVERSE);
  //   else
  //     wattroff(prf_win, A_REVERSE);
  //   mvwaddnstr(prf_win,i-30,21,prf_contents[history_num_in]+i*num_size,num_size);
  // }

  for (i=0; i < 4; i++) {
    if (strncmp(prf_contents[history_num_in]+i*num_size,
                prf_contents[old_history_num_in]+i*num_size,num_size))
      wattron(prf_win, A_REVERSE);
    else
      wattroff(prf_win, A_REVERSE);

    for (int it=0; it<2; it++) {
      mvwaddnstr(prf_win,i+2,6+it*9,prf_contents[history_num_in]+i*num_size+it*8,8);
      // mvwprintw(prf_win,i+2,6+it*9-1,"        ");
    }
  }
  for (i=4; i < 8; i++) {
    if (strncmp(prf_contents[history_num_in]+i*num_size,
                prf_contents[old_history_num_in]+i*num_size,num_size))
      wattron(prf_win, A_REVERSE);
    else
      wattroff(prf_win, A_REVERSE);

    for (int it=0; it<2; it++) {
      mvwaddnstr(prf_win,i+3,6+it*9,prf_contents[history_num_in]+i*num_size+it*8,8);
      // mvwprintw(prf_win,i+2,6+it*9-1,"        ");
    }
  }
    for (i=8; i < 12; i++) {
    if (strncmp(prf_contents[history_num_in]+i*num_size,
                prf_contents[old_history_num_in]+i*num_size,num_size))
      wattron(prf_win, A_REVERSE);
    else
      wattroff(prf_win, A_REVERSE);

    for (int it=0; it<2; it++) {
      mvwaddnstr(prf_win,i+4,6+it*9,prf_contents[history_num_in]+i*num_size+it*8,8);
      // mvwprintw(prf_win,i+2,6+it*9-1,"        ");
    }
  }
    for (i=12; i < 16; i++) {
    if (strncmp(prf_contents[history_num_in]+i*num_size,
                prf_contents[old_history_num_in]+i*num_size,num_size))
      wattron(prf_win, A_REVERSE);
    else
      wattroff(prf_win, A_REVERSE);

    for (int it=0; it<2; it++) {
      mvwaddnstr(prf_win,i+5,6+it*9,prf_contents[history_num_in]+i*num_size+it*8,8);
      // mvwprintw(prf_win,i+2,6+it*9-1,"        ");
    }
  }
  wrefresh(prf_win);




  // Handle updating the LQB window
  num_size = LQB_SIZE_IN_HEX;
  for (i=0; i < NUM_LQB; i++) {
    if (strncmp(lqb_contents[history_num_in]+i*num_size,
                lqb_contents[old_history_num_in]+i*num_size,num_size))
      wattron(lqb_win, A_REVERSE);
    else
      wattroff(lqb_win, A_REVERSE);
    mvwaddnstr(lqb_win,i+2,5,lqb_contents[history_num_in]+i*num_size,8);
    mvwprintw(lqb_win,i+2,14,"|");
    mvwaddnstr(lqb_win,i+2,16,lqb_contents[history_num_in]+i*num_size+8,1);
    mvwprintw(lqb_win,i+2,18,"|");
    // mvwaddnstr(lqb_win,i+2,20,lqb_contents[history_num_in]+i*num_size+9,1);
    if (lqb_contents[history_num_in][i*num_size+9] == '1')
      mvwprintw(lqb_win,i+2,20,"1");
    else
       mvwprintw(lqb_win,i+2,20," ");
    mvwprintw(lqb_win,i+2,22,"|");
    // mvwaddnstr(lqb_win,i+2,24,lqb_contents[history_num_in]+i*num_size+10,1);
    if (lqb_contents[history_num_in][i*num_size+10] == '1')
      mvwprintw(lqb_win,i+2,24,"1");
    else
       mvwprintw(lqb_win,i+2,24," ");
    mvwprintw(lqb_win,i+2,26,"|");
    // mvwaddnstr(lqb_win,i+2,28,lqb_contents[history_num_in]+i*num_size+11,1);
    // if (lqb_contents[history_num_in][i*num_size+11] == '1')
    //   mvwprintw(lqb_win,i+2,28,"1");
    // else
    //    mvwprintw(lqb_win,i+2,28," ");
    // mvwprintw(lqb_win,i+2,30,"|");

    mvwprintw(lqb_win,i+2,28,"        ");
    mvwaddnstr(lqb_win,i+2,28,lqb_contents[history_num_in]+i*num_size+11,8);
    mvwprintw(lqb_win,i+2,37,"|");

    mvwprintw(lqb_win,i+2,41,"  ");
    mvwaddnstr(lqb_win,i+2,41,lqb_contents[history_num_in]+i*num_size+19,2);
   
  }
  wrefresh(lqb_win);

  // Handle updating the RSB window
  num_size = RSB_SIZE_IN_HEX;
  for (i=0; i < NUM_RSB; i++) {
    if (strncmp(rsb_contents[history_num_in]+i*num_size,
                rsb_contents[old_history_num_in]+i*num_size,num_size))
      wattron(rsb_win, A_REVERSE);
    else
      wattroff(rsb_win, A_REVERSE);
    mvwaddnstr(rsb_win,i+2,5,rsb_contents[history_num_in]+i*num_size,8);
    mvwprintw(rsb_win,i+2,14,"|");
    mvwaddnstr(rsb_win,i+2,16,rsb_contents[history_num_in]+i*num_size+8,1);
    mvwprintw(rsb_win,i+2,18,"|");
    
    if (i==0)
      mvwaddnstr(rsb_win,i+2,21,rsb_contents[history_num_in]+9,1);
    else
      mvwprintw(rsb_win,i+2,21," ");
      mvwprintw(rsb_win,i+2,24,"|");

    mvwaddnstr(rsb_win,i+2,26,rsb_contents[history_num_in]+i*num_size+10,8);
  
    
    // if (rsb_contents[history_num_in][i*num_size+9] == '1')
    //   mvwprintw(rsb_win,i+2,21,"1");
    // else
    //   mvwprintw(rsb_win,i+2,21," ");
  }
  wrefresh(rsb_win);



  // Handle updating the CDB window
  num_size = CDB_SIZE_IN_HEX;
  for (i=0; i < NUM_CDB; i++) {
    if (strncmp(cdb_contents[history_num_in]+i*num_size,
                cdb_contents[old_history_num_in]+i*num_size,num_size))
      wattron(cdb_win, A_REVERSE);
    else
      wattroff(cdb_win, A_REVERSE);
    mvwaddnstr(cdb_win,i+2,7,cdb_contents[history_num_in]+i*num_size,2);
    mvwprintw(cdb_win,i+2,11,"|");
    mvwaddnstr(cdb_win,i+2,15,cdb_contents[history_num_in]+i*num_size+2,2);
    mvwprintw(cdb_win,i+2,21,"|");
    mvwaddnstr(cdb_win,i+2,23,cdb_contents[history_num_in]+i*num_size+4,8);
    mvwprintw(cdb_win,i+2,32,"|");
    mvwaddnstr(cdb_win,i+2,36,cdb_contents[history_num_in]+i*num_size+12,1);
  }
  wrefresh(cdb_win);


  // Handle updating the LQ window
  num_size = LQ_SIZE_IN_HEX;
  for (i=0; i < NUM_LQ; i++) {
    if (strncmp(lq_contents[history_num_in]+i*num_size,
                lq_contents[old_history_num_in]+i*num_size,num_size))
      wattron(lq_win, A_REVERSE);
    else
      wattroff(lq_win, A_REVERSE);

    mvwaddnstr(lq_win,i+2,5,lq_contents[history_num_in]+i*num_size,8);
    mvwprintw(lq_win,i+2,14,"|");
    mvwaddnstr(lq_win,i+2,18,lq_contents[history_num_in]+i*num_size+8,1);
    mvwprintw(lq_win,i+2,22,"|");
    mvwaddnstr(lq_win,i+2,26,lq_contents[history_num_in]+i*num_size+9,2);
    mvwprintw(lq_win,i+2,32,"|");
    mvwaddnstr(lq_win,i+2,36,lq_contents[history_num_in]+i*num_size+11,1);
    mvwprintw(lq_win,i+2,41,"|");

    if (lq_contents[history_num_in][i*num_size+12] == '1') {
        mvwprintw(lq_win,i+2,44,"1");
    } else {
        mvwprintw(lq_win,i+2,44," ");
    }
    mvwprintw(lq_win,i+2,48,"|");

    if (lq_contents[history_num_in][i*num_size+13] == '1') {
        mvwprintw(lq_win,i+2,51,"1");
    } else {
        mvwprintw(lq_win,i+2,51," ");
    }
    mvwprintw(lq_win,i+2,55,"|");

    if (i==0) {
        mvwaddnstr(lq_win,i+2,58,lq_contents[history_num_in]+i*num_size+14,1);
    }
    mvwprintw(lq_win,i+2,62,"|");

    if (i==0) {
        mvwaddnstr(lq_win,i+2,65,lq_contents[history_num_in]+i*num_size+15,1);
    }

  }
  wrefresh(lq_win);


  // Handle updating the SQ window
  num_size = SQ_SIZE_IN_HEX;
  for (i=0; i < NUM_SQ; i++) {
    if (strncmp(sq_contents[history_num_in]+i*num_size,
                sq_contents[old_history_num_in]+i*num_size,num_size))
      wattron(sq_win, A_REVERSE);
    else
      wattroff(sq_win, A_REVERSE);
    mvwaddnstr(sq_win,i+2,5,sq_contents[history_num_in]+i*num_size,8);
    mvwprintw(sq_win,i+2,14,"|");
    mvwaddnstr(sq_win,i+2,18,sq_contents[history_num_in]+i*num_size+8,1);
    mvwprintw(sq_win,i+2,22,"|");
    mvwaddnstr(sq_win,i+2,24,sq_contents[history_num_in]+i*num_size+9,8);
    mvwprintw(sq_win,i+2,33,"|");
    mvwaddnstr(sq_win,i+2,37,sq_contents[history_num_in]+i*num_size+17,1);
    mvwprintw(sq_win,i+2,42,"|");

    if (sq_contents[history_num_in][i*num_size+18] == '1') {
        mvwprintw(sq_win,i+2,45,"1");
        mvwprintw(sq_win,i+2,49,"|");
    } else {
        mvwprintw(sq_win,i+2,45," ");
        mvwprintw(sq_win,i+2,49,"|");
    }

    if (sq_contents[history_num_in][i*num_size+19] == '1') {
        mvwprintw(sq_win,i+2,52,"1");
    } else {
        mvwprintw(sq_win,i+2,52," ");
    }
    mvwprintw(sq_win,i+2,56,"|");

    if (i==0) {
        mvwaddnstr(sq_win,i+2,59,sq_contents[history_num_in]+i*num_size+20,1);
    }
    mvwprintw(sq_win,i+2,63,"|");

    if (i==0) {
        mvwaddnstr(sq_win,i+2,66,sq_contents[history_num_in]+i*num_size+21,1);
    }

  }
  wrefresh(sq_win);



  //update the branch predictor window
  mvwaddnstr(brpred_win,1,7,brpred_contents[history_num_in], 5);
  wrefresh(brpred_win);



  // Handle updating the RAT window
  num_size = 3;
  for (i=0; i < NUM_RAT; i++) {
    if (strncmp(rat_contents[history_num_in]+i*num_size,
                rat_contents[old_history_num_in]+i*num_size,num_size))
      wattron(rat_win, A_REVERSE);
    else
      wattroff(rat_win, A_REVERSE);

    mvwaddnstr(rat_win,i+2,7,rat_contents[history_num_in]+i*num_size,2);
    mvwprintw(rat_win,i+2,11,"|");
    mvwaddnstr(rat_win,i+2,14,rat_contents[history_num_in]+i*num_size+2,1);
  }
  wrefresh(rat_win);


  // Handle updating the RRAT window
  num_size = 2;
  for (i=0; i < NUM_RAT; i++) {
    if (strncmp(rrat_contents[history_num_in]+i*num_size,
                rrat_contents[old_history_num_in]+i*num_size,num_size))
      wattron(rrat_win, A_REVERSE);
    else
      wattroff(rrat_win, A_REVERSE);
    mvwaddnstr(rrat_win,i+2,7,rrat_contents[history_num_in]+i*num_size,num_size);
  }
  wrefresh(rrat_win);


  // Handle updating the Freelist window
  num_size = 4;
  for (i=0; i < NUM_FL_BANK; i++) {
    if (strncmp(fl_contents[history_num_in]+i*num_size,
                fl_contents[old_history_num_in]+i*num_size,num_size))
      wattron(flb1_win, A_REVERSE);
    else
      wattroff(flb1_win, A_REVERSE);

    mvwaddnstr(flb1_win,i+2,8,fl_contents[history_num_in]+i*num_size,2);
    mvwprintw(flb1_win,i+2,13,"|");
    mvwaddnstr(flb1_win,i+2,15,fl_contents[history_num_in]+i*num_size+2,1);
    mvwprintw(flb1_win,i+2,17,"|");
    mvwaddnstr(flb1_win,i+2,19,fl_contents[history_num_in]+i*num_size+3,1);
  }
  wrefresh(flb1_win);

  // for (i=NUM_FL_BANK; i < NUM_FL; i++) {
  //   if (strncmp(fl_contents[history_num_in]+i*num_size,
  //               fl_contents[old_history_num_in]+i*num_size,num_size))
  //     wattron(flb2_win, A_REVERSE);
  //   else
  //     wattroff(flb2_win, A_REVERSE);

  //   mvwaddnstr(flb2_win,i+2-NUM_FL_BANK,8,fl_contents[history_num_in]+i*num_size,2);
  //   mvwprintw(flb2_win,i+2-NUM_FL_BANK,13,"|");
  //   mvwaddnstr(flb2_win,i+2-NUM_FL_BANK,15,fl_contents[history_num_in]+i*num_size+2,1);
  //   mvwprintw(flb2_win,i+2-NUM_FL_BANK,17,"|");
  //   mvwaddnstr(flb2_win,i+2-NUM_FL_BANK,19,fl_contents[history_num_in]+i*num_size+3,1);
  // }
  // wrefresh(flb2_win);



  // Handle updating the IF window
  for(i=0;i<num_if_regs;i++){
    if (strcmp(if_contents[history_num_in][i],
                if_contents[old_history_num_in][i]))
      wattron(if_win, A_REVERSE);
    else
      wattroff(if_win, A_REVERSE);
    mvwprintw(if_win,i+1,strlen(if_reg_names[i])+3,"     ");
    mvwaddstr(if_win,i+1,strlen(if_reg_names[i])+3,if_contents[history_num_in][i]);
  }
  wrefresh(if_win);

  // Handle updating the IF/ID window
  for(i=0;i<num_if_id_regs;i++){
    if (strcmp(if_id_contents[history_num_in][i],
                if_id_contents[old_history_num_in][i]))
      wattron(if_id_win, A_REVERSE);
    else
      wattroff(if_id_win, A_REVERSE);
    mvwaddstr(if_id_win,i+1,strlen(if_id_reg_names[i])+3,if_id_contents[history_num_in][i]);
  }
  wrefresh(if_id_win);

  // Handle updating the ID/RN window
  for(i=0;i<num_id_rn_regs;i++){
    if (strcmp(id_rn_contents[history_num_in][i],
                id_rn_contents[old_history_num_in][i]))
      wattron(id_rn_win, A_REVERSE);
    else
      wattroff(id_rn_win, A_REVERSE);
    mvwaddstr(id_rn_win,i+1,strlen(id_rn_reg_names[i])+3,id_rn_contents[history_num_in][i]);
  }
  wrefresh(id_rn_win);

  // Handle updating the RN/DP window
  for(i=0;i<num_rn_dp_regs;i++){
    if (strcmp(rn_dp_contents[history_num_in][i],
                rn_dp_contents[old_history_num_in][i]))
      wattron(rn_dp_win, A_REVERSE);
    else
      wattroff(rn_dp_win, A_REVERSE);
    mvwaddstr(rn_dp_win,i+1,strlen(rn_dp_reg_names[i])+3,rn_dp_contents[history_num_in][i]);
  }
  wrefresh(rn_dp_win);

  // Handle updating the IS/EX window
  for(i=0;i<num_is_ex_regs;i++){
    if (strcmp(is_ex_contents[history_num_in][i],
                is_ex_contents[old_history_num_in][i]))
      wattron(is_ex_win, A_REVERSE);
    else
      wattroff(is_ex_win, A_REVERSE);
    mvwaddstr(is_ex_win,i+1,strlen(is_ex_reg_names[i])+3,is_ex_contents[history_num_in][i]);
  }
  wrefresh(is_ex_win);

  // Handle updating the EX/CM window
  for(i=0;i<num_ex_cm_regs;i++){
    if (strcmp(ex_cm_contents[history_num_in][i],
                ex_cm_contents[old_history_num_in][i]))
      wattron(ex_cm_win, A_REVERSE);
    else
      wattroff(ex_cm_win, A_REVERSE);
    mvwaddstr(ex_cm_win,i+1,strlen(ex_cm_reg_names[i])+3,ex_cm_contents[history_num_in][i]);
  }
  wrefresh(ex_cm_win);

  //update the time window
  mvwaddstr(time_win,1,1,timebuffer[history_num_in]);
  wrefresh(time_win);

  //update to the correct clock edge for this history
  mvwaddstr(clock_win,1,7,cycles[history_num_in]);
  update_clock(clocks[history_num_in]);

  //save the old history index to check for changes later
  old_history_num_in = history_num_in;
}

// Parse a line of data output from the testbench
int processinput(){
  static int byte_num = 0;
  static int if_reg_num = 0;
  static int if_id_reg_num = 0;
  static int id_reg_num = 0;
  static int id_rn_reg_num = 0;
  static int rn_reg_num = 0;
  static int rn_dp_reg_num = 0;
  static int is_ex_reg_num = 0;
  static int ex_cm_reg_num = 0;
  int tmp_len;
  char name_buf[32];
  char val_buf[32];

  //get rid of newline character
  readbuffer[strlen(readbuffer)-1] = 0;

  if(strncmp(readbuffer,"t",1) == 0){

    //We are getting the timestamp
    strcpy(timebuffer[history_num],readbuffer+1);
  }else if(strncmp(readbuffer,"c",1) == 0){

    //We have a clock edge/cycle count signal
    if(strncmp(readbuffer+1,"0",1) == 0)
      clocks[history_num] = 0;
    else
      clocks[history_num] = 1;

    // grab clock count (for some reason, first clock count sent is
    // too many digits, so check for this)
    strncpy(cycles[history_num],readbuffer+2,7);
    if (strncmp(cycles[history_num],"       ",7) == 0)
      cycles[history_num][6] = '0';
    
  }else if(strncmp(readbuffer,"z",1) == 0){
    
    // we have a reset signal
    if(strncmp(readbuffer+1,"0",1) == 0)
      resets[history_num] = 0;
    else
      resets[history_num] = 1;

  }else if(strncmp(readbuffer,"w",1) == 0){
    // We are getting CDB contents
    strcpy(cdb_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"o",1) == 0){
    // We are getting branch predictor contents
    strcpy(brpred_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"a",1) == 0){
    // We are getting ROB registers
    strcpy(rob_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"y",1) == 0){
    // We are getting RAT registers
    strcpy(rat_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"u",1) == 0){
    // We are getting RRAT registers
    strcpy(rrat_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"v",1) == 0){
    // We are getting Freelist registers
    strcpy(fl_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"1",1) == 0){
    // We are getting Load Queue Buffer registers
    strcpy(lqb_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"2",1) == 0){
    // We are getting Retire Store Buffer registers
    strcpy(rsb_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"h",1) == 0){
    // We are getting Load Queue registers
    strcpy(lq_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"j",1) == 0){
    // We are getting Store Queue registers
    strcpy(sq_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"s",1) == 0){
    // We are getting RS1 registers
    strcpy(rs1_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"x",1) == 0){
    // We are getting RS2 registers
    strcpy(rs2_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"p",1) == 0){
    // We are getting information about which instructions are in each stage
    strcpy(inst1_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"l",1) == 0){
    // We are getting information about which instructions are in each stage
    strcpy(inst2_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"f",1) == 0){
    // We are getting an IF register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, if_reg_num, if_contents, if_reg_names);
      mvwaddstr(if_win,if_reg_num+1,1,if_reg_names[if_reg_num]);
      waddstr(if_win, ": ");
      wrefresh(if_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(if_contents[history_num][if_reg_num],val_buf);
    }

    if_reg_num++;
  }else if(strncmp(readbuffer,"g",1) == 0){
    // We are getting an IF/ID register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, if_id_reg_num, if_id_contents, if_id_reg_names);
      mvwaddstr(if_id_win,if_id_reg_num+1,1,if_id_reg_names[if_id_reg_num]);
      waddstr(if_id_win, ": ");
      wrefresh(if_id_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(if_id_contents[history_num][if_id_reg_num],val_buf);
    }

    if_id_reg_num++;
  }else if(strncmp(readbuffer,"d",1) == 0){
    // We are getting an ID/RN register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, id_rn_reg_num, id_rn_contents, id_rn_reg_names);
      mvwaddstr(id_rn_win,id_rn_reg_num+1,1,id_rn_reg_names[id_rn_reg_num]);
      waddstr(id_rn_win, ": ");
      wrefresh(id_rn_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(id_rn_contents[history_num][id_rn_reg_num],val_buf);
    }

    id_rn_reg_num++;
  }else if(strncmp(readbuffer,"e",1) == 0){
    // We are getting an RN/DP register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, rn_dp_reg_num, rn_dp_contents, rn_dp_reg_names);
      mvwaddstr(rn_dp_win,rn_dp_reg_num+1,1,rn_dp_reg_names[rn_dp_reg_num]);
      waddstr(rn_dp_win, ": ");
      wrefresh(rn_dp_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(rn_dp_contents[history_num][rn_dp_reg_num],val_buf);
    }

    rn_dp_reg_num++;
  }else if(strncmp(readbuffer,"i",1) == 0){
    // We are getting an IS/EX register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, is_ex_reg_num, is_ex_contents, is_ex_reg_names);
      mvwaddstr(is_ex_win,is_ex_reg_num+1,1,is_ex_reg_names[is_ex_reg_num]);
      waddstr(is_ex_win, ": ");
      wrefresh(is_ex_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(is_ex_contents[history_num][is_ex_reg_num],val_buf);
    }

    is_ex_reg_num++;
  }else if(strncmp(readbuffer,"m",1) == 0){
    // We are getting a EX/CM register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, ex_cm_reg_num, ex_cm_contents, ex_cm_reg_names);
      mvwaddstr(ex_cm_win,ex_cm_reg_num+1,1,ex_cm_reg_names[ex_cm_reg_num]);
      waddstr(ex_cm_win, ": ");
      wrefresh(ex_cm_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(ex_cm_contents[history_num][ex_cm_reg_num],val_buf);
    }

    ex_cm_reg_num++;
  }else if(strncmp(readbuffer,"r",1) == 0){
    // We are getting ARF registers
    strcpy(prf_contents[history_num], readbuffer+1);

  }else if (strncmp(readbuffer,"break",4) == 0) {
    // If this is the first time through, indicate that we've setup all of
    // the register arrays.
    setup_registers = 1;

    //we've received our last data segment, now go process it
    byte_num = 0;
    if_reg_num = 0;
    if_id_reg_num = 0;
    id_reg_num = 0;
    id_rn_reg_num = 0;
    rn_reg_num = 0;
    rn_dp_reg_num = 0;
    is_ex_reg_num = 0;
    ex_cm_reg_num = 0;

    //update the simulator time, this won't change with 'b's
    mvwaddstr(sim_time_win,1,1,timebuffer[history_num]);
    wrefresh(sim_time_win);

    //tell the parent application we're ready to move on
    return(1); 
  }
  return(0);
}

  static int if_regs = 0;
  static int if_id_regs = 0;
  static int id_regs = 0;
  static int id_rn_regs = 0;
  static int rn_regs = 0;
  static int rn_dp_regs = 0;
  static int is_ex_regs = 0;
  static int ex_cm_regs = 0;

//this initializes a ncurses window and sets up the arrays for exchanging reg information
extern "C" void initcurses(int if_regs, int if_id_regs, int id_rn_regs,
                int rn_dp_regs, int is_ex_regs, int ex_cm_regs){
  int nbytes;
  int ready_val;

  done_state = 0;
  echo_data = 1;
  num_if_regs = if_regs;
  num_if_id_regs = if_id_regs;
  num_id_rn_regs = id_rn_regs;
  num_rn_dp_regs = rn_dp_regs;
  num_is_ex_regs = is_ex_regs;
  num_ex_cm_regs = ex_cm_regs;
  pid_t childpid;
  pipe(readpipe);
  pipe(writepipe);
  stdout_save = dup(1);
  childpid = fork();
  if(childpid == 0){
    close(PARENT_WRITE);
    close(PARENT_READ);
    fp = fdopen(CHILD_READ, "r");
    fp2 = fopen("program.out","w");

    //allocate room on the heap for the reg data
    inst1_contents    = (char**) malloc(NUM_HISTORY*sizeof(char*));
    inst2_contents    = (char**) malloc(NUM_HISTORY*sizeof(char*));
    rob_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    rs1_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    rs2_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    prf_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    rat_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    rrat_contents     = (char**) malloc(NUM_HISTORY*sizeof(char*));
    fl_contents       = (char**) malloc(NUM_HISTORY*sizeof(char*));
    cdb_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    brpred_contents   = (char**) malloc(NUM_HISTORY*sizeof(char*));
    lq_contents       = (char**) malloc(NUM_HISTORY*sizeof(char*));
    sq_contents       = (char**) malloc(NUM_HISTORY*sizeof(char*));
    lqb_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    rsb_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    int i=0;
    if_contents       = (char***) malloc(NUM_HISTORY*sizeof(char**));
    if_id_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    id_rn_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    rn_dp_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    is_ex_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    ex_cm_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    timebuffer        = (char**) malloc(NUM_HISTORY*sizeof(char*));
    cycles            = (char**) malloc(NUM_HISTORY*sizeof(char*));
    clocks            = (char*) malloc(NUM_HISTORY*sizeof(char));
    resets            = (char*) malloc(NUM_HISTORY*sizeof(char));


    // allocate room for the register names (what is displayed)
    if_reg_names      = (char**) malloc(num_if_regs*sizeof(char*));
    if_id_reg_names   = (char**) malloc(num_if_id_regs*sizeof(char*));
    id_rn_reg_names   = (char**) malloc(num_id_rn_regs*sizeof(char*));
    rn_dp_reg_names   = (char**) malloc(num_rn_dp_regs*sizeof(char*));
    is_ex_reg_names   = (char**) malloc(num_is_ex_regs*sizeof(char*));
    ex_cm_reg_names   = (char**) malloc(num_ex_cm_regs*sizeof(char*));

    int j=0;
    for(;i<NUM_HISTORY;i++){
      timebuffer[i]       = (char*) malloc(8);
      cycles[i]           = (char*) malloc(7);
      brpred_contents[i]  = (char*) malloc(8);
      rob_contents[i]     = (char*) malloc(NUM_ROB*(ROB_SIZE_IN_HEX+4));
      rs1_contents[i]     = (char*) malloc(NUM_RS*(RS_SIZE_IN_HEX+4));
      rs2_contents[i]     = (char*) malloc(NUM_RS*(RS_SIZE_IN_HEX+4));
      prf_contents[i]     = (char*) malloc(NUM_PRF*20);
      cdb_contents[i]     = (char*) malloc(NUM_CDB*(CDB_SIZE_IN_HEX+4));
      inst1_contents[i]   = (char*) malloc(NUM_STAGES*10);
      inst2_contents[i]   = (char*) malloc(NUM_STAGES*10);
      rat_contents[i]     = (char*) malloc(NUM_RAT*10);
      rrat_contents[i]    = (char*) malloc(NUM_RAT*10);
      fl_contents[i]      = (char*) malloc(NUM_FL_BANK*10);
      lq_contents[i]      = (char*) malloc(NUM_LQ*(LQ_SIZE_IN_HEX+4));
      sq_contents[i]      = (char*) malloc(NUM_SQ*(SQ_SIZE_IN_HEX+4));
      lqb_contents[i]     = (char*) malloc(NUM_LQB*(LQB_SIZE_IN_HEX+4));
      rsb_contents[i]     = (char*) malloc(NUM_RSB*(RSB_SIZE_IN_HEX+4));
      if_contents[i]      = (char**) malloc(num_if_regs*sizeof(char*));
      if_id_contents[i]   = (char**) malloc(num_if_id_regs*sizeof(char*));
      id_rn_contents[i]   = (char**) malloc(num_id_rn_regs*sizeof(char*));
      rn_dp_contents[i]   = (char**) malloc(num_rn_dp_regs*sizeof(char*));
      is_ex_contents[i]   = (char**) malloc(num_is_ex_regs*sizeof(char*));
      ex_cm_contents[i]   = (char**) malloc(num_ex_cm_regs*sizeof(char*));
    }
    setup_gui(fp);

    // Main loop for retrieving data and taking commands from user
    char quit_flag = 0;
    char resp=0;
    char running=0;
    int mem_addr=0;
    char goto_flag = 0;
    char cycle_flag = 0;
    char done_received = 0;
    memset(readbuffer,'\0',sizeof(readbuffer));
    while(!quit_flag){
      if (!done_received) {
        fgets(readbuffer, sizeof(readbuffer), fp);
        ready_val = processinput();
      }
      if(strcmp(readbuffer,"DONE") == 0) {
        done_received = 1;
        done_time = history_num - 1;
      }
      if(ready_val == 1 || done_received == 1){
        if(echo_data == 0 && done_received == 1) {
          running = 0;
          timeout(-1);
          echo_data = 1;
          history_num--;
          history_num%=NUM_HISTORY;
        }
        if(echo_data != 0){
          parsedata(history_num);
        }
        history_num++;
        // keep track of whether time wrapped around yet
        if (history_num == NUM_HISTORY)
          time_wrapped = 1;
        history_num%=NUM_HISTORY;

        //we're done reading the reg values for this iteration
        if (done_received != 1) {
          write(CHILD_WRITE, "n", 1);
          write(CHILD_WRITE, &mem_addr, 2);
        }
        char continue_flag = 0;
        int hist_num_temp = (history_num-1)%NUM_HISTORY;
        if (history_num==0) hist_num_temp = NUM_HISTORY-1;
        char echo_data_tmp,continue_flag_tmp;

        while(continue_flag == 0){
          resp=getch();
          if(running == 1){
            continue_flag = 1;
          }
          if(running == 0 || resp == 'p'){ 
            if(resp == 'n' && hist_num_temp == (history_num-1)%NUM_HISTORY){
              if (!done_received)
                continue_flag = 1;
            }else if(resp == 'n'){
              //forward in time, but not up to present yet
              hist_num_temp++;
              hist_num_temp%=NUM_HISTORY;
              parsedata(hist_num_temp);
            }else if(resp == 'r'){
              echo_data = 0;
              running = 1;
              timeout(0);
              continue_flag = 1;
            }else if(resp == 'p'){
              echo_data = 1;
              timeout(-1);
              running = 0;
              parsedata(hist_num_temp);
            }else if(resp == 'q'){
              //quit
              continue_flag = 1;
              quit_flag = 1;
            }else if(resp == 'b'){
              //We're goin BACK IN TIME, woohoo!
              // Make sure not to wrap around to NUM_HISTORY-1 if we don't have valid
              // data there (time_wrapped set to 1 when we wrap around to history 0)
              if (hist_num_temp > 0) {
                hist_num_temp--;
                parsedata(hist_num_temp);
              } else if (time_wrapped == 1) {
                hist_num_temp = NUM_HISTORY-1;
                parsedata(hist_num_temp);
              }
            }else if(resp == 'g' || resp == 'c'){
              // See if user wants to jump to clock cycle instead of sim time
              cycle_flag = (resp == 'c');

              // go to specified simulation time (either in history or
              // forward in simulation time).
              stop_time = get_time();
              
              // see if we already have that time in history
              int tmp_time;
              int cur_time;
              int delta;
              if (cycle_flag)
                sscanf(cycles[hist_num_temp], "%u", &cur_time);
              else
                sscanf(timebuffer[hist_num_temp], "%u", &cur_time);
              delta = (stop_time > cur_time) ? 1 : -1;
              if ((hist_num_temp+delta)%NUM_HISTORY != history_num) {
                tmp_time=hist_num_temp;
                i= (hist_num_temp+delta >= 0) ? (hist_num_temp+delta)%NUM_HISTORY : NUM_HISTORY-1;
                while (i!=history_num) {
                  if (cycle_flag)
                    sscanf(cycles[i], "%u", &cur_time);
                  else
                    sscanf(timebuffer[i], "%u", &cur_time);
                  if ((delta == 1 && cur_time >= stop_time) ||
                      (delta == -1 && cur_time <= stop_time)) {
                    hist_num_temp = i;
                    parsedata(hist_num_temp);
                    stop_time = 0;
                    break;
                  }

                  if ((i+delta) >=0)
                    i = (i+delta)%NUM_HISTORY;
                  else {
                    if (time_wrapped == 1)
                      i = NUM_HISTORY - 1;
                    else {
                      parsedata(hist_num_temp);
                      stop_time = 0;
                      break;
                    }
                  }
                }
              }

              // If we looked backwards in history and didn't find stop_time
              // then give up
              if (i==history_num && (delta == -1 || done_received == 1))
                stop_time = 0;

              // Set flags so that we run forward in the simulation until
              // it either ends, or we hit the desired time
              if (stop_time > 0) {
                // grab current values
                echo_data = 0;
                running = 1;
                timeout(0);
                continue_flag = 1;
                goto_flag = 1;
              }
            }
          }
        }
        // if we're instructed to goto specific time, see if we're there
        int cur_time=0;
        if (goto_flag==1) {
          if (cycle_flag)
            sscanf(cycles[hist_num_temp], "%u", &cur_time);
          else
            sscanf(timebuffer[hist_num_temp], "%u", &cur_time);
          if ((cur_time >= stop_time) ||
              (strcmp(readbuffer,"DONE")==0) ) {
            goto_flag = 0;
            echo_data = 1;
            running = 0;
            timeout(-1);
            continue_flag = 0;
            //parsedata(hist_num_temp);
          }
        }
      }
    }
    refresh();
    delwin(title_win);
    endwin();
    fflush(stdout);
    if(resp == 'q'){
      fclose(fp2);
      write(CHILD_WRITE, "Z", 1);
      exit(0);
    }
    readbuffer[0] = 0;
    while(strncmp(readbuffer,"DONE",4) != 0){
      if(fgets(readbuffer, sizeof(readbuffer), fp) != NULL)
        fputs(readbuffer, fp2);
    }
    fclose(fp2);
    fflush(stdout);
    write(CHILD_WRITE, "Z", 1);
    printf("Child Done Execution\n");
    exit(0);
  } else {
    close(CHILD_READ);
    close(CHILD_WRITE);
    dup2(PARENT_WRITE, 1);
    close(PARENT_WRITE);
    
  }
}


// Function to make testbench block until debugger is ready to proceed
extern "C" int waitforresponse(){
  static int mem_start = 0;
  char c=0;
  while(c!='n' && c!='Z') read(PARENT_READ,&c,1);
  if(c=='Z') exit(0);
  mem_start = read(PARENT_READ,&c,1);
  mem_start = mem_start << 8 + read(PARENT_READ,&c,1);
  return(mem_start);
}

extern "C" void flushpipe(){
  char c=0;
  read(PARENT_READ, &c, 1);
}

// Function to return string representation of opcode given inst encoding
char *get_opcode_str(int inst, int valid_inst)
{
  int opcode, check;
  char *str;
  
  if (valid_inst == ((int)'x' - (int)'0'))
    str = "-";
  else if(!valid_inst)
    str = "-";
  else if(inst==NOOP_INST)
    str = "nop";
  else {
    inst_t dummy_inst;
    dummy_inst.decode(inst);
    str = const_cast<char*>(dummy_inst.str); // due to legacy code..
  }

  return str;
}

// Function to parse register $display() from testbench and add to
// names/contents arrays
void parse_register(char *readbuf, int reg_num, char*** contents, char** reg_names) {
  char name_buf[32];
  char val_buf[32];
  int tmp_len;

  sscanf(readbuf,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
  int i=0;
  for (;i<NUM_HISTORY;i++){
    contents[i][reg_num] = (char*) malloc((tmp_len+1)*sizeof(char));
  }
  strcpy(contents[history_num][reg_num],val_buf);
  reg_names[reg_num] = (char*) malloc((strlen(name_buf)+1)*sizeof(char));
  strncpy(reg_names[reg_num], readbuf+1, strlen(name_buf));
  reg_names[reg_num][strlen(name_buf)] = '\0';
}

// Ask user for simulation time to stop at
// Since the enter key isn't detected, user must press 'g' key
//  when finished entering a number.
int get_time() {
  int col = COLS/2-6;
  wattron(title_win,A_REVERSE);
  mvwprintw(title_win,1,col,"goto time: ");
  wrefresh(title_win);
  int resp=0;
  int ptr = 0;
  char buf[32];
  int i;
  
  resp=wgetch(title_win);
  while(resp != 'g' && resp != KEY_ENTER && resp != ERR && ptr < 6) {
    if (isdigit((char)resp)) {
      waddch(title_win,(char)resp);
      wrefresh(title_win);
      buf[ptr++] = (char)resp;
    }
    resp=wgetch(title_win);
  }

  // Clean up title window
  wattroff(title_win,A_REVERSE);
  mvwprintw(title_win,1,col,"           ");
  for(i=0;i<ptr;i++)
    waddch(title_win,' ');

  wrefresh(title_win);

  buf[ptr] = '\0';
  return atoi(buf);
}
