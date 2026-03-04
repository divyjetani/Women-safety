# App/backend/safety_prediction/train.py
# from sklearn.ensemble import randomforestregressor
# from sklearn.preprocessing import labelencoder
# from sklearn.metrics import mean_squared_error

# df = pd.read_excel("c:/users/divyj/desktop/study/capstone_project/app/data/data 1.xlsx")

# # drop non-numeric / non-useful columns

# # encode categorical columns


# for col in categorical_cols:
# df[col] = le.fit_transform(df[col])

# # define features and target
# x = df.drop(columns=["risk_score", "risk_level"])

# # since dataset is tiny, do not split (splitting is meaningless here)
# model = randomforestregressor(n_estimators=200, random_state=42)

# # evaluate on training data (only because dataset is tiny)
# predictions = model.predict(x)
# mse = mean_squared_error(y, predictions)

# print("model trained successfully")

# # save model + encoders + feature order
# joblib.dump(model, "c:/users/divyj/desktop/study/capstone_project/app/backend/models/safety_model.pkl")
# joblib.dump(encoders, "c:/users/divyj/desktop/study/capstone_project/app/backend/models/encoders.pkl")
# joblib.dump(x.columns.tolist(), "c:/users/divyj/desktop/study/capstone_project/app/backend/models/feature_order.pkl")


import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib
from math import radians
from sklearn.metrics.pairwise import haversine_distances
from sklearn.ensemble import GradientBoostingRegressor

df = pd.read_csv("C:/Users/divyj/Desktop/study/Capstone_Project/App/data/data 2.csv")

EARTH_RADIUS = 6371  # km


def calculate_distance(lat1, lon1, lat2, lon2):
    coords1 = np.radians([[lat1, lon1]])
    coords2 = np.radians([[lat2, lon2]])
    return haversine_distances(coords1, coords2)[0][0] * EARTH_RADIUS


# generate synthetic training points
training_rows = []

for _, row in df.iterrows():
    for _ in range(20):  # generate 5 samples per row
        lat = row["crime_area_lat"] + np.random.uniform(-0.01, 0.01)
        lon = row["crime_area_lon"] + np.random.uniform(-0.01, 0.01)

        dist_police = calculate_distance(lat, lon, row["police_lat"], row["police_lon"])
        dist_brts = calculate_distance(lat, lon, row["nearest_brts_lat"], row["nearest_brts_lon"])
        dist_crime = calculate_distance(lat, lon, row["crime_area_lat"], row["crime_area_lon"])
        dist_crowd = calculate_distance(lat, lon, row["crowd_density_lat"], row["crowd_density_lon"])
        dist_cctv = calculate_distance(lat, lon, row["cctv_coverage_lat"], row["cctv_coverage_lon"])
        dist_lighting = calculate_distance(lat, lon, row["lighting_condition_lat"], row["lighting_condition_lon"])

        # safety logic formula (important)
        safety_score = (
            50
            - row["crime_rate_score"] * 5
            - dist_crime * 3
            - row["crowd_density_score"] * 2
            + row["cctv_coverage_score"] * 3
            + row["lighting_condition_score"] * 3
            - dist_police * 1.5
        )


        safety_score = np.clip(safety_score, 10, 90)

        training_rows.append([
            dist_police,
            dist_brts,
            dist_crime,
            dist_crowd,
            dist_cctv,
            dist_lighting,
            row["crime_rate_score"],
            row["crowd_density_score"],
            row["cctv_coverage_score"],
            row["lighting_condition_score"],
            safety_score
        ])

train_df = pd.DataFrame(training_rows, columns=[
    "dist_police",
    "dist_brts",
    "dist_crime",
    "dist_crowd",
    "dist_cctv",
    "dist_lighting",
    "crime_rate_score",
    "crowd_density_score",
    "cctv_score",
    "lighting_score",
    "safety_score"
])

print(train_df["safety_score"].describe())

X = train_df.drop("safety_score", axis=1)
y = train_df["safety_score"]

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

model = GradientBoostingRegressor(n_estimators=300, learning_rate=0.05)

model.fit(X_scaled, y)

joblib.dump(model, "C:/Users/divyj/Desktop/study/Capstone_Project/App/backend/models/geo_safety_model.pkl")
joblib.dump(scaler, "C:/Users/divyj/Desktop/study/Capstone_Project/App/backend/models/geo_scaler.pkl")

print("Geo model trained.")
