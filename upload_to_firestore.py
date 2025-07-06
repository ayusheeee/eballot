import firebase_admin
from firebase_admin import credentials, firestore
import csv

# Initialize Firebase Admin SDK
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# Get Firestore client
db = firestore.client()

# Open the CSV file
with open("candidates.csv", newline='', encoding='utf-8') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        name = row['name']
        # Each document ID will be the candidate's name
        doc_ref = db.collection("candidates").document(name)
        doc_ref.set({
            "name": row["name"],
            "party": row["party"],
            "state": row["state"],
            "constituency": row["constituency"]
        })

print("✅ Data uploaded to Firestore successfully.")
