import 'dart:math';

/// 回测引擎
class BacktestEngine {
  static Map<String, dynamic> runBacktest({
    required List<double> prices,
    required String strategyType,
    required Map<String, double> params,
    double initialCapital = 10000,
    double commissionRate = 0.001,
  }) {
    List<Map<String, dynamic>> trades = [];
    double capital = initialCapital;
    double position = 0;
    double entryPrice = 0;
    int winCount = 0;
    int lossCount = 0;
    double maxDrawdown = 0;
    double peakCapital = initialCapital;
    
    List<String> signals = _generateSignals(prices, strategyType, params);
    
    for (int i = 0; i < prices.length; i++) {
      String signal = signals[i];
      
      if (signal == 'BUY' && position == 0) {
        double commission = capital * commissionRate;
        position = (capital - commission) / prices[i];
        entryPrice = prices[i];
        capital = 0;
        trades.add({'type': 'BUY', 'price': prices[i], 'time': i, 'capital': capital});
      } else if (signal == 'SELL' && position > 0) {
        double exitValue = position * prices[i];
        double commission = exitValue * commissionRate;
        capital = exitValue - commission;
        double profit = capital - (position * entryPrice);
        
        if (profit > 0) winCount++;
        else lossCount++;
        
        trades.add({'type': 'SELL', 'price': prices[i], 'time': i, 'profit': profit, 'capital': capital});
        position = 0;
      }
      
      double currentCapital = capital + (position * prices[i]);
      if (currentCapital > peakCapital) {
        peakCapital = currentCapital;
      }
      double drawdown = (peakCapital - currentCapital) / peakCapital * 100;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }
    
    double finalCapital = capital + (position * prices.last);
    double totalReturn = (finalCapital - initialCapital) / initialCapital * 100;
    int totalTrades = winCount + lossCount;
    double winRate = totalTrades > 0 ? winCount / totalTrades * 100 : 0;
    
    List<double> returns = [];
    for (int i = 1; i < prices.length; i++) {
      returns.add((prices[i] - prices[i-1]) / prices[i-1]);
    }
    double avgReturn = returns.isNotEmpty ? returns.reduce((a, b) => a + b) / returns.length : 0;
    double stdDev = returns.length > 1 ? _standardDeviation(returns) : 1;
    double sharpeRatio = stdDev > 0 ? (avgReturn / stdDev) * sqrt(252) : 0;
    
    return {
      'initialCapital': initialCapital,
      'finalCapital': finalCapital,
      'totalReturn': totalReturn,
      'totalTrades': totalTrades,
      'winCount': winCount,
      'lossCount': lossCount,
      'winRate': winRate,
      'maxDrawdown': maxDrawdown,
      'sharpeRatio': sharpeRatio,
      'trades': trades,
    };
  }
  
