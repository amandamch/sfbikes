# San Francisco Bike Sharing 
## A project using SQL for exploration and Python for time series prediction

### What is this project?
This is a small investigation that I'm doing using the SF Bay Area Bike Share data from 2013-15, available on Kaggle at https://www.kaggle.com/datasets/benhamner/sf-bay-area-bike-share/code. I'm using SQLite to investigate the insights that we can draw from the data, such as how ridership is affected by seasons/weather, how time of day affects purpose and journeys, and what the difference in usage patterns is between customers and subscribers. It's not meant to be a comprehensive analysis, just an exploratory analysis to understand how the data works, what sort of preliminary questions we can answer with it, and what further directions our exploration can take.

### Part 1: SQLite Exploration
After getting to know the shape of the database and the tables within, I set about seeking to answer the following questions:
- Which stations are the most popular to make trips from and to? How many docks do they have (this could indicate future docks that are needed)
- Which stations are the least popular? How many docks do these ones have? (could tell us about distribution of resources)
- What is the average number of docks and bikes available at the top stations?
- What duration trips are people making? (max and mean; this can tell us what kind of trips people might be making)
- What time of day do users make the most trips? (this could tell us if people are using the bikes to commute)
- Which stations are the most visited during commuter hours, and which stations are the most visited during the 'tourist hours'? (i.e. during the day)
- How many users are subscribers versus customers? (this could give us information about how to price each tier)
- How does the weather affect the number of journeys? (this could tell us about the long-term sustainability of the bike programme)

I ended up answering more questions than these, just following on from the explorations that I made to answer these questions. I've also left in the queries that I drew up to begin to write some more complex queries, to demonstrate my approach and thought process when I was going through this. This SQL project has expanded my querying capabilities, and has taught me how to do things beyond just querying and joining tables, such as querying substrings, creating joins on substrings, and creating 'bins' for results that can help highlight trends and test hypotheses that cannot just be captured with the GROUP BY command.

### Part 2: Time Series Analysis
This part is coming soon. Given that there is three years' worth of seasonal data here, sorted down to individual days, locations, and trips, it should be possible to predict seasonal trends based on the data that we have here. This part will use Python and relevant libraries for time series analysis.