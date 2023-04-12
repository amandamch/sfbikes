-- DATABASE AVAILABLE AT https://www.kaggle.com/datasets/benhamner/sf-bay-area-bike-share?select=database.sqlite 
-- The first thing we want to do is query what the database has
.headers ON
.table
-- We find four tables: Station, Status, Trip, and Weather
.schema
-- The Station table gives us id, name, lat, long, dock_count, city, installation_date
-- Status gives us station_id, bikes_available, docks_available, and time
-- Trip gives us id, duration, start_date, start_station_id, end_date, end_station_id, bike_id, subscription_type, and zip_code
-- Weather gives us date, max/mean/min temperature (f), max/min/mean humidity, max/mean/min sea level pressure (in), max/mean/min visibility (mi), max/mean wind speed (mph), max gust (mph), precipitation (in), cloud_cover, events, wind_dir (degrees) and zip_code

-- There are a few columns in each table that I'm not sure what the contents are, so I'm going to investigate them
SELECT DISTINCT subscription_type FROM trip; -- This shows us that there are only two things someone can be: a subscriber or a customer

SELECT DISTINCT events FROM weather; -- We have null, Fog, Rain, Fog-Rain, rain (!) and Rain-Thunderstorm; this shows us there may be issues with Rain vs rain

SELECT cloud_cover FROM weather LIMIT 10; -- I was expecting a percentage, but this appears to be on a different scale, as only single digit cloud coverage seems unusual
SELECT MAX(cloud_cover) FROM weather WHERE cloud_cover IS NOT NULL; -- Produces an empty value?
SELECT MIN(cloud_cover) FROM weather; -- Minimum is 0
SELECT cloud_cover FROM weather ORDER BY cloud_cover DESC LIMIT 10;
-- It seems that the largest number here is 8, so we're looking at a scale that runs from 0 to 8

-- It would also be useful to know the number of stations that we're dealing with in this data set, as well as the number of trips made:
SELECT COUNT(name) FROM station; -- 70
SELECT COUNT(id) FROM trip; -- 669959

-- Now that my questions about the data types and the size of the data we're looking at have been answered, I can start investigating the questions that I'm interested in:
-- Which stations are the most popular to make trips from and to? How many docks do they have (this could indicate future docks that are needed)
-- Which stations are the least popular? How many docks do these ones have? (could tell us about distribution of resources)
-- What is the average number of docks and bikes available at the top stations?
-- What duration trips are people making? (max and mean; this can tell us what kind of trips people might be making)
-- What time of day do users make the most trips? (this could tell us if people are using the bikes to commute)
-- Which stations are the most visited during commuter hours, and which stations are the most visited during the 'tourist hours'? (i.e. during the day)
-- How many users are subscribers versus customers? (this could give us information about how to price each tier)
-- How does the weather affect the number of journeys? (this could tell us about the long-term sustainability of the bike programme)

SELECT COUNT(trip.start_station_id), station.name, station.dock_count FROM trip
    JOIN station ON trip.start_station_id=station.id 
    GROUP BY trip.start_station_id
    ORDER BY COUNT(trip.start_station_id) DESC LIMIT 5;
-- So our top stations are San Francisco Caltrain (Townsend at 4th) (49,092), San Francisco Caltrain 2 (330 Townsend) (33,742), Harry Bridges Plaza (Ferry Building) (32,394), Embarcadero at Sansome (27,713), and Temporary Transbay Terminal (Howard at Beale) (26,089)
-- We can see that there's a pretty big drop off after the top station, and then after the second and third as well
-- By ranking, the number of docks: 1st (19), 2nd (23), 3rd (23), 4th (15), 5th (23)

SELECT COUNT(trip.end_station_id), station.name, station.dock_count FROM trip
    JOIN station ON trip.end_station_id=station.id 
    GROUP BY trip.end_station_id
    ORDER BY COUNT(trip.end_station_id) DESC LIMIT 5;