  static double _standardDeviation(List<double> data) {
    double mean = data.reduce((a, b) => a + b) / data.length;
    double sumSquaredDiff = data.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiff / data.length);
  }
  
  static List<String> _generateSignals(List<double> prices, String strategyType, Map<String, double> params) {
    List<String> signals = List.filled(prices.length, 'HOLD');
    
    switch (strategyType) {
      case 'moving_average':
        signals = _movingAverageStrategy(prices, params);
        break;
      case 'rsi':
        signals = _rsiStrategy(prices, params);
        break;
      case 'bollinger':
        signals = _bollingerStrategy(prices, params);
        break;
      case 'macd':
        signals = _macdStrategy(prices, params);
        break;
    }
    
    return signals;
  }
  
  static List<String> _movingAverageStrategy(List<double> prices, Map<String, double> params) {
    int fastPeriod = params['fastPeriod']?.toInt() ?? 10;
    int slowPeriod = params['slowPeriod']?.toInt() ?? 30;
    List<String> signals = List.filled(prices.length, 'HOLD');
    
    for (int i = slowPeriod; i < prices.length; i++) {
      double fastMA = prices.sublist(i - fastPeriod, i).reduce((a, b) => a + b) / fastPeriod;
      double slowMA = prices.sublist(i - slowPeriod, i).reduce((a, b) => a + b) / slowPeriod;
      double prevFastMA = prices.sublist(i - fastPeriod - 1, i - 1).reduce((a, b) => a + b) / fastPeriod;
      double prevSlowMA = prices.sublist(i - slowPeriod - 1, i - 1).reduce((a, b) => a + b) / slowPeriod;
      
      if (fastMA > slowMA && prevFastMA <= prevSlowMA) {
        signals[i] = 'BUY';
      } else if (fastMA < slowMA && prevFastMA >= prevSlowMA) {
        signals[i] = 'SELL';
      }
    }
    
    return signals;
  }
  
  static List<String> _rsiStrategy(List<double> prices, Map<String, double> params) {
    int period = params['period']?.toInt() ?? 14;
    double oversold = params['oversold'] ?? 30;
    double overbought = params['overbought'] ?? 70;
    List<String> signals = List.filled(prices.length, 'HOLD');
    
    for (int i = period; i < prices.length; i++) {
      double rsi = _calculateRSI(prices.sublist(0, i + 1), period);
      
      if (rsi < oversold) {
        signals[i] = 'BUY';
      } else if (rsi > overbought) {
        signals[i] = 'SELL';
      }
    }
    
    return signals;
  }
  
  static double _calculateRSI(List<double> prices, int period) {
    if (prices.length < period + 1) return 50;
    
    List<double> gains = [];
    List<double> losses = [];
    
    for (int i = 1; i < prices.length; i++) {
      double change = prices[i] - prices[i - 1];
      gains.add(change > 0 ? change : 0);
      losses.add(change < 0 ? -change : 0);
    }
    
    double avgGain = gains.sublist(gains.length - period).reduce((a, b) => a + b) / period;
    double avgLoss = losses.sublist(losses.length - period).reduce((a, b) => a + b) / period;
    
    if (avgLoss == 0) return 100;
    double rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
  
  static List<String> _bollingerStrategy(List<double> prices, Map<String, double> params) {
    int period = params['period']?.toInt() ?? 20;
    double multiplier = params['multiplier'] ?? 2;
    List<String> signals = List.filled(prices.length, 'HOLD');
    
    for (int i = period; i < prices.length; i++) {
      double sma = prices.sublist(i - period, i).reduce((a, b) => a + b) / period;
      double variance = prices.sublist(i - period, i).map((p) => (p - sma) * (p - sma)).reduce((a, b) => a + b) / period;
      double stdDev = sqrt(variance);
      
      double upper = sma + multiplier * stdDev;
      double lower = sma - multiplier * stdDev;
      
      if (prices[i] < lower) {
        signals[i] = 'BUY';
      } else if (prices[i] > upper) {
        signals[i] = 'SELL';
      }
    }
    
    return signals;
  }
  
  static List<String> _macdStrategy(List<double> prices, Map<String, double> params) {
    int fastPeriod = params['fastPeriod']?.toInt() ?? 12;
    int slowPeriod = params['slowPeriod']?.toInt() ?? 26;
    int signalPeriod = params['signalPeriod']?.toInt() ?? 9;
    List<String> signals = List.filled(prices.length, 'HOLD');
    
    List<double> fastEMA = _calculateEMA(prices, fastPeriod);
    List<double> slowEMA = _calculateEMA(prices, slowPeriod);
    
    List<double> macdLine = [];
    for (int i = 0; i < prices.length; i++) {
      if (fastEMA[i].isNaN || slowEMA[i].isNaN) {
        macdLine.add(double.nan);
      } else {
        macdLine.add(fastEMA[i] - slowEMA[i]);
      }
    }
    
    List<double> validMacd = macdLine.where((e) => !e.isNaN).toList();
    if (validMacd.length < signalPeriod + 1) return signals;
    
    List<double> signalLine = _calculateEMA(validMacd, signalPeriod);
    
    int offset = macdLine.length - validMacd.length;
    for (int i = signalPeriod + 1; i < validMacd.length; i++) {
      int idx = i + offset;
      if (idx >= signals.length) break;
      
      if (validMacd[i] > signalLine[i - signalPeriod] && validMacd[i - 1] <= signalLine[i - signalPeriod - 1]) {
        signals[idx] = 'BUY';
      } else if (validMacd[i] < signalLine[i - signalPeriod] && validMacd[i - 1] >= signalLine[i - signalPeriod - 1]) {
        signals[idx] = 'SELL';
      }
    }
    
    return signals;
  }
  
  static List<double> _calculateEMA(List<double> data, int period) {
    List<double> result = [];
    double multiplier = 2 / (period + 1);
    
    for (int i = 0; i < period - 1; i++) {
      result.add(double.nan);
    }
    
    double ema = data.sublist(0, period).reduce((a, b) => a + b) / period;
    result.add(ema);
    
    for (int i = period; i < data.length; i++) {
      ema = (data[i] - ema) * multiplier + ema;
      result.add(ema);
    }
    
    return result;
  }
}