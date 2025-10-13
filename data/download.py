import pandas as pd
import yfinance as yf
import sqlite3

conn = sqlite3.connect("market.db")

ticker = "AJG"
data = yf.download(ticker, start="2024-01-01", end="2024-12-31")

# Flatten MultiIndex columns
if isinstance(data.columns, pd.MultiIndex):
    data.columns = [f"{col[0].lower()}" for col in data.columns]
else:
    data.columns = [col.lower() for col in data.columns]

# Add the symbol and timestamp columns
data["symbol"] = ticker
data["timestamp"] = data.index.astype("int64") // 10**9  # UNIX timestamp
data.reset_index(drop=True, inplace=True)
cols = ["symbol", "timestamp", "open", "high", "low", "close", "volume"]
data = data[cols]

# Save to SQLite
data.to_sql("ohlcv", conn, if_exists="replace", index=False)
conn.close()

print("Data saved to market.db successfully!")
