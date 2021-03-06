//+------------------------------------------------------------------+
//|                                       tksFFTforDowMiddleTerm.mq4 |
//|                                    Copyright 2015, Tokushi Corp. |
//|                                                 http://tks-w.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Tokushi Corp."
#property link      "http://tks-w.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

#property  indicator_buffers 8
#property  indicator_color1  Gold
#property  indicator_color2  Red
#property  indicator_color3  Green
#property  indicator_color4  Yellow /* ↑ */
#property  indicator_color5  Yellow	/* ↓ */
#property  indicator_width1  2
#property  indicator_width2  2
#property  indicator_width3  2

#import "Fourier.dll"
int HigashiWindow(double ConvergenceValue, double &ar[], int aN);
int execFilter(double &ar[], double &ai[], int aN, double &filterary[]);
int FFT4096(double &data[], int aN, double &retr[], double &reti[]);
int iFFT4096(double &ar[], double &ai[], int aN, double &retr[]);
void print(double &ar[], double &ai[], int n);
void printd(double &ar[], int n);
#import

#include <tks/tkslog.mqh>

#define DIR_THRESHOLD 3

/* input parameters */
input int      AppliedPrice   = PRICE_HIGH;  /* 使用する価格データの種類(PRICE_CLOSE(0),PRICE_OPEN(1),PRICE_HIGH(2),PRICE_LOW(3)) */

/* 定義 */
int      FFT_N          = 4096;        /* FFTのサイズ */

