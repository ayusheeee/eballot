import csv

input_file = "candidates_final.csv"
output_file = "candidates_clean.csv"

with open(input_file, newline='', encoding='utf-8', errors='ignore') as infile, \
     open(output_file, "w", newline='', encoding='utf-8') as outfile:

    reader = csv.DictReader(infile)
    fieldnames = reader.fieldnames
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()

    for row in reader:
        # Skip rows where ALL values are empty or only whitespace
        if not any(value.strip() for value in row.values()):
            continue
        # Clean all values by stripping spaces
        clean_row = {key: value.strip() for key, value in row.items()}
        writer.writerow(clean_row)

print("✅ Cleaned CSV written to candidates_clean.csv")
