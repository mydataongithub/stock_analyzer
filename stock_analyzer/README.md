# Stock Analyzer Project

The Stock Analyzer Project is a comprehensive tool for analyzing stocks, providing detailed insights into both technical and fundamental metrics. It is designed to assist investors in making informed decisions by offering a modular and extensible framework.

## Features

- **Technical Analysis**: Calculates key indicators such as Moving Averages (MA), Relative Strength Index (RSI), and volatility.
- **Fundamental Analysis**: Extracts financial ratios and metrics like P/E, P/B, ROE, and more.
- **DCF Valuation**: Performs Discounted Cash Flow (DCF) analysis to estimate intrinsic value.
- **Visualization**: Provides ASCII-based visualizations for price trends and performance comparisons.
- **Recommendations**: Generates actionable insights based on technical and fundamental data.
- **Batch Processing**: Analyzes multiple stocks efficiently with minimal API calls.
- **Performance Tracking**: Tracks performance of recommendations over time.
- **Optimized API Usage**: Reduces API calls through batch data fetching.

## Project Structure

```
/home/ganzfrisch/finance/stock_analyzer/
├── stock_analyzer.py             # Main script containing the StockAnalyzer class
├── batch_stock_analyzer.py       # Optimized version for analyzing stocks in batches
├── config.py                     # Configuration parameters (e.g., RSI period, historical data period)
├── utils.py                      # Utility functions (e.g., formatting, error handling)
├── recommend_logic.py            # Recommendation logic module
├── dcf_model.py                  # DCF calculation and sensitivity analysis module
├── data_viz.py                   # Text-based visualization module
└── README.md                     # Project documentation
```

## Requirements

- Python 3.8 or higher
- Required Python packages:
  - `yfinance`: For fetching stock and financial data
  - `tabulate`: For displaying data in tabular format
  - `numpy` and `pandas`: For data manipulation and calculations

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd /home/ganzfrisch/finance/stock_analyzer
   ```

2. Set up a virtual environment (optional but recommended):
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. Install the dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

1. Run the stock analyzer for a specific stock symbol:
   ```bash
   python stock_analyzer.py SYMBOL
   ```
   Replace `SYMBOL` with the ticker symbol of the stock you want to analyze (e.g., `AAPL`, `GOOG`, `SAP.DE`).

2. Example:
   ```bash
   python stock_analyzer.py SAP.DE
   ```

## Contributing

Contributions are welcome! If you have ideas for new features or improvements, feel free to open an issue or submit a pull request.

## Optimized Scripts

For better performance when analyzing multiple stocks, use the optimized versions:

- `batch_stock_analyzer.py`: Optimized data loading with minimal API calls
- `run_optimized_analysis.sh`: Runs batch analysis with optimized performance
- `auto_optimized_analyzer.sh`: Automates optimized batch analysis

See `README_OPTIMIZED.md` for detailed information about the optimized scripts.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