-- Top five trip end stations: San Francisco Caltrain (Townsend at 4th) (63179), San Francisco Caltrain 2 (330 Townsend) (35117), Harry Bridges Plaza (Ferry Building) (33193), Embarcadero at Sansome (30796), 2nd at Townsend (28529)
-- Interestingly, more journeys end at the top locations than start, which could mean the bikes are used to get to central locations from elsewhere
-- Only the 5th place of the top 5 endings is different from the top 5 starts, and 2nd at Townsend has 27 docks. 

-- Since the top four stations are the same, we can look at the average number of bikes and docks available in the top four stations
SELECT AVG(status.bikes_available), AVG(status.docks_available), COUNT(trip.start_station_id) FROM status
    JOIN trip ON status.station_id=trip.start_station_id
    GROUP BY trip.start_station_id
    ORDER BY COUNT(trip.start_station_id) DESC LIMIT 4;
-- Lesson learned! This query was too much for my computer to process (runtime error)- need to find ways to make the runtime more efficient
-- Can do this by looking for the ids of the top four stations, and then only searching for their status averages
SELECT id FROM station WHERE name LIKE 'San Francisco Caltrain (Townsend at 4th)'; -- 70
SELECT id FROM station WHERE name LIKE 'San Francisco Caltrain 2 (330 Townsend)'; -- 69
SELECT id FROM station WHERE name LIKE 'Harry Bridges Plaza (Ferry Building)'; -- 50
SELECT id FROM station WHERE name LIKE 'Embarcadero at Sansome'; -- 60

-- Since we know that id = station_id, we don't need to join anything, and instead of running for all queries, ordering and limiting to the top 4, we can cut all of the irrelevant answers out
SELECT AVG(bikes_available), AVG(docks_available), station_id FROM status
    WHERE station_id=70 OR station_id=69 OR station_id=50 OR station_id=60
    GROUP BY station_id;
-- San Francisco Caltrain (Townsend at 4th): 10.73 bikes vs 8.23 docks available
-- San Francisco Caltrain 2 (330 Townsend): 12.21 bikes vs 10.75 docks available
-- Harry Bridges Plaza (Ferry Building): 13.32 bikes vs 9.61 docks available
-- Embarcadero at Sansome: 7.43 bikes vs 7.53 docks available

-- How does this compare to the overall averages?
SELECT AVG(bikes_available), AVG(docks_available) FROM status; -- 8.39 bikes and 9.28 docks, so on average a station has more docks than bikes, but the most popular stations all have more bikes than docks available (bar the embarcardero which is a difference of 0.1)


-- Next, we're going to look at the average, shortest, and longest journey times. Finding this value can also indicate how the journey times are stored (seconds, minutes, etc.)
SELECT AVG(duration) FROM trip; -- 1107.95 - we can assume this is seconds, as this is 18.45 minutes, whereas 1107 minutes would be 18 hours!
SELECT id, MAX(duration) FROM trip; -- Journey 568474 took 17270400 seconds! This is 4797 hours, or 6.57 months. This tells us we need to do some cleaning!
-- Need to figure out if this is a one-off:
SELECT id, duration FROM trip ORDER BY duration DESC LIMIT 10; -- Even the tenth longest journey lasted 7.5 days
SELECT COUNT(id) FROM trip WHERE duration > 86400; -- There were 296 journeys that were longer than 24h, and these are likely from people not putting the bikes back! We can rule them out of our mean duration once we've had a look at minimums


SELECT id, MIN(duration) FROM trip; -- Journey 8576 took 60 seconds, so it's worth investigating if the start and end station are the same here
SELECT start_station_id, end_station_id, MIN(duration) FROM trip; -- Yep, this started and ended at Harry Bridges Plaza, so we also need to eliminate these kinds of mistake journeys too
SELECT COUNT(id) FROM trip WHERE start_station_id=end_station_id; -- Of the 669959 journeys, a staggering 23981 had this profile, but people may have done loops, so let's limit this to ones where the trip lasted longer than 5 minutes
SELECT COUNT(id) FROM trip WHERE start_station_id=end_station_id AND duration < 300; -- Here we get 3288 journeys that were likely accidental
SELECT AVG(duration) FROM trip WHERE duration > 300 AND duration < 86400; -- 1162 seconds, which is a slight change from our first go but likely more accurate

