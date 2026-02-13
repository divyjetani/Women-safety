import joblib
import pandas as pd

model = joblib.load("C:/Users/divyj/Desktop/study/Capstone_Project/App/backend/models/safety_model.pkl")
encoders = joblib.load("C:/Users/divyj/Desktop/study/Capstone_Project/App/backend/models/encoders.pkl")
feature_order = joblib.load("C:/Users/divyj/Desktop/study/Capstone_Project/App/backend/models/feature_order.pkl")

def predict_safety(data_dict):

    df = pd.DataFrame([data_dict])

    # Encode categorical columns
    for col, encoder in encoders.items():
        df[col] = encoder.transform(df[col])

    # Ensure correct feature order
    df = df[feature_order]

    prediction = model.predict(df)[0]

    return round(float(prediction), 2)


# Example usage
if __name__ == "__main__":

    sample = {
        "Crime_Rate_per_1000": 4.0,
        "Lighting": "Good",
        "Crowd_Density": "Low",
        "Police_Latitude": 23.05,
        "Police_Longitude": 72.55,
        "Distance_to_Police_km": 2.5,
        "Late_Night_Activity": "Medium",
        "Public_Transport": "Moderate",
        "CCTV_Coverage": "High"
    }

    score = predict_safety(sample)
    print("Predicted Risk Score:", score)
