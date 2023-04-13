# Starting with a univariate time series analysis, just using the trip data to see if we can predict how many trips will occur by date
# This is quite a nice one as it's dealing with integers for trips etc.

import tensorflow as tf
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# What we can actually do here is clean the data a little using SQL: if we do it in pandas we have to process all the data first, and then iterate through, which leaves us with O(n) runtime
# O(n) here would be Massive as we have 669959 entries in trip; this would literally take most of a day to get done with pandas
# What I want to predict is the number of trips made in a day according to date, so we need to group the trips according to date (M/D/Y in this dataset)
# Obviously with a univariate LSTM we would just be feeding it the number of trips, but we need to make the intervals regular, and grouping by date makes sense
# For every seven days (makes sense to window by week), we want to predict what the next day's visitors would be
# Grouping our 669959 journeys by day reduces the amount of data we have to work with to 1095 rows (365*3 with no leap years), so that's worth noting

# We can write an easy enough sqlite command to extract the information that we need
# SELECT SUBSTR(start_date, INSTR(start_date, ' '), -10) AS date, COUNT(id) FROM trip GROUP BY date; We also have to do .mode csv and then .output ~filepath/univar.csv before our query
# Bingo! csv created in a tiny fraction of the time it would take to do it in pandas

df = pd.read_csv('univar.csv')
df['date'] = pd.to_datetime(df['date'], format='%m/%d/%Y')
df.sort_values(by='date', inplace=True) # Dates are ordered numerically, but this is a much easier sort in pandas- SQLite doesn't have datetime functions