-- So, who's making these accidental short journeys? And who's not putting the bikes back after use?
SELECT COUNT(subscription_type), subscription_type FROM trip
    WHERE duration < 300
    AND start_station_id=end_station_id
    GROUP BY subscription_type
-- 1070 were customers and 2218 were subscribers; potentially indicates subscribers changing their minds?
SELECT COUNT(subscription_type), subscription_type FROM trip
    WHERE duration > 86400
    GROUP BY subscription_type;
-- 248 were customers and 48 were subscribers; potentially indicates that subscribers are more conscious about bike use

-- What time do people make journeys? We can maybe measure this by seeing when changes in the number of bikes occurs
-- This required a little bit of fiddling to learn how to make this kind of query
-- First step is figuring out how to get journey times
SELECT start_date FROM trip LIMIT 10; -- Good news! These are datetime format. Now we need to get the hour of the trip out... 
-- Need to find what's between ' ' and ':' in SQLite- can't use LOCATE()
SELECT SUBSTR(start_date, INSTR(start_date, ' ') + 1) AS newcol FROM trip LIMIT 10;  -- Using the substring and instring methods to get the start times by indexing from after the first space in the data
-- Now we have to get the hour out of the time: we may need to find a way to trim again! Get the value minus the last three characters
SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time FROM trip LIMIT 10;
-- A far less stupid way of doing it: instead of removing a variable-length left side and then trying to trim a fixed-length right side, I could just select the two left of the colon and cast as an int- the empty space in single digits gets ignored
-- Next step: Dividing up the start times by the hour that they occurred
SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)) FROM trip
    GROUP BY start_time; -- This is something that we could / should make a graph out of to look at usage times

SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)) FROM trip
    WHERE start_time < 9; -- 152,980 journeys were made before 9am

SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)) FROM trip
    WHERE start_time >= 9 AND start_time < 17; -- 307,746 journeys were made between the hours of 9am and 5pm

SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)) FROM trip
    WHERE start_time >= 17; -- 209,233 journeys were made after 5pm
-- Although we don't have a graphical representation, the above can give us the impression of how the service is used, whether it's for commuting or pleasure
-- We can further explore this by introducing the division of subscription_type, to see who makes more journeys when: the hypothesis is more subscribers in commuting hours compared to between 9am and 5pm
SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)), subscription_type FROM trip
    WHERE start_time < 9
    GROUP BY subscription_type;-- 8462 Customers (5.5%) and 144518 Subscribers (94.5%)

SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)), subscription_type FROM trip
    WHERE start_time >= 9 AND start_time < 17
    GROUP BY subscription_type; -- 67485 Customers (21%) and 240260 Subscribers (79%)

SELECT CAST(SUBSTR(start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(start_date, -3, -2) AS int)), subscription_type FROM trip
    WHERE start_time >= 17
    GROUP BY subscription_type; -- 27265 Customers (13%) and 181,968 Subscribers (87%)
-- So we do see small changes in subscribers versus customer according to whether it's commuting hours or more tourist hours

-- The next question I want to answer is if we see a change in the stations visited during commuting or tourist hours- it's more useful to look at the end station, as that's where people want to go
SELECT CAST(SUBSTR(trip.start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(trip.start_date, -3, -2) AS int)) AS start_count, trip.end_station_id, station.name FROM trip
    JOIN station ON trip.end_station_id=station.id
    WHERE start_time < 9
    GROUP BY end_station_id
    ORDER BY COUNT(CAST(SUBSTR(trip.start_date, -3, -2) AS int)) DESC LIMIT 5;
-- Our most visited stations at this time are San Francisco Caltrain (Townsend at 4th), 2nd at Townsend, Market at Sansome, Townsend at 7th, and Embarcadero at Sansome

