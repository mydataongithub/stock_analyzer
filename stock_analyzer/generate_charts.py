#!/usr/bin/env python3

import sys
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
import yfinance as yf
from matplotlib.ticker import FuncFormatter

def format_percentage(x, pos):
    """Format tick labels as percentages"""
    return f"{x:.1f}%"

def generate_performance_chart(symbols, benchmark_symbols, start_date, output_file, title):
    """Generate performance comparison chart for a list of stock symbols"""
    end_date = datetime.now().strftime('%Y-%m-%d')
    
    # Download stock data
    all_symbols = symbols + benchmark_symbols
    data = yf.download(all_symbols, start=start_date, end=end_date)['Adj Close']
    
    # Calculate performance (percentage change relative to first day)
    performance_df = pd.DataFrame()
    
    for symbol in all_symbols:
        if symbol in data.columns:
            # Skip if we don't have enough data
            if len(data[symbol].dropna()) < 5:
                continue
                
            # Calculate percentage change
            start_price = data[symbol].dropna().iloc[0]
            performance_df[symbol] = (data[symbol] / start_price - 1) * 100
    
    if performance_df.empty:
        print(f"No valid data found for the provided symbols: {symbols}")
        return False
    
    # Create plot
    plt.figure(figsize=(12, 8))
    
    # Plot stock performance
    for symbol in symbols:
        if symbol in performance_df.columns:
            plt.plot(performance_df.index, performance_df[symbol], linewidth=2, label=symbol)
    
    # Plot benchmark performance with dashed lines
    for benchmark in benchmark_symbols:
        if benchmark in performance_df.columns:
            label = benchmark.replace('^', '')
            plt.plot(performance_df.index, performance_df[benchmark], linewidth=1.5, 
                    linestyle='--', label=label)
    
    # Format the plot
    plt.title(title, fontsize=16)
    plt.xlabel('Datum', fontsize=12)
    plt.ylabel('Performance (%)', fontsize=12)
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.legend(loc='best', fontsize=10)
    
    # Format x-axis dates
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%d-%m-%Y'))
    plt.gca().xaxis.set_major_locator(mdates.MonthLocator())
    plt.gcf().autofmt_xdate()
    
    # Format y-axis as percentage
    plt.gca().yaxis.set_major_formatter(FuncFormatter(format_percentage))
    
    # Add horizontal line at 0%
    plt.axhline(y=0, color='black', linestyle='-', alpha=0.3)
    
    # Save the plot
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Chart saved to {output_file}")
    return True

def create_performance_table(symbols, benchmark_symbols, start_date, output_file):
    """Create performance table for stocks and benchmarks"""
    end_date = datetime.now().strftime('%Y-%m-%d')
    all_symbols = symbols + benchmark_symbols
    data = yf.download(all_symbols, start=start_date, end=end_date)['Adj Close']
    
    # Calculate performance for different time periods
    performance = pd.DataFrame(index=all_symbols)
    
    now = datetime.now()
    
    # Calculate relevant dates
    week_ago = (now - timedelta(days=7)).strftime('%Y-%m-%d')
    month_ago = (now - timedelta(days=30)).strftime('%Y-%m-%d')
    three_months_ago = (now - timedelta(days=90)).strftime('%Y-%m-%d')
    year_start = f"{now.year}-01-01"
    
    # Add columns for different time periods
    performance['1W'] = None  # 1 week
    performance['1M'] = None  # 1 month
    performance['3M'] = None  # 3 months
    performance['YTD'] = None  # Year to Date
    performance['Since Recommendation'] = None  # Since recommendation date
    
    # Calculate performance for each symbol and period
    for symbol in all_symbols:
        if symbol in data.columns:
            symbol_data = data[symbol].dropna()
            if len(symbol_data) < 5:
                continue
                
            # Latest price
            latest_price = symbol_data.iloc[-1]
            
            # 1 week
            try:
                week_price = symbol_data.loc[:week_ago].iloc[-1]
                performance.loc[symbol, '1W'] = (latest_price / week_price - 1) * 100
            except:
                pass
            
            # 1 month
            try:
                month_price = symbol_data.loc[:month_ago].iloc[-1]
                performance.loc[symbol, '1M'] = (latest_price / month_price - 1) * 100
            except:
                pass
            
            # 3 months
            try:
                three_month_price = symbol_data.loc[:three_months_ago].iloc[-1]
                performance.loc[symbol, '3M'] = (latest_price / three_month_price - 1) * 100
            except:
                pass
            
            # Year to Date
            try:
                year_start_price = symbol_data.loc[:year_start].iloc[-1]
                performance.loc[symbol, 'YTD'] = (latest_price / year_start_price - 1) * 100
            except:
                pass
            
            # Since recommendation date
            try:
                start_price = symbol_data.iloc[0]
                performance.loc[symbol, 'Since Recommendation'] = (latest_price / start_price - 1) * 100
            except:
                pass
    
    # Format the table
    performance = performance.round(2)
    
    # Save to CSV
    performance.to_csv(output_file)
    print(f"Performance table saved to {output_file}")
    
    return performance

def extract_symbols_from_file(file_path):
    """Extract stock symbols from a recommendations file"""
    symbols = []
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if line.startswith('Symbol:'):
                    symbol = line.replace('Symbol:', '').strip()
                    symbols.append(symbol)
        return symbols
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return []

def main():
    if len(sys.argv) < 5:
        print("Usage: generate_charts.py <buy_file> <sell_file> <benchmarks> <output_dir> <timestamp>")
        sys.exit(1)
    
    buy_file = sys.argv[1]
    sell_file = sys.argv[2]
    benchmarks = sys.argv[3].split(',')
    output_dir = sys.argv[4]
    timestamp = sys.argv[5]
    
    # Extract recommendation date from timestamp
    recommendation_date = f"{timestamp[:4]}-{timestamp[4:6]}-{timestamp[6:8]}"
    
    # Get buy and sell symbols
    buy_symbols = extract_symbols_from_file(buy_file)
    sell_symbols = extract_symbols_from_file(sell_file)
    
    print(f"Found {len(buy_symbols)} buy recommendations and {len(sell_symbols)} sell recommendations")
    
    # Generate buy recommendations chart
    if buy_symbols:
        buy_chart_file = f"{output_dir}/buy_performance_{timestamp}.png"
        buy_csv_file = f"{output_dir}/buy_performance_{timestamp}.csv"
        
        title = f"Performance der Kaufempfehlungen (seit {recommendation_date})"
        success = generate_performance_chart(buy_symbols, benchmarks, recommendation_date, buy_chart_file, title)
        
        if success:
            create_performance_table(buy_symbols, benchmarks, recommendation_date, buy_csv_file)
    
    # Generate sell recommendations chart
    if sell_symbols:
        sell_chart_file = f"{output_dir}/sell_performance_{timestamp}.png"
        sell_csv_file = f"{output_dir}/sell_performance_{timestamp}.csv"
        
        title = f"Performance der Verkaufsempfehlungen (seit {recommendation_date})"
        success = generate_performance_chart(sell_symbols, benchmarks, recommendation_date, sell_chart_file, title)
        
        if success:
            create_performance_table(sell_symbols, benchmarks, recommendation_date, sell_csv_file)

if __name__ == "__main__":
    main()
