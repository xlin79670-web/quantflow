import 'dart:math';

/// 技术指标计算工具类
class TechnicalIndicators {
  /// 计算SMA
  static List<double> sma(List<double> data, int period) {
    List<double> result = [];
    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += data[j];
        }
        result.add(sum / period);
      }
    }
    return result;
  }

  /// 计算EMA
  static List<double> ema(List<double> data, int period) {
    List<double> result = [];
    double multiplier = 2 / (period + 1);
    
    for (int i = 0; i < period - 1; i++) {
      result.add(double.nan);
    }
    
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += data[i];
    }
    result.add(sum / period);
    
    for (int i = period; i < data.length; i++) {
      double emaValue = (data[i] - result[i - 1]) * multiplier + result[i - 1];
      result.add(emaValue);
    }
    
    return result;
  }

  /// 计算RSI
  static List<double> rsi(List<double> data, {int period = 14}) {
    List<double> result = [];
    List<double> gains = [];
    List<double> losses = [];
    
    for (int i = 1; i < data.length; i++) {
      double change = data[i] - data[i - 1];
      gains.add(change > 0 ? change : 0);
      losses.add(change < 0 ? -change : 0);
    }
    
    for (int i = 0; i < period; i++) {
      result.add(double.nan);
    }
    
    double avgGain = gains.sublist(0, period).reduce((a, b) => a + b) / period;
    double avgLoss = losses.sublist(0, period).reduce((a, b) => a + b) / period;
    
    if (avgLoss == 0) {
      result.add(100);
    } else {
      double rs = avgGain / avgLoss;
      result.add(100 - (100 / (1 + rs)));
    }
    
    for (int i = period; i < gains.length; i++) {
      avgGain = (avgGain * (period - 1) + gains[i]) / period;
      avgLoss = (avgLoss * (period - 1) + losses[i]) / period;
      
      if (avgLoss == 0) {
        result.add(100);
      } else {
        double rs = avgGain / avgLoss;
        result.add(100 - (100 / (1 + rs)));
      }
    }
    
    return result;
  }

  /// 计算MACD
  static Map<String, List<double>> macd(
    List<double> data, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    List<double> fastEma = ema(data, fastPeriod);
    List<double> slowEma = ema(data, slowPeriod);
    
    List<double> macdLine = [];
    for (int i = 0; i < data.length; i++) {
      if (fastEma[i].isNaN || slowEma[i].isNaN) {
        macdLine.add(double.nan);
      } else {
        macdLine.add(fastEma[i] - slowEma[i]);
      }
    }
    
    List<double> signalLine = ema(macdLine.where((e) => !e.isNaN).toList(), signalPeriod);
    List<double> paddedSignal = List.filled(macdLine.length - signalLine.length, double.nan) + signalLine;
    
    List<double> histogram = [];
    for (int i = 0; i < macdLine.length; i++) {
      if (macdLine[i].isNaN || paddedSignal[i].isNaN) {
        histogram.add(double.nan);
      } else {
        histogram.add(macdLine[i] - paddedSignal[i]);
      }
    }
    
    return {
      'macd': macdLine,
      'signal': paddedSignal,
      'histogram': histogram,
    };
  }

  /// 计算布林带
  static Map<String, List<double>> bollingerBands(
    List<double> data, {
    int period = 20,
    double standardDeviation = 2,
  }) {
    List<double> middle = sma(data, period);
    List<double> upper = [];
    List<double> lower = [];
    
    for (int i = 0; i < data.length; i++) {
      if (middle[i].isNaN) {
        upper.add(double.nan);
        lower.add(double.nan);
      } else {
        double sumSquaredDiff = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sumSquaredDiff += pow(data[j] - middle[i], 2);
        }
        double stdDev = sqrt(sumSquaredDiff / period);
        upper.add(middle[i] + standardDeviation * stdDev);
        lower.add(middle[i] - standardDeviation * stdDev);
      }
    }
    
    return {
      'upper': upper,
      'middle': middle,
      'lower': lower,
    };
  }

  /// 生成交易信号
  static Map<String, dynamic> generateSignals({
    required List<double> prices,
    required List<double> rsiValues,
    required Map<String, List<double>> macdData,
    required Map<String, List<double>> bollingerData,
  }) {
    int lastIndex = prices.length - 1;
    String signal = 'HOLD';
    double confidence = 0;
    List<String> reasons = [];
    
    if (!rsiValues[lastIndex].isNaN) {
      if (rsiValues[lastIndex] < 30) {
        signal = 'BUY';
        confidence += 0.3;
        reasons.add('RSI超卖(${rsiValues[lastIndex].toStringAsFixed(1)})');
      } else if (rsiValues[lastIndex] > 70) {
        signal = 'SELL';
        confidence += 0.3;
        reasons.add('RSI超买(${rsiValues[lastIndex].toStringAsFixed(1)})');
      }
    }
    
    if (!macdData['macd']![lastIndex].isNaN && !macdData['signal']![lastIndex].isNaN) {
      if (macdData['macd']![lastIndex] > macdData['signal']![lastIndex] &&
          macdData['macd']![lastIndex - 1] <= macdData['signal']![lastIndex - 1]) {
        signal = 'BUY';
        confidence += 0.3;
        reasons.add('MACD金叉');
      } else if (macdData['macd']![lastIndex] < macdData['signal']![lastIndex] &&
          macdData['macd']![lastIndex - 1] >= macdData['signal']![lastIndex - 1]) {
        signal = 'SELL';
        confidence += 0.3;
        reasons.add('MACD死叉');
      }
    }
    
    if (!bollingerData['lower']![lastIndex].isNaN) {
      if (prices[lastIndex] < bollingerData['lower']![lastIndex]) {
        if (signal != 'SELL') signal = 'BUY';
        confidence += 0.2;
        reasons.add('价格触及布林带下轨');
      } else if (prices[lastIndex] > bollingerData['upper']![lastIndex]) {
        if (signal != 'BUY') signal = 'SELL';
        confidence += 0.2;
        reasons.add('价格触及布林带上轨');
      }
    }
    
    return {
      'signal': signal,
      'confidence': confidence.clamp(0, 1),
      'reasons': reasons,
    };
  }
}