SELECT CAST(SUBSTR(trip.start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(trip.start_date, -3, -2) AS int)) AS start_count, trip.end_station_id, station.name FROM trip
    JOIN station ON trip.end_station_id=station.id
    WHERE start_time >= 9 AND start_time < 17
    GROUP BY end_station_id
    ORDER BY COUNT(CAST(SUBSTR(trip.start_date, -3, -2) AS int)) DESC LIMIT 5;
-- Our most visited stations at this time are San Francisco Caltrain (Townsend at 4th), Harry Bridges Plaza (Ferry Building), Embarcadero at Sansome, San Francisco Caltrain 2 (330 Townsend) and Market at Sansome

SELECT CAST(SUBSTR(trip.start_date, -3, -2) AS int) AS start_time, COUNT(CAST(SUBSTR(trip.start_date, -3, -2) AS int)) AS start_count, trip.end_station_id, station.name FROM trip
    JOIN station ON trip.end_station_id=station.id
    WHERE start_time >= 17
    GROUP BY end_station_id
    ORDER BY COUNT(CAST(SUBSTR(trip.start_date, -3, -2) AS int)) DESC LIMIT 5;
-- Now, the stations are San Francisco Caltrain (Townsend at 4th), San Francisco Caltrain 2 (330 Townsend), Harry Bridges Plaza (Ferry Building), Steuart at Market, and Temporary Transbay Terminal (Howard at Beale)
-- We need to do some further investigating of the layout of San Francisco and where these stops relate to commuting areas and transit stops, tourist areas, and residential areas to see if this variation in station shows variation in use

-- So we have already looked at how the percentage of customers to subscribers varies according to time of day, and who makes unusual length journeys, but perhaps there are more insights that we can get out of this
-- Firstly, what is the general proportion of customers to subscribers making journeys? This can tell us how the splits we found earlier according to time of day might compare to average
SELECT COUNT(subscription_type), subscription_type FROM trip
    GROUP BY subscription_type;
-- This data can't tell us about the number of unique users, but it can tell us that 103213 trips were customers and 566746 were subscribers (15% versus 85%). This makes it clear that journey time is affected by subscription type. Stats would need doing to see if it was significant
-- This also tells us that the subscribers are the main draw for usage, and perhaps pricing should reflect that (perhaps to incentivise subscription over being a customer by pricing up non-subscriber journeys)

-- How about the average journey length for subscribers versus customers? We've already looked at the unusual journeys, but what about in the range of usual journeys (more than 5min and less than 24h)?
SELECT AVG(duration), subscription_type FROM trip WHERE duration > 300 AND duration < 86400
    GROUP BY subscription_type; -- Average 3400 seconds for customers and 666 for subscribers: that's about 57 minutes and 11 for subscribers, which tells us a lot about the kinds of journeys are being made
-- If we assume the customers are more likely tourists taking leisure rides and subscribers are commuting, the numbers here back it up

-- The final question I want to answer is about how the season and weather affects usage; of course there are many more questions that can be answered (see below)
-- First, it's worth checking that the date column in the weather table is a properly-structured datetime: as we learned from trip, this isn't a guarantee!
SELECT date FROM weather LIMIT 10;-- ...it's not :( so this might take some more fiddling
SELECT CAST(SUBSTR(date, 1, 2) AS int) FROM weather LIMIT 10; -- SQL conveniently casts "9/" as "9", which solves that problem for us! The date format here is m/d/Y

-- First thing I want to find out is how many journeys are made according to season. We'll divide seasons as Spring (March-May), Summer (June-August), Autumn (September-November) and Winter (December-February)
-- I can first group the journey by month without having to join weather

SELECT CAST(SUBSTR(start_date, 1, 2) AS int) AS month, COUNT(start_date) FROM trip
    GROUP BY month;
-- So we get more riders in summer- June, July and August, but October also shows high numbers
-- Perhaps this is a combination of the tourist season in summer but October being a comfortable temperature for riding: September is also a hot month, and minus tourist traffic so ridership could drop because of that

