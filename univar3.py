# This univariate LSTM is predicting journey numbers by looking at the hour rather than the day: hopefully we'll be able to do better prediction with this level of detail
import tensorflow
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import *
from tensorflow.keras.callbacks import ModelCheckpoint
from tensorflow.keras.losses import MeanSquaredError
from tensorflow.keras.metrics import RootMeanSquaredError
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.models import load_model

# CSV file creation: we want the date of journey, hour of journey, and number of trips, grouped by hour
# We can reorder the csv once we have it as a dataframe
# SELECT SUBSTR(start_date, -3, -14) AS start_time, COUNT(start_date) AS trip_count FROM trip GROUP BY start_time; 

# The only issue with this data is that there are some early morning hours where there were no trips- hopefully casting as datetime helps with this

df = pd.read_csv('univar3.csv')
df['start_time'] = pd.to_datetime(df['start_time'], format='%m/%d/%Y %H')
df.sort_values(by='start_time', inplace=True)
df.index = df['start_time']
trip_count = df['trip_count']

# trip_count.plot()
# plt.show()
# This data is a much finer grain than the first one we did, and we can still see the seasonal variation in trips too! Hopefully we won't need 1000 epochs to get to a loss of 30,000!

def df_to_X_y (df, window_size):
    df_as_np = df.to_numpy()
    X = []
    y = []
    for i in range(len(df_as_np) - window_size):
        X.append([[val] for val in df_as_np[i:i+window_size]])
        y.append(df_as_np[i+window_size])
    return np.array(X), np.array(y)

WINDOW_SIZE = 5 # Just because it feels nice to be predicting the sixth hour

X, y = df_to_X_y(trip_count, WINDOW_SIZE)

# print(X.shape, y.shape)
# X and y have a length of 15893, so our split will be 12715, 1589, 1589

X_train, y_train = X[:12715], y[:12715]
X_val, y_val = X[12716:14304], y[12716:14304]
X_test, y_test = X[14305:], y[14305:]

model = Sequential()
model.add(InputLayer((WINDOW_SIZE, 1)))
model.add(LSTM(64))
model.add(Dense(8, 'relu'))
model.add(Dense(1, 'linear'))

cp = ModelCheckpoint('model/', save_best_only=True)

model.compile(loss=MeanSquaredError(), optimizer=Adam(), metrics=[RootMeanSquaredError()])
model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=250, callbacks=[cp])

model = load_model('model')

train_predictions = model.predict(X_train).flatten() # Readable matrix of predictions
train_results = pd.DataFrame(data={'Train Predictions':train_predictions, 'Actual Values':y_train})
print(train_results)

plt.plot(train_results['Train Predictions'])
plt.plot(train_results['Actual Values'])
plt.show()

# With 10 epochs: loss: 221.4113 - root_mean_squared_error: 14.8799 - val_loss: 262.6943 - val_root_mean_squared_error: 16.2078
# With 20 epochs: loss: 208.4394 - root_mean_squared_error: 14.4374 - val_loss: 243.8210 - val_root_mean_squared_error: 15.6148
# With 50 epochs: loss: 193.1314 - root_mean_squared_error: 13.8972 - val_loss: 215.2029 - val_root_mean_squared_error: 14.6698 (still struggling with early data: could be influence of missing values?)
# We can see some growth in the popularity of the program over time, and we can assume there's more missing middle of the night journeys toward the beginning that make the data more difficult
# With 100 epochs: loss: 182.7714 - root_mean_squared_error: 13.5193 - val_loss: 232.7693 - val_root_mean_squared_error: 15.2568 (improvements getting more marginal, but earlier data is predicted better)
# With 250 epochs: loss: 155.3439 - root_mean_squared_error: 12.4637 - val_loss: 222.3858 - val_root_mean_squared_error: 14.9126

# So we know that we can get pretty good info from the weather, so I think we should conduct a multivariate time series prediction using temp and trips
# Trips will have to be per day, however, as the weather is per day, but hopefully more variables should make the model fit better