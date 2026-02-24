import numpy as np
import pandas as pd
import joblib
from sklearn.metrics.pairwise import haversine_distances
from config.settings import (
    GEO_SAFETY_MODEL_PATH,
    GEO_SCALER_PATH,
    DATA_CSV_PATH,
    EARTH_RADIUS,
)
from utils.logger import logger


class SafetyScoreService:
    def __init__(self):
        try:
            self.model = joblib.load(GEO_SAFETY_MODEL_PATH)
            self.scaler = joblib.load(GEO_SCALER_PATH)
            self.df = pd.read_csv(DATA_CSV_PATH)
            logger.info("✅ SafetyScoreService initialized successfully")
        except Exception as e:
            logger.error(f"❌ Error initializing SafetyScoreService: {e}")
            raise

    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        coords1 = np.radians([[lat1, lon1]])
        coords2 = np.radians([[lat2, lon2]])
        return haversine_distances(coords1, coords2)[0][0] * EARTH_RADIUS

    def get_features_for_location(self, lat: float, lon: float) -> pd.DataFrame:
        # Find nearest feature row based on crime area distance
        self.df["temp_distance"] = self.df.apply(
            lambda row: self.calculate_distance(
                lat, lon,
                row["crime_area_lat"],
                row["crime_area_lon"]
            ),
            axis=1
        )

        nearest = self.df.loc[self.df["temp_distance"].idxmin()]

        features = [
            self.calculate_distance(lat, lon, nearest["police_lat"], nearest["police_lon"]),
            self.calculate_distance(lat, lon, nearest["nearest_brts_lat"], nearest["nearest_brts_lon"]),
            self.calculate_distance(lat, lon, nearest["crime_area_lat"], nearest["crime_area_lon"]),
            self.calculate_distance(lat, lon, nearest["crowd_density_lat"], nearest["crowd_density_lon"]),
            self.calculate_distance(lat, lon, nearest["cctv_coverage_lat"], nearest["cctv_coverage_lon"]),
            self.calculate_distance(lat, lon, nearest["lighting_condition_lat"], nearest["lighting_condition_lon"]),
            nearest["crime_rate_score"],
            nearest["crowd_density_score"],
            nearest["cctv_coverage_score"],
            nearest["lighting_condition_score"],
        ]

        feature_names = [
            "dist_police",
            "dist_brts",
            "dist_crime",
            "dist_crowd",
            "dist_cctv",
            "dist_lighting",
            "crime_rate_score",
            "crowd_density_score",
            "cctv_score",
            "lighting_score"
        ]

        return pd.DataFrame([features], columns=feature_names)

    # safety score -> higher = safer
    def get_safety_score(self, lat: float, lon: float) -> float:
        try:
            features = self.get_features_for_location(lat, lon)
            features_scaled = self.scaler.transform(features)
            prediction = self.model.predict(features_scaled)[0]
            
            prediction = max(0, min(100, round(prediction, 2)))
            return prediction
        except Exception as e:
            logger.error(f"❌ Error calculating safety score: {e}")
            return 50.0 
