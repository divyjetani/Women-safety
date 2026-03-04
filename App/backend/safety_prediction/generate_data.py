# App/backend/safety_prediction/generate_data.py
import random
import pandas as pd
import os

threat_templates = [
    "help me",
    "someone is following me",
    "please save me",
    "he is trying to hurt me",
    "I am in danger",
    "call the police",
    "I feel unsafe",
    "don't come near me",
    "leave me alone",
    "stop touching me",
    "they are chasing me",
    "someone broke into my house",
    "I am scared",
    "I need help immediately",
    "he has a weapon",
    "there is an intruder",
    "I am being harassed",
    "this person won't leave me alone",
    "I think someone is outside",
    "I am trapped"
]

safe_templates = [
    "good morning",
    "how are you",
    "what are you doing",
    "let's meet tomorrow",
    "have a nice day",
    "I am going to college",
    "this food tastes good",
    "nice weather today",
    "see you later",
    "I finished my work",
    "can you call me later",
    "let's watch a movie",
    "I am studying",
    "this is interesting",
    "I love programming",
    "the meeting was productive",
    "I am at home",
    "let's go shopping",
    "that sounds good",
    "thank you"
]

locations = ["on the street", "in the park", "near my house", "at the bus stop", "in a taxi", "in my building"]
times = ["right now", "late at night", "this evening", "today", "just now"]
people = ["a man", "someone", "a stranger", "two guys", "a group of people"]

def generate_threat():
    base = random.choice(threat_templates)
    loc = random.choice(locations)
    t = random.choice(times)
    p = random.choice(people)

    variations = [
        f"{base} {loc}",
        f"{base} {t}",
        f"{p} is following me {loc}",
        f"{base}, {p} is near me",
        f"{base}, please help {t}",
        f"I think {p} is dangerous {loc}",
        f"{p} is acting suspicious {loc}",
        f"{base}, I am alone {loc}",
    ]

    return random.choice(variations)

def generate_safe():
    base = random.choice(safe_templates)
    loc = random.choice(locations)
    t = random.choice(times)

    variations = [
        f"{base}",
        f"{base} {loc}",
        f"{base} {t}",
        f"I will go {loc} {t}",
        f"{base}, see you {t}",
        f"{base} with my friends",
    ]

    return random.choice(variations)

data = []

for _ in range(600):
    data.append((generate_threat(), 1))

for _ in range(600):
    data.append((generate_safe(), 0))

random.shuffle(data)

df = pd.DataFrame(data, columns=["text", "label"])
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
file_path = os.path.join(BASE_DIR, "threat_dataset.csv")

df.to_csv(file_path, index=False)

print("Dataset saved at:", file_path)
