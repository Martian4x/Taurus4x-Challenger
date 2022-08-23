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
struct CDateTime;
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
input int ChallengeDurationMonths = 1;
input ENUM_TRADING_PHASES    CurrentChallengePhase = PHASE_1;                       
input ENUM_TIMEFRAMES        FrequenceTimeframe    = PERIOD_M1;                          //Monitoring Timeframe
input ENUM_BAR_PROCESSING_METHOD   BarProcessingMethod   = ONLY_PROCESS_TICKS_FROM_NEW_M1_BAR;  //EA Bar Processing Method (All systems I use M1 Data to process)

//################
//Global Variables
//################
string   SymbolArray[];                               //Set in OnInit()

int      TicksProcessedCount = 0;       //Number of ticks processed by the EA (will depend on the BarProcessingMethod being used)
datetime TimeLastTickProcessed;                     //Used to control the processing of trades so that processing only happens at the desired intervals (to allow like-for-like back testing between the Strategy Tester and Live Trading)
string   SymbolsProcessedThisIteration; 

int      iBarToUseForProcessing; 
//globals
string challenge_status = "";
//Global variables 
double deals_profits,current_profit, max_loss, profit_goal,floting_profits,daily_max_loss;
string challengeMetrics;
datetime StartDate, EndDate;
int OnInit() {
   string challengeMetrics = "";
   
   OutputStatusToScreen(challengeMetrics);
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
      
      current_profit=0;
      max_loss=0;
      profit_goal = 0;
      floting_profits =0;
      daily_max_loss=0;
      deals_profits=0;
      for(uint i=0;i<deals_total;i++) 
      {
         //--- Objectivess
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
         if(symbol!=""){
            datetime deal_time =(datetime)HistoryDealGetInteger(deal_ticket,DEAL_TIME);
            deals_profits = deals_profits+deal_profit+deal_swap+deal_commission+deal_fee;

            if(StartDate!=NULL){
               continue;
            }
            StartDate = deal_time;
         }
    
      }
      CDateTime newStartDate;
      TimeToStruct(StartDate,newStartDate);
      newStartDate.MonInc(ChallengeDurationMonths);
      EndDate = newStartDate.DateTime();
      // Print("Start Date: ", TimeToString(StartDate, TIME_DATE|TIME_SECONDS));
      // Print("End Date: ", EndDate);
         // Print("Balance:", DoubleToString(deals_profits));
      // Get Floating P/L
      floting_profits = FlotingProfit();
      current_profit = floting_profits+deals_profits;
      profit_goal = ChallengeCapital*ProfitTarget_Percentage/100;
      max_loss = ChallengeCapital*MaxLoss_Percentage/100;
      daily_max_loss = ChallengeCapital*MaxDailyLoss_Percentage/100;
      
      //3. Check the Objective is reached
      // Challenge Passed
      if(current_profit>profit_goal){
         challenge_status = "PASSED";
      // Challenge Not Passed | Reach max loss limit
      }else if(current_profit<=profit_goal&&current_profit<=-max_loss){
         challenge_status = "NOT PASSED";
      // Challenge Not Passed | Reach daily max limit
      }else if(current_profit<=-daily_max_loss){

      }
      // Print("Deals Profits: ",DoubleToString(deals_profits));
      // Print("Current Profit: ",DoubleToString(current_profit));

      // ExpertRemove(); // TODO: Removed
      // Print("current_profit: ",current_profit, " max_loss: ",max_loss, " profit_goal: ",profit_goal," floting_profits: ",floting_profits," daily_max_loss: ",daily_max_loss);
      OutputStatusToScreen(challengeMetrics);

   }
}


void OutputStatusToScreen(string additionalMetrics)
{
   double offsetInHours = (TimeCurrent() - TimeGMT()) / 3600.0;

   double currentDD = 0;
   if((ChallengeCapital+current_profit)<ChallengeCapital){
      currentDD = ChallengeCapital-(ChallengeCapital+current_profit);
   }
   
   string OutputText = "\n\r";
   
   OutputText += "MT5 SERVER TIME: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " (OPERATING AT UTC/GMT" + StringFormat("%+.1f", offsetInHours) + ")\n\r\n\r";
   
   OutputText += "CHALLENGE  | CAPITAL: " + IntegerToString(ChallengeCapital) + " | GOAL: " + IntegerToString(ChallengeCapital+profit_goal) + "\n\r";
   OutputText += "DATES:   START: " + TimeToString(StartDate, TIME_DATE|TIME_SECONDS) +"  |  END: "+EndDate+ "\n\r";
   OutputText += "CURRENT STATUS  | BALANCE: " + DoubleToString(deals_profits,2) +" |  EQUIT: " + DoubleToString(current_profit,2) + "  |  PROGRESS: " + DoubleToString(current_profit/profit_goal*100,2) + "%\n\r";
   OutputText += "MAX DRAWDOWNS:   MAX: -" + DoubleToString(max_loss, 0) +"  |  CURRENT: -"+DoubleToString(currentDD, 2)+ "\n\r";

   //SYMBOLS BEING TRADED
   // OutputText += "SYMBOLS:   ";
   // for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   // {
   //    OutputText += " " + SymbolArray[SymbolLoop];
   // }
   
   //Timeframe Info
   OutputText += "\n\rPROCESSING METHOD:   " + EnumToString(BarProcessingMethod) + "\n\r";
   OutputText += "PROCESSING TIMEFRAME:   " + EnumToString(FrequenceTimeframe) + "\n\r";
   
   // Comment(OutputText);
   Comment(OutputText,
         "\n\r\n\r", additionalMetrics);

   return;
}

