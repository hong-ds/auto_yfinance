"""Cloud function for download stock data from yahoo finance."""

import json
import os
import time
from datetime import datetime

import pandas as pd
import yfinance as yf
from flask import Flask

########################################################
# configs

STOCK_PATH = "assets"
CHUNKS = 500
PERIOD = "5d"
INTERVAL = "1m"

########################################################

app = Flask(__name__)


def read_symbols(fpath):
    """if fpath is a folder, parse multiple symbols, otherwise return symbols"""
    if fpath.endswith(".csv"):
        symbols = pd.read_csv(fpath, usecols=["Symbol"], squeeze=True).tolist()
    else:
        files = os.listdir(fpath)
        symbols = []
        for f in files:
            symbols_partition = pd.read_csv(
                f"{fpath}/{f}", usecols=["Symbol"], squeeze=True
            ).tolist()
            symbols += symbols_partition
    return symbols


def downloadChunks(symbols, period, interval, chunks, pause=10):
    """Calling the yfinance in chunks to avoid being blocked by yahoo."""
    data = pd.DataFrame()
    for i in range(0, len(symbols), chunks):
        symbols_chunk = symbols[i : i + chunks]
        data_chunk = yf.download(  # or pdr.get_data_yahoo(...
            # tickers list or string as well
            tickers=symbols_chunk,
            # use "period" instead of start/end
            # valid periods: 1d,5d,1mo,3mo,6mo,1y,2y,5y,10y,ytd,max
            # (optional, default is '1mo')
            period=period,
            # fetch data by interval (including intraday if period < 60 days)
            # valid intervals: 1m,2m,5m,15m,30m,60m,90m,1h,1d,5d,1wk,1mo,3mo
            # (optional, default is '1d')
            interval=interval,
            # group by ticker (to access via data['SPY'])
            # (optional, default is 'column')
            group_by="ticker",
            # adjust all OHLC automatically
            # (optional, default is False)
            auto_adjust=True,
            # download pre/post regular market hours data
            # (optional, default is False)
            prepost=True,
            # use threads for mass downloading? (True/False/Integer)
            # (optional, default is True)
            threads=False,
        )
        data = pd.concat([data, data_chunk], axis=1)
        time.sleep(pause)  # don't overwhelm the api

    return data


def createMetadata(df):
    """"Create metadata file."""
    start_date = df.index.min().strftime("%Y-%m-%d")
    end_date = df.index.max().strftime("%Y-%m-%d")

    metadata = {
        "start_date": start_date,
        "end_date": end_date,
        "period": PERIOD,
        "interval": INTERVAL,
        "adjusted": "true",
        "prepost": "true",
        "file_format": "parquet",
        "records": df.shape[0],
        "tickers": df.shape[1],
    }

    return metadata


@app.route("/main")
def main(*arg):
    # get running time
    current_time = datetime.now()

    symbols = read_symbols(STOCK_PATH)

    df = downloadChunks(symbols, PERIOD, INTERVAL, CHUNKS)

    metadata = createMetadata(df)

    # parsing file names
    run_time = datetime.strftime(current_time, "%Y%m%d-%H%M%S")
    metadata_fname = f"{run_time}_metadata.json"
    data_fname = f"{run_time}_data.parquet"

    # save files
    with open(metadata_fname, "w") as outfile:
        json.dump(metadata, outfile, indent=4)
    df.to_parquet(data_fname)

    cmd = f"gsutil mv {metadata_fname} gs://auto-yfinance-data-bucket/"
    os.system(cmd)

    cmd = f"gsutil mv {data_fname} gs://auto-yfinance-data-bucket/"
    os.system(cmd)


@app.route("/")
def hello():
    return "Hello"


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
