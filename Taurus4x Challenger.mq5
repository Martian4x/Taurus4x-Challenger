//+------------------------------------------------------------------+
//|                                          Trading Challenge Robot |
//|                                                        Martian4x |
//|                                         http://www.martian4x.com |
//+------------------------------------------------------------------+

#property copyright "Martian4x"
#property link "http://www.martian4x.com"
#property version   "1.01"
#property description "Taurus4x trading challenge management EA. \n This EA does not place trades but it monitors trading activies and closes all positions if the challenge rules are met or about to be broken."

#include <Martian4xLib\MoneyManagement.mqh>
#include <Tools\DateTime.mqh>
CDateTime DateTime;
enum ENUM_TRADING_PHASES
{
   PHASE_1,         //PHASE 1: EVALUATION
   PHASE_2          //PHASE 2: CONFIRMATION
};
enum ENUM_BAR_PROCESSING_METHOD
{
   PROCESS_ALL_DELIVERED_TICKS,                 //Process All Delivered Ticks
   ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR,          //Only Process Ticks From New M1 Bar
   ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR     //Only Process Ticks From New Bar in Trade TF (TimeFrame) eg. M15
};
input int ChallengeCapital = 10000;
input int ProfitTarget_Percentage = 10;
input int MaxDailyLoss_Percentage = 5;
input int MaxLoss_Percentage = 10;
input int ChallengeDurationDays = 30;
datetime StartDate;
datetime EndDate;
input ENUM_TRADING_PHASES    CurrentChallengePhase = PHASE_1;                       
input ENUM_TIMEFRAMES        FrequenceTimeframe    = PERIOD_M1;                          //Monitoring Timeframe
ENUM_BAR_PROCESSING_METHOD   BarProcessingMethod   = ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR;  //EA Bar Processing Method (All systems I use M1 Data to process)

//################
//Global Variables
//################
string   SymbolArray[];                               //Set in OnInit()

int      TicksProcessedCount = 0;       //Number of ticks processed by the EA (will depend on the BarProcessingMethod being used)
datetime TimeLastTickProcessed;                     //Used to control the processing of trades so that processing only happens at the desired intervals (to allow like-for-like back testing between the Strategy Tester and Live Trading)
string   SymbolsProcessedThisIteration; 

int      iBarToUseForProcessing; 
//globals
double deals_profits;
string challenge_status = "";
//Global variables 
double Profit=0, ProfitSymbol=0;
int OnInit() {
   
   // END of Connection 
   return(INIT_SUCCEEDED);
}

