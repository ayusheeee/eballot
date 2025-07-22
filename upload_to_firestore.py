import firebase_admin
from firebase_admin import credentials, firestore
import csv
import re

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def clean_string(value):
    return value.strip().replace("\n", " ").replace("\r", " ")

with open("candidates_final.csv", newline='', encoding='utf-8') as csvfile:
    reader = csv.DictReader(csvfile)
    for i, row in enumerate(reader, start=1):
        name = clean_string(row.get('name', 'Unnamed Candidate'))

        if not name:
            continue

        doc_id = re.sub(r'[/\\#?]', '-', name)

        # 🔒 Check if already uploaded
        if db.collection("candidates").document(doc_id).get().exists:
            print(f"✅ Skipping (already uploaded): {doc_id}")
            continue

        doc_ref = db.collection("candidates").document(doc_id)
        doc_ref.set({
            "name": name,
            "party": clean_string(row.get("party", "Unknown")),
            "state": clean_string(row.get("state", "Unknown")),
            "constituency": clean_string(row.get("constituency", "Unknown"))
        })

        print(f"⬆️ Uploaded: {doc_id}")

print("🎉 Upload complete for new candidates only.")