/* 計算用 */
double tempr[];      /* 実数部 */
double tempi[];      /* 虚数部 */
double filterary[];  /* フィルター */
/* 描画用 */
double   gFft[];
double   gUpDt[];
double   gDnDt[];
double   gUpArw[];
double   gDnArw[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   int ret0 = ArrayResize(filterary, FFT_N);
   int ret1 = ArrayResize(tempr, FFT_N);
   int ret2 = ArrayResize(tempi, FFT_N);
   if(ret0 != FFT_N || ret1 != FFT_N || ret2 != FFT_N) {
      printf("OnInit() ArrayResize() failured.");
      return(INIT_FAILED);
   }

   setFilter(filterary);

   IndicatorBuffers(8);
   SetIndexBuffer(0,gFft);
   SetIndexBuffer(1,gUpDt);
   SetIndexBuffer(2,gDnDt);
   SetIndexBuffer(3,gUpArw);
   SetIndexBuffer(4,gDnArw);

   SetIndexLabel(0,"FFT");
   SetIndexLabel(1,"Up");
   SetIndexLabel(2,"Down");

   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID);
   SetIndexStyle(1,DRAW_LINE,STYLE_SOLID);
   SetIndexStyle(2,DRAW_LINE,STYLE_SOLID);
   SetIndexStyle(3,DRAW_ARROW);
   SetIndexStyle(4,DRAW_ARROW);

   SetIndexArrow(3,228);         /* ↑ */
   SetIndexArrow(4,230);         /* ↓ */

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   /* BarsがFFT_N以下なら、処理しない */
   if(Bars<FFT_N) {
      IndicatorShortName("Error!! Bars(" + (string)Bars + ") < " + (string)FFT_N);
      return(0);
   }

   /* 初期化 */
   int limit=rates_total-prev_calculated;
   if(limit == 0) limit = 1;
   
   double AllBarPrices[];
   if(AppliedPrice == PRICE_OPEN)
      ArrayCopySeries(AllBarPrices, MODE_OPEN, NULL, PERIOD_H1);
   else if(AppliedPrice == PRICE_HIGH)
      ArrayCopySeries(AllBarPrices, MODE_HIGH, NULL, PERIOD_H1);
   else if(AppliedPrice == PRICE_LOW)
      ArrayCopySeries(AllBarPrices, MODE_LOW, NULL, PERIOD_H1);
   else if(AppliedPrice == PRICE_CLOSE)
      ArrayCopySeries(AllBarPrices, MODE_CLOSE, NULL, PERIOD_H1);

   /* FFT計算 */
   double Prices[];
   double retr[];

   int ret0 = ArrayResize(retr, FFT_N);
   if(ret0 != FFT_N) return 0;

   int lpmax = (limit/FFT_N-1) * FFT_N;
   if(lpmax < 0) lpmax = 0;
   for(int lpct = lpmax; lpct >= 0; lpct-=(FFT_N/2)) {
      ArrayCopy(Prices, AllBarPrices, 0, lpct, FFT_N);
	
/* ログ出力 削除予定 */
//loginfo(Prices, FFT_N);

      /* 窓関数適用 */
      HigashiWindow(Prices[0], Prices, FFT_N);

/* ログ出力 削除予定 */
//loginfo(Prices, FFT_N);

      /* FFT実行 */
	  FFT4096(Prices, FFT_N, tempr, tempi);

/* ログ出力 削除予定 */
//loginfo(tempr, tempi, FFT_N);

      /* デジタルフィルタをかける */
      execFilter(tempr, tempi, FFT_N, filterary);

/* ログ出力 削除予定 */
//loginfo(tempr, tempi, FFT_N);

      /* iFFT実行 */
      iFFT4096(tempr, tempi, FFT_N, retr);

/* ログ出力 削除予定 */
//loginfo(retr, FFT_N);

      ArrayCopy(gFft, retr, lpct, 0, (FFT_N/2));

      if(lpct == lpmax) continue;

//    /* 後ろを丸める(継ぎ目でガクンてなるから) */
//    int idx = 0;
//    for(int rct = lpct+(FFT_N*15/16); rct < (lpct+FFT_N); rct++,idx++)
//       gFft[rct] = (gFft[rct] * smoothconnect1024[idx]) + (gFft[lpct+FFT_N] * (1-smoothconnect1024[idx]));
   }

   /* 反転判定 */
   if(gUpDt[0] == EMPTY_VALUE && gDnDt[0] == EMPTY_VALUE) {
      gUpDt[0] = gUpDt[1];
      gDnDt[0] = gDnDt[1];
   }
   double tmpdiff = gFft[0] - gFft[1];
   if(tmpdiff-(DIR_THRESHOLD*Point) > 0 && gUpDt[0] == EMPTY_VALUE) {
      gUpArw[0] = gFft[0];
      gUpArw[1] = gFft[1];
      gUpArw[2] = gFft[2];
      gUpArw[3] = gFft[3];
      gUpArw[4] = gFft[4];
      gDnArw[0] = EMPTY_VALUE;
      gDnArw[1] = EMPTY_VALUE;
      gDnArw[2] = EMPTY_VALUE;
      gDnArw[3] = EMPTY_VALUE;
      gDnArw[4] = EMPTY_VALUE;
   } 
   else if(tmpdiff+(DIR_THRESHOLD*Point) < 0 && gDnDt[0] == EMPTY_VALUE) {
      gUpArw[0] = EMPTY_VALUE;
      gUpArw[1] = EMPTY_VALUE;
      gUpArw[2] = EMPTY_VALUE;
      gUpArw[3] = EMPTY_VALUE;
      gUpArw[4] = EMPTY_VALUE;
      gDnArw[0] = gFft[0];
      gDnArw[1] = gFft[1];
      gDnArw[2] = gFft[2];
      gDnArw[3] = gFft[3];
      gDnArw[4] = gFft[4];
   }

   /* 副次的な線を計算 */
   int loopmax = (limit-1);
   if(loopmax < (FFT_N / 16)) loopmax = FFT_N / 16;
   if(loopmax == (rates_total-1)) loopmax-=7;
   for(int lpct = loopmax; lpct >= 0; lpct--) {
      double diff = gFft[lpct] - gFft[lpct+1];
      /* 上向き */
      if(diff-(DIR_THRESHOLD*Point) > 0) {
         gUpDt[lpct] = gFft[lpct];
         gDnDt[lpct] = EMPTY_VALUE;
      }
      /* 下向き */
      else if(diff+(DIR_THRESHOLD*Point) < 0) {
         gUpDt[lpct] = EMPTY_VALUE;
         gDnDt[lpct] = gFft[lpct];
      }
      /* 横ばい */
      else {
         if(gUpDt[lpct] != EMPTY_VALUE)
            gUpDt[lpct] = gFft[lpct];
         else
            gDnDt[lpct] = gFft[lpct];
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
void setFilter(double &aFilterAry[]) {
	aFilterAry[0] = 1;
	for(int lpct = 1; lpct <= 18; lpct++) {
		filterary[lpct] = 1;
		filterary[FFT_N - lpct] = 1;
	}
}

void loginfo(double &valiable[], int size) {
	for(int lpct = 0; lpct < size; lpct++) {
		Loge("" + (string)lpct + ",=," + (string)valiable[lpct]);
	}
}
void loginfo(double &vals1[], double &vals2[],int size) {
	for(int lpct = 0; lpct < size; lpct++) {
		Loge("" + (string)lpct + ",=," + (string)vals1[lpct] + "," + (string)vals2[lpct]);
	}
}