void OnTick() {
   string CurrentSymbol = Symbol();
   bool ProcessThisIteration = false;     //Set to false by default and then set to true below if required

   if(BarProcessingMethod == PROCESS_ALL_DELIVERED_TICKS)
      ProcessThisIteration = true;
   
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR)    //Process trades from any TF, every minute.
   {
      if(TimeLastTickProcessed != iTime(CurrentSymbol, PERIOD_M1, 0))
      {
         ProcessThisIteration = true;
         TimeLastTickProcessed = iTime(CurrentSymbol, PERIOD_M1, 0);
      }
   }
   
   else if(BarProcessingMethod == ONLY_PROCESS_TICKS_FROM_NEW_TRADE_TF_BAR) //Process when a new bar appears in the TF being used. So the M15 TF is processed once every 15 minutes, the TF60 is processed once every hour etc...
   {
      if(TimeLastTickProcessed != iTime(CurrentSymbol, FrequenceTimeframe, 0))      // TimeLastTickProcessed contains the last Time[0] we processed for this TF. If it's not the same as the current value, we know that we have a new bar in this TF, so need to process 
      {
         ProcessThisIteration = true;
         TimeLastTickProcessed = iTime(CurrentSymbol, FrequenceTimeframe, 0);
      }
   }
   
   //#############################
   //Process Trades if appropriate
   //#############################
   if(ProcessThisIteration == true)
   {
      TicksProcessedCount++;
      // SymbolsProcessedThisIteration += CurrentSymbol + "\n\r"; //Used to ouput to screen for visual confirmation of processing

      //#####################################
      // 1. Check if there is a closed positions
      //#####################################
      //--- request trade history 
      HistorySelect(0,TimeCurrent()); 
      // Checking DB Connection
      // if (Period()!=PerioD){
      //    OnDeinit(3);
      //    OnInit();
      // }
      // string   name; 
      uint deals_total=HistoryDealsTotal(); 
      ulong account_number = AccountInfoInteger(ACCOUNT_LOGIN);
      // 2. Check if there is a unsaved position
      // Print("Deals Total: ", IntegerToString(deals_total));
      for(uint i=0;i<deals_total;i++) 
      {
         //--- Objectives
         /**
         1. Get the total profit of order history
         2. Get the total profit of open orders
         3. Profit higher that ProfitTarget_Percentage then close all orders and close all other charts
         **/
         // ticket=HistoryDealGetTicket(i);
         ulong deal_ticket = HistoryDealGetTicket(i); 
         double deal_profit = HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);
         double deal_commission =HistoryDealGetDouble(deal_ticket,DEAL_COMMISSION);
         // Print("Commission :",DoubleToString(deal_commission));
         double deal_fee =HistoryDealGetDouble(deal_ticket,DEAL_FEE);
         double deal_swap =HistoryDealGetDouble(deal_ticket,DEAL_SWAP);
         string symbol =HistoryDealGetString(deal_ticket,DEAL_SYMBOL); 
         datetime deal_time =(datetime)HistoryDealGetInteger(deal_ticket,DEAL_TIME);
         if(symbol!=""){
            deals_profits = deals_profits+deal_profit+deal_swap+deal_commission+deal_fee;

            Print("Start Date :",TimeToString(deal_time, TIME_DATE|TIME_SECONDS));
            // datetime nDate = 0, cDate = D'2013.01.31 00:00';
            // StartDate = TimeToString(deal_time, TIME_DATE|TIME_SECONDS);
            StartDate = deal_time;
            EndDate = StringToTime(StringConcatenate(DateTime.Year(StartDate), ".", Month(StartDate)+1, ".", Day(StartDate)));
            Print ("Start Date: ", TimeToString(StartDate));
            Print ("End Date: ", TimeToString(EndDate));
            // deals_profits = deals_profits+deal_commission;
         }
    
      }
         // Print("Balance:", DoubleToString(deals_profits));
      // Get Floating P/L
      double floting_profits = FlotingProfit();
      double current_profit = floting_profits+deals_profits;
      double profit_goal = ChallengeCapital*ProfitTarget_Percentage/100;
      double max_loss = ChallengeCapital*MaxLoss_Percentage/100;
      double daily_max_loss = ChallengeCapital*MaxDailyLoss_Percentage/100;
      
      //3. Check the Objective is reached
      // Challenge Passed
      if(current_profit>profit_goal){
         challenge_status = "PASSED";
      // Challenge Not Passed | Reach max loss limit
      }else if(current_profit<=profit_goal&&current_profit<=-max_loss){
         challenge_status = "NOT PASSED";
      // Challenge Not Passed | Reach daily max limit
      }else if(current_profit<=-daily_max_loss)
      // Print("Deals Profits: ",DoubleToString(deals_profits));
      Print("Current Profit: ",DoubleToString(current_profit));

      ExpertRemove(); // TODO: Removed
   }
  
}

// double CheckTotalProfits()
//   {

//    Profit=0;
//    ProfitSymbol=0;

//    // 
//    for(int l_pos_0=OrdersTotal()-1; l_pos_0>=0; l_pos_0--)
//      {
//         bool order=OrderSelect(l_pos_0,SELECT_BY_POS,MODE_TRADES);
      
//       if(!order)
//         {
//          continue;
//         }

//       if(OrderType()==OP_BUY || OrderType()==OP_SELL)
//         {
//          double order_profit=OrderProfit()+OrderSwap()+OrderCommission();
//          Profit+=order_profit;
//             ProfitSymbol+=order_profit;
//         }
//      }
//       return(ProfitSymbol);
//   }

// void OnDeinit(const int reason) {
   
// }

