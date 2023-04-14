# Starting with a univariate time series analysis, just using the trip data to see if we can predict how many trips will occur by date
# This is quite a nice one as it's dealing with integers for trips etc.
import tensorflow
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# What we can actually do here is clean the data a little using SQL: if we do it in pandas we have to process all the data first, and then iterate through, which leaves us with O(n) runtime
# O(n) here would be Massive as we have 669959 entries in trip; this would literally take most of a day to get done with pandas
# What I want to predict is the number of trips made in a day according to date, so we need to group the trips according to date (M/D/Y in this dataset)
# Obviously with a univariate LSTM we would just be feeding it the number of trips, but we need to make the intervals regular, and grouping by date makes sense
# For every seven days (makes sense to window by week), we want to predict what the next day's visitors would be
# Grouping our 669959 journeys by day reduces the amount of data we have to work with, so that's worth noting, particularly as we have around 2 years of data (2013 and 2014 are half-complete)

# We can write an easy enough sqlite command to extract the information that we need
# SELECT SUBSTR(start_date, INSTR(start_date, ' '), -10) AS date, COUNT(id) AS trip_count FROM trip GROUP BY date; We also have to do .mode csv and then .output ~filepath/univar.csv before our query
# Bingo! csv created in a tiny fraction of the time it would take to do it in pandas

df = pd.read_csv('univar.csv')
df['date'] = pd.to_datetime(df['date'], format='%m/%d/%Y')
df.sort_values(by='date', inplace=True) # Dates are ordered numerically, but this is a much easier sort in pandas- SQLite doesn't have datetime functions
df.index = df['date'] # This does make the date column redundant but that's not a huge concern atm- this just makes it easier to do a univariate LSTM
# Note: I could have done df.index = pd.to_datetime(df['date'], format='%m/%d/%Y') but then if you try and use sort_index it sorts it as if it's not datetime, so going 1st Jan 2013/14/15, which isn't what we want

# df['trip_count'].plot()
# plt.show()
# Even with the small dataset we can begin to see some kind of seasonailty in the data- there's a clear drop in winter and expansion in summer, but also the cutoff times for this data mean we only have one complete season
# This could maybe give us the chance to predict what happens in the latter half of 2015?
# Too fine grained atm to see if the wiggle is the effect of weekends

trip_count = df['trip_count']

# We then want an input matrix (3D tensor) where each row has a corresponding step ahead
# I think for every seven days, we want to predict what the next day is going to be, assuming a weekly pattern

def df_to_X_y (df, window_size):
    df_as_np = df.to_numpy() # Creating numpy array from df
    X = []
    y = []
    for i in range(len(df_as_np) - window_size):
        X.append([[val] for val in df_as_np[i:i+window_size]]) # Add window of 7 day values to X array
        y.append(df_as_np[i+window_size]) # Add day after window to y vector
    return np.array(X), np.array(y)

WINDOW_SIZE = 5 # Hard coding this here just because it's an important value that is worth keeping as a constant

X, y = df_to_X_y(trip_count, WINDOW_SIZE)

# Now we can split into train/validation/test (good practice is 80-10-10)
# Going to hard-code this just because we're working with a specific data set and a specific window size
# 80% of 726 is 580.8, but round it down so we can have even validation and test. Our split will be 580, 73, 73

X_train, y_train = X[:580], y[:580]
X_val, y_val = X[581:653], y[581:653]
X_test, y_test = X[654:], y[654:]

# Compile the model, using the tensorflow-specific imports (put down here because they only get used down here)
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import *
from tensorflow.keras.callbacks import ModelCheckpoint # This saves the model that does best on the validation to save us a lot of time and effort
from tensorflow.keras.losses import MeanSquaredError # MSE is the average of the squared distances from the real value
from tensorflow.keras.metrics import RootMeanSquaredError
from tensorflow.keras.optimizers import Adam # Faster and fewer parameters needed to tune compared to other models
from tensorflow.keras.models import load_model

model = Sequential()
model.add(InputLayer((WINDOW_SIZE, 1)))
model.add(LSTM(64)) # Doing an LSTM because that's good at picking up long-term dependencies, and since we're looking at seasonal or yearly trends, that's a good call
model.add(Dense(8, 'relu')) # ReLU over sigmoid/tanh as it doesn't have the same sensitivity issues and large values don't snap to each end of the scale; also just the most common activation function
model.add(Dense(1, 'linear')) # Trying to predict a linear value

# print(model.summary())
# ^ checking it does what I want (it does)

cp = ModelCheckpoint('model/', save_best_only=True)
model.compile(loss=MeanSquaredError(), optimizer=Adam(), metrics=[RootMeanSquaredError()]) # Adam learning rate default is 0.001

model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=1000, callbacks=[cp]) # Easy rule of thumb for epochs is 3 * no. columns, so 10 is fine for univariate LSTM

# Ok, so the output here is not good. Perhaps bike trips are not as predictable as we thought? Or perhaps the date simply is not enough information to fit a model for use (this makes sense really)
model = load_model('model')

train_predictions = model.predict(X_train).flatten() # Readable matrix of predictions
train_results = pd.DataFrame(data={'Train Predictions':train_predictions, 'Actual Values':y_train})
print(train_results)
# Ok, so something has definitely gone wrong here. All the training predictions are around super low, so we need to unpack why that's so different from the actual values, since it seems that the minimum number of trips is in the hundreds
# loss: 893185.8125 - root_mean_squared_error: 945.0851 - val_loss: 1178963.3750 - val_root_mean_squared_error: 1085.8008
# Below is a list of model tweaks that we can do:
# Altering window size
# Window size as 6: loss: 887147.3125 - root_mean_squared_error: 941.8849 - val_loss: 1177575.5000 - val_root_mean_squared_error: 1085.1615 (marginal improvement)
# Window size as 5: loss: 918391.3750 - root_mean_squared_error: 958.3274 - val_loss: 1213552.3750 - val_root_mean_squared_error: 1101.6135 (not as good but lower validation mse)
# Altering learning rate using our window size of 6, to 0.0001 Effect: loss: 933586.3125 - root_mean_squared_error: 966.2227 - val_loss: 1234065.5000 - val_root_mean_squared_error: 1110.8850 (not really improving)
# Changing number of epochs:
# 20 epochs: loss: 705208.3125 - root_mean_squared_error: 839.7668 - val_loss: 953453.1250 - val_root_mean_squared_error: 976.4492 (huge improvement relative to where we were)
# 50 epochs: loss: 218783.0625 - root_mean_squared_error: 467.7425 - val_loss: 342586.1250 - val_root_mean_squared_error: 585.3086 (big improvement but we're still in the hundreds of thousands for loss)
# However with 50 epochs the predicted and actual lines intersect
# We'll be really bold and try 1000 epochs, then leave it there for a debrief on what kind of issues a model like this has, and why LSTM might not be the most appropriate here
# loss: 32198.1719 - root_mean_squared_error: 179.4385 - val_loss: 44117.5508 - val_root_mean_squared_error: 210.0418
# We can then try another univariate analysis with the weather, and also with the number of trips grouped by hour as well as date, and then try a multivariate analysis using all the weather data

plt.plot(train_results['Train Predictions'])
plt.plot(train_results['Actual Values'])
plt.show()