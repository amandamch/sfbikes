# Doing a second univariate LSTM, to see if we can predict the weather according to the date
# We'll run it on the same kind of LSTM that we used for the first one, just for consistency
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

# Creating a csv file with the weather organised by date (again using SQL because it's so much faster)
# Most dates have several temperatures since there are three cities, so we're going to just group by date for convenience
# SELECT date, AVG(mean_temperature_f) AS mean_temp FROM weather GROUP BY date;

df = pd.read_csv('univar2.csv')
df['date'] = pd.to_datetime(df['date'], format='%m/%d/%Y')
df.sort_values(by='date', inplace=True)
df.index = df['date']
temp = df['mean_temp'] # creating useful variable; length of 733

# temp.plot()
# plt.show()
# This data looks more seasonal than the trip data, which is a good sign!
    
def df_to_X_y (df, window_size):
    df_as_np = df.to_numpy()
    X = []
    y = []
    for i in range(len(df_as_np) - window_size):
        X.append([[val] for val in df_as_np[i:i+window_size]])
        y.append(df_as_np[i+window_size])
    return np.array(X), np.array(y)

WINDOW_SIZE = 6 # Starting here we can see how we go

X, y = df_to_X_y(temp, WINDOW_SIZE) # Length of 727, so we do the 80-10-10 split as 581, 73, 73

X_train, y_train = X[:581], y[:581]
X_val, y_val = X[582:654], y[582:654]
X_test, y_test = X[655:], y[655:]

model = Sequential()
model.add(InputLayer((WINDOW_SIZE, 1)))
model.add(LSTM(64))
model.add(Dense(8, 'relu'))
model.add(Dense(1, 'linear'))

cp = ModelCheckpoint('model/', save_best_only=True)

model.compile(loss=MeanSquaredError(), optimizer=Adam(), metrics=[RootMeanSquaredError()])
model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=50, callbacks=[cp])

model = load_model('model')

train_predictions = model.predict(X_train).flatten() # Readable matrix of predictions
train_results = pd.DataFrame(data={'Train Predictions':train_predictions, 'Actual Values':y_train})
print(train_results)

plt.plot(train_results['Train Predictions'])
plt.plot(train_results['Actual Values'])
plt.show()

# With 10 epochs: loss: 779.0305 - root_mean_squared_error: 27.9111 - val_loss: 670.5809 - val_root_mean_squared_error: 25.8956
# With 20 epochs: loss: 60.5354 - root_mean_squared_error: 7.7804 - val_loss: 34.5674 - val_root_mean_squared_error: 5.8794 (line just cuts through the middle)
# With 50 epochs: loss: 18.2571 - root_mean_squared_error: 4.2728 - val_loss: 13.7585 - val_root_mean_squared_error: 3.7092 (not quite predicting the peak of summer but getting there)
# With 100 epochs: loss: 7.6699 - root_mean_squared_error: 2.7695 - val_loss: 11.3715 - val_root_mean_squared_error: 3.3722 (almost there! But I want a loss below 1)
# With 250 epochs: loss: 6.9303 - root_mean_squared_error: 2.6325 - val_loss: 11.4805 - val_root_mean_squared_error: 3.3883
#  With 1000 epochs: loss: 7.1981 - root_mean_squared_error: 2.6829 - val_loss: 11.1719 - val_root_mean_squared_error: 3.342 (so it looks like we sort of hit a point where we just won't get lower than 7, which is still impressive with this small dataset!)

# So the temperature data is quite a lot more predictable than the trip data - this makes sense!
# The next univariate LSTM that we'll try is trip data, except this time by hour - that kind of level of detail may work a lot better with the LSTM!