-- Let's see how this works alongside the average max temperature for each month where trip.start_date=weather.date, but we have to take the timestamp off the trip.start_date
-- We want average max temperature rather than average temperature, as this could be a better indication of when it gets too hot to ride
SELECT CAST(SUBSTR(trip.start_date, 1, 2) AS int) AS month, COUNT(trip.start_date), AVG(weather.max_temperature_f) FROM trip
    JOIN weather ON weather.date = SUBSTR(trip.start_date, INSTR(trip.start_date, ' '), - 10)
    GROUP BY month;
-- For some reason here, all of the count values have been multiplied by 5, but all the other values are fine
-- The hottest months are July, August and September, which are 78 Fahrenheit (around 26 celsius)
-- The coolest months are December (60F) and January (63F) (15 and 17 degrees)
-- So ridership does vary according to temperature: this can be better demonstrated in a graph, which we can do later. I'll put the values in here for temperature:
-- The ridership drop in September that doesn't match the other months at that temperature does imply that tourist traffic is a big driver in summer ridership numbers
SELECT CAST(SUBSTR(trip.start_date, 1, 2) AS int) AS month, AVG(weather.max_temperature_f) FROM trip
    JOIN weather ON weather.date = SUBSTR(trip.start_date, INSTR(trip.start_date, ' '), - 10)
    GROUP BY month;

-- Out of interest, it might be useful to see whether subscription type varies alongside this; this is also worth graphing in presentation
SELECT CAST(SUBSTR(start_date, 1, 2) AS int) AS month, subscription_type, COUNT(subscription_type) FROM trip
    GROUP BY month, subscription_type;
-- From the data, we can see relatively consistent subscriber numbers, but a massive increase in customers in the summer months- this backs up our theory!
-- So something that we could think about in terms of prices is hiking prices in the summer months for customers

-- So what about rain? Instead of using 'rain'/'Rain' we might want to look at precipitation, to tell us how rainy it has to be for ridership to go down
SELECT AVG(precipitation_inches) FROM weather; -- 0.02 inches of rain average over the year
SELECT MAX(precipitaton_inches) FROM weather; -- "T"- need to get rid of that
SELECT AVG(precipitation_inches) FROM weather WHERE precipitation_inches != 'T'; -- This hasn't affected the numbers, but it may be that there are issues with the recording in this column

SELECT CAST(SUBSTR(trip.start_date, 1, 2) AS int) AS month, COUNT(trip.start_date), AVG(weather.precipitation_inches) FROM trip
    JOIN weather ON weather.date = SUBSTR(trip.start_date, INSTR(trip.start_date, ' '), - 10)
    GROUP BY month;
-- It seems like it really rains in July, but ridership numbers aren't affected in the same way as they are by temperature, but this may be to do with which city the rain is occurring in
-- Let's have a look at the event 'rain' or 'Rain' by month

SELECT CAST(SUBSTR(date, 1, 2) AS int) AS month, COUNT(events) AS rainy_days FROM weather
    WHERE events = (SELECT events FROM weather WHERE events LIKE 'rain')
    GROUP BY month;
-- It rains more frequently in the winter months, although July has twice the rain of June and August. It seems that this varies in the inverse generally to increases in temperature
-- Temp vs rainfall can definitely be graphed
-- However, it seems that customer ridership is the main driver in variation, and this has perhaps a lot more to do with tourist season than weather? But it could also be weather

-- There are lots more explorations that can be made in terms of weather specifics, as well as variation by city and by zipcode. We're somewhat limited by the lack of a rider id, but that makes sense for data privacy to not have that freely accessible!
-- What we do have is bike_id, and we could make a map of individual bikes' journeys around San Francisco, which could be a great illustration of individual bike mileage (theoretically this could be useful for automating a maintenance system)
-- We could also in future look at the most popular routes for customers and subscribers (by counting start and end station pairs in the trip table), or how weekdays vs weekends affect journey times